import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_otel/flutter_otel.dart' show StatusCode;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/chat_workspace_state.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_builder.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import 'dart:convert' show jsonEncode;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';
import 'package:hermes_app/src/workspaces/workspace_telemetry.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/recorded_breadcrumbs.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

/// Things that must never reach a span, a breadcrumb or a log event.
const _secretFolder = '/srv/secret-client-project';
const _secretName = 'secret-client-project';
const _secretBranch = 'feature/secret-branch';
const _secretProject = 'Secret Client Project';
const _profile = 'secretprofile';

const _catalogBody = {
  'projects': [
    {
      'id': 'p_1',
      'name': _secretProject,
      'folders': [
        {'path': _secretFolder, 'is_primary': true},
      ],
    },
  ],
  'repos': [
    {'root': '/srv/other-secret', 'sessions': 2, 'last_active': 5.0},
  ],
  'default_cwd': _secretFolder,
  'home': '/home/me',
  'scan_enabled': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late RecordedBreadcrumbs crumbs;
  late HermesWorkspacesRepository repository;
  late Future<Map<String, Object?>> Function(String, Map<String, Object?>) rpc;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    tracer = RecordingTracer();
    events = RecordedEvents();
    crumbs = RecordedBreadcrumbs();
    rpc = (_, _) async => {};
    server
      ..on('GET', '/api/chat/workspaces', _catalogBody)
      ..on('GET', '/api/fs/list', {
        'entries': [
          {'name': _secretName, 'path': _secretFolder, 'isDirectory': true},
        ],
      });
    repository = HermesWorkspacesRepository(
      server.client().raw,
      (method, params, {required timeout}) => rpc(method, params),
      telemetry: WorkspaceTelemetry(
        ConnectionTelemetry(
          tracer: tracer,
          events: events.call,
          serverAttributes: const {'hermes.version': '0.14.2'},
        ),
        crumbs.breadcrumbs,
      ),
    );
  });

  /// Every string a span or event carries.
  String recorded() => [
    for (final span in tracer.spans) ...[
      span.name,
      ...span.attributes.keys,
      ...span.attributes.values.map((v) => '$v'),
      ...span.events,
      '${span.statusDescription}',
    ],
    for (final name in events.namesStartingWith('')) ...[
      name,
      for (final attributes in events.named(name))
        for (final entry in attributes.entries) ...[
          entry.key,
          '${entry.value}',
        ],
    ],
    crumbs.text,
  ].join('\n');

  void expectNoSecrets() {
    final text = recorded();
    for (final secret in [
      _secretFolder,
      _secretName,
      _secretBranch,
      _secretProject,
      _profile,
      'other-secret',
      '/home/me',
    ]) {
      expect(text, isNot(contains(secret)), reason: secret);
    }
  }

  group('spans', () {
    test('workspace.list carries the kind, the outcome and counts, not a '
        'folder', () async {
      await repository.catalog(profile: _profile);
      await repository.listFolders(_secretFolder, profile: _profile);
      rpc = (_, _) async => {
        'items': [
          {'text': 'x', 'display': '$_secretName/', 'meta': 'dir'},
        ],
      };
      await repository.complete('/srv/secret', profile: _profile);

      expect(tracer.spans.map((s) => s.name), [
        'workspace.list',
        'workspace.list',
        'workspace.list',
      ]);
      expect(tracer.spans.map((s) => s.attributes['kind']), [
        'catalog',
        'browse',
        'suggest',
      ]);
      expect(tracer.spans.every((s) => s.attributes['outcome'] == 'ok'), true);
      expect(tracer.spans.first.attributes['projects'], 1);
      expect(tracer.spans.first.attributes['repos'], 1);
      expect(
        tracer.spans.first.attributes['hermes.version'],
        '0.14.2',
        reason: 'server attributes are allowed',
      );
      expect(tracer.spans.every((s) => s.ended), isTrue);
      expectNoSecrets();
    });

    test('a failed read ends the span with the outcome only', () async {
      server
        ..on('GET', '/api/chat/workspaces', {
          'detail': 'failed $_secretFolder',
        }, status: 500)
        ..on('GET', '/api/fs/list', {
          'detail': 'Path is outside the managed read boundary $_secretFolder',
        }, status: 403);

      await repository.catalog(profile: _profile);
      await repository.listFolders(_secretFolder, profile: _profile);

      expect(tracer.spans.map((s) => s.attributes['outcome']), [
        'failed',
        'forbidden',
      ]);
      expect(tracer.spans.every((s) => s.status == StatusCode.error), isTrue);
      expectNoSecrets();
    });

    test('workspace.move says how it ended, not where to', () async {
      rpc = (_, _) async => {'cwd': _secretFolder, 'branch': _secretBranch};
      await repository.moveWorkspace('s1', _secretFolder, profile: _profile);
      rpc = (_, _) async => throw GatewayRpcException(
        4017,
        'working directory does not exist: $_secretFolder',
      );
      await repository.moveWorkspace('s1', _secretFolder, profile: _profile);
      rpc = (_, _) async => throw GatewayRpcException(5007, 'move failed');
      await repository.moveWorkspace('s1', _secretFolder, profile: _profile);

      expect(tracer.spans.map((s) => s.name), List.filled(3, 'workspace.move'));
      expect(tracer.spans.map((s) => s.attributes['outcome']), [
        'ok',
        'not_found',
        'failed',
      ]);
      expectNoSecrets();
    });

    test('a path that is not a server path starts no span', () async {
      await repository.moveWorkspace('s1', 'relative/path', profile: _profile);

      expect(tracer.spans, isEmpty);
    });
  });

  group('the chat', () {
    late ChatController chat;
    late AttentionNotifier attention;
    late FakeChatTransport transport;
    late ValueNotifier<bool> activity;
    late AppLockController lock;

    Map<String, Object?> row(String id) => {
      ...sessionRow(id: id, title: 'Chat $id', lastActive: 1780000000),
      'cwd': _secretFolder,
      'git_branch': _secretBranch,
      'git_repo_root': _secretFolder,
    };

    setUp(() async {
      activity = ValueNotifier(true);
      transport = FakeChatTransport();
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([row('s1')]),
          query: {'profile': _profile},
        )
        ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
        ..on('GET', '/api/sessions/s1', row('s1'));
      attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      final authenticator = FakeDeviceAuthenticator();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'hermes.app_lock_enabled': true,
          });
      lock = AppLockController(
        authenticator: authenticator,
        coverWhenInactive: false,
      );
      await lock.load();
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        workspaces: repository,
        activity: activity,
        appLock: lock,
        transport: transport,
        attention: attention,
        breadcrumbs: crumbs.breadcrumbs,
        report: (_) {},
        events: events.call,
      );
      await chat.loadThreads(_profile);
    });

    tearDown(() {
      chat.dispose();
      attention.dispose();
      lock.dispose();
    });

    ChatThread thread() => chat.threads.firstWhere((t) => t.id == 's1');

    test('a confirmed move notes the confirmation and its outcome, no '
        'folder', () async {
      rpc = (_, _) async => {
        'cwd': '/srv/elsewhere-secret',
        'branch': _secretBranch,
      };

      await chat.moveWorkspace(thread(), '/srv/elsewhere-secret');

      expect(crumbs.named('workspace.move.confirmed'), [<String, Object>{}]);
      expect(events.named('workspace.move_outcome'), [
        {'outcome': 'changed'},
      ]);
      expect(recorded(), isNot(contains('elsewhere-secret')));
      expectNoSecrets();
    });

    test('each way a move can end is a fixed name', () async {
      final outcomes = <String>[];
      for (final (error, expected) in <(GatewayRpcException, String)>[
        (
          GatewayRpcException(4017, 'does not exist: $_secretFolder'),
          'folder_missing',
        ),
        (GatewayRpcException(4007, 'session $_secretName'), 'chat_gone'),
        (GatewayRpcException(4064, 'profile $_profile'), 'profile_gone'),
      ]) {
        rpc = (_, _) async => throw error;
        await chat.moveWorkspace(thread(), '/srv/else');
        outcomes.add(
          events.named('workspace.move_outcome').last['outcome']! as String,
        );
        expect(outcomes.last, expected);
      }
      // A lost answer is read again: the row still shows the old folder.
      rpc = (_, _) async => throw GatewayRpcException(5007, 'move failed');
      await chat.moveWorkspace(thread(), '/srv/else');
      expect(events.named('workspace.move_outcome').last, {
        'outcome': 'unchanged',
      });
      expectNoSecrets();
    });

    test('a folder that differs from the pick logs the mismatch without a '
        'path', () async {
      chat.newThread();
      chat.chooseWorkspace(const WorkspaceChoice(path: '/srv/picked-secret'));
      await chat.submit('hello', const []);
      await pumpEventQueue();
      transport.sends.last.emit(
        const WorkspaceBound(cwd: '/srv/started-secret'),
      );
      await pumpEventQueue();

      expect(events.named('workspace.cwd_mismatch'), [
        {'retried_without_explicit': false},
      ]);
      expect(recorded(), isNot(contains('picked-secret')));
      expect(recorded(), isNot(contains('started-secret')));
    });

    test(
      'sign-out clears the draft pick, the catalog and the notices',
      () async {
        chat.newThread();
        chat.chooseWorkspace(const WorkspaceChoice(path: _secretFolder));
        final loader = chat.workspaceCatalog()!;
        await loader.load();
        expect(loader.catalog, isNotNull);
        final epoch = chat.workspaceEpoch;

        chat.clearWorkspaceState();

        expect(chat.workspaceChoice, isNull);
        expect(chat.workspaceEpoch, epoch + 1);
        expect(loader.catalog, isNotNull, reason: 'the old loader is disposed');
        expect(chat.newChatWorkspace().folder, isNull);
      },
    );

    test('App Lock clears them and closes what is open, and reads nothing '
        'while locked', () async {
      chat.newThread();
      chat.chooseWorkspace(const WorkspaceChoice(path: _secretFolder));
      await chat.workspaceCatalog()!.load();
      final epoch = chat.workspaceEpoch;
      final reads = server.requestsTo('GET', '/api/chat/workspaces').length;

      WidgetsBindingLifecycle.pause();
      await pumpEventQueue();

      expect(lock.locked, isTrue);
      expect(chat.workspaceChoice, isNull);
      expect(chat.workspaceEpoch, epoch + 1);
      expect(chat.workspaceCatalog(), isNull);
      await pumpEventQueue();
      expect(
        server.requestsTo('GET', '/api/chat/workspaces'),
        hasLength(reads),
      );
    });

    test('no folder, project or branch reaches shared preferences', () async {
      chat.newThread();
      chat.chooseWorkspace(
        const WorkspaceChoice(
          path: _secretFolder,
          projectName: _secretProject,
          branch: _secretBranch,
        ),
      );
      await chat.workspaceCatalog()!.load();
      rpc = (_, _) async => {
        'cwd': '/srv/moved-secret',
        'branch': _secretBranch,
      };
      await chat.moveWorkspace(thread(), '/srv/moved-secret');

      final stored = await SharedPreferencesAsync().getAll();

      final text = [
        for (final entry in stored.entries) ...[entry.key, '${entry.value}'],
      ].join('\n');
      for (final secret in [
        _secretFolder,
        _secretName,
        _secretBranch,
        _secretProject,
        'moved-secret',
      ]) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
    });

    test('the surface snapshot, which Spotlight and the widgets read, '
        'carries none of the folder fields of a chat', () async {
      server
        ..on('GET', '/api/profiles', {
          'profiles': [
            {'name': _profile},
          ],
        })
        ..on('GET', '/api/dashboard/plugins', [])
        ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
        ..on('GET', '/api/cron/jobs', []);
      final built = await SurfaceSnapshotBuilder(
        HermesRepositories(server.client()),
        timeout: const Duration(milliseconds: 200),
      ).build(signedIn: true, refreshRemote: true);

      final text = jsonEncode(built.snapshot.toJson());

      expect(built.snapshot.recentChats, isNotEmpty);
      for (final secret in [_secretFolder, _secretName, _secretBranch]) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
    });

    test('App Lock keeps a move that is still being settled', () async {
      final answer = Completer<Map<String, Object?>>();
      rpc = (_, _) => answer.future;
      final future = chat.moveWorkspace(thread(), '/srv/else');
      await pumpEventQueue();
      expect(chat.workspaceMoveOf(thread()).phase, WorkspaceMovePhase.moving);

      WidgetsBindingLifecycle.pause();
      await pumpEventQueue();

      expect(chat.workspaceMoveOf(thread()).phase, WorkspaceMovePhase.moving);
      answer.complete({'cwd': '/srv/else'});
      await future;
    });
  });
}

/// Moves the binding the way the platform does, so App Lock engages.
abstract final class WidgetsBindingLifecycle {
  static void pause() => TestWidgetsFlutterBinding.instance
      .handleAppLifecycleStateChanged(AppLifecycleState.paused);
}
