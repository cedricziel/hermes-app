import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/chat_workspace_state.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/workspace_catalog_loader.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';

const _demo = '/home/me/code/demo';
const _other = '/home/me/code/other';

Map<String, Object?> _row(String id, {String? cwd, String? root}) => {
  ...sessionRow(id: id, title: 'Chat $id', lastActive: 1780000000),
  'cwd': cwd ?? _demo,
  'git_branch': 'main',
  'git_repo_root': root ?? cwd ?? _demo,
};

const _catalogBody = {
  'projects': [
    {
      'id': 'p_1',
      'slug': 'demo',
      'name': 'Demo',
      'folders': [
        {'path': _demo, 'is_primary': true},
      ],
    },
  ],
  'repos': [],
  'default_cwd': _demo,
  'home': '/home/me',
  'scan_enabled': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late List<(String, Map<String, Object?>)> rpcCalls;
  late Future<Map<String, Object?>> Function(Map<String, Object?> params)
  onMove;
  late List<(String, Map<String, Object>)> logged;
  late HermesWorkspacesRepository workspaces;
  late ValueNotifier<bool> activity;

  /// What `GET /api/sessions/s1` answers for a re-read.
  late FakeResponse Function() reread;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    rpcCalls = [];
    logged = [];
    activity = ValueNotifier(true);
    onMove = (params) async => {'cwd': _other, 'git_repo_root': _other};
    reread = () => (status: 200, body: _row('s1'));
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([_row('s1'), _row('s2', cwd: '/srv/two')]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([_row('h1')]),
        query: {'profile': 'home'},
      )
      ..on('GET', '/api/chat/workspaces', _catalogBody)
      ..onRequest('GET', '/api/sessions/s1', (_) => reread());
    for (final id in ['s1', 's2']) {
      server.on('GET', '/api/sessions/$id/messages', messageListBody(id, []));
    }
    workspaces = HermesWorkspacesRepository(server.client().raw, (
      method,
      params, {
      required timeout,
    }) {
      rpcCalls.add((method, params));
      // As the real requester does: it gives up after `timeout`.
      return onMove(params).timeout(timeout);
    });
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      workspaces: workspaces,
      activity: activity,
      transport: transport,
      attention: attention,
      report: (_) {},
      events: (name, [attributes = const {}]) => logged.add((name, attributes)),
    );
    await chat.loadThreads('work');
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  ChatThread thread(String id) => chat.threads.firstWhere((t) => t.id == id);

  Future<FakeSend> startNewChat({WorkspaceChoice? pick}) async {
    chat.newThread();
    if (pick != null) chat.chooseWorkspace(pick);
    await chat.submit('hello', const []);
    await pumpEventQueue();
    return transport.sends.last;
  }

  const pickOther = WorkspaceChoice(
    path: _other,
    projectName: 'Other',
    source: WorkspaceChoiceSource.project,
  );

  group('the draft choice', () {
    test('lives on the new thread and goes out with the first send', () async {
      chat.newThread();
      final draft = chat.selectedThread!;

      expect(chat.chooseWorkspace(pickOther), isTrue);

      expect(draft.workspaceChoice, pickOther);
      expect(chat.workspaceChoice, pickOther);
      await chat.submit('hello', const []);
      await pumpEventQueue();
      expect(transport.sends.single.workspace, pickOther);
    });

    test('no pick sends none', () async {
      final send = await startNewChat();

      expect(send.workspace, isNull);
    });

    test('a resumed chat sends none and takes no pick', () async {
      chat.select('s1');
      await pumpEventQueue();

      expect(chat.chooseWorkspace(pickOther), isFalse);
      await chat.submit('more', const []);
      await pumpEventQueue();

      expect(transport.sends.single.workspace, isNull);
    });

    test(
      'a pick made with no chat selected goes to the next new chat',
      () async {
        chat.clearSelection();
        expect(chat.workspaceChoice, isNull);

        chat.chooseWorkspace(pickOther);
        expect(chat.workspaceChoice, pickOther);
        await chat.submit('hello', const []);
        await pumpEventQueue();

        expect(transport.sends.single.workspace, pickOther);
      },
    );

    test('is cleared once the chat is created', () async {
      final send = await startNewChat(pick: pickOther);
      final draft = chat.selectedThread!;

      send.emit(const ThreadBound('stored-9'));
      send.emit(const WorkspaceBound(cwd: _other, branch: 'dev'));
      await pumpEventQueue();

      expect(draft.workspaceChoice, isNull);
      expect(draft.id, 'stored-9');
      expect(draft.workingDirectory, _other);
      expect(draft.branch, 'dev');
      expect(draft.folderPath, _other);
      expect(chat.workspaceMismatchOf(draft), isNull);
      expect(logged.where((e) => e.$1 == 'workspace.cwd_mismatch'), isEmpty);
    });

    test('a create that failed before binding keeps the pick', () async {
      final send = await startNewChat(pick: pickOther);
      final draft = chat.selectedThread!;

      send.fail();
      await pumpEventQueue();

      expect(draft.workspaceChoice, pickOther);
    });

    test('is cleared on a profile switch, with the catalog', () async {
      chat.newThread();
      chat.chooseWorkspace(pickOther);
      final loader = chat.workspaceCatalog()!;
      await pumpEventQueue();

      await chat.loadThreads('home');

      expect(chat.workspaceChoice, isNull);
      expect(chat.threads.every((t) => t.workspaceChoice == null), isTrue);
      expect(chat.workspaceCatalog(), isNot(same(loader)));
    });

    test('is cleared on sign-out and Change Server', () async {
      chat.clearSelection();
      chat.chooseWorkspace(pickOther);
      final loader = chat.workspaceCatalog()!;
      await pumpEventQueue();

      chat.clearWorkspaceState();

      expect(chat.workspaceChoice, isNull);
      expect(chat.workspaceCatalog(), isNot(same(loader)));
    });

    test('a catalog answer after the controller is gone is dropped', () async {
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/chat/workspaces', (_) => gate.future);
      chat.clearSelection();
      final loader = chat.workspaceCatalog()!;
      await pumpEventQueue();
      expect(loader.loading, isTrue);

      chat.dispose();
      gate.complete((status: 200, body: _catalogBody));
      await pumpEventQueue();

      expect(loader.catalog, isNull);
      chat = ChatController(attention: attention, report: (_) {});
    });

    test(
      'a draft that a slash command created is not shown as picked',
      () async {
        chat.newThread();
        final draft = chat.selectedThread!;
        chat.chooseWorkspace(pickOther);

        await chat.runSlashCommand('/help');

        expect(draft.workspaceChoice, isNull);
        expect(chat.workspaceChoice, isNull);
      },
    );

    test('a pending pick is dropped when a command makes the chat', () async {
      chat.clearSelection();
      chat.chooseWorkspace(pickOther);

      await chat.runSlashCommand('/help');

      expect(chat.workspaceChoice, isNull);
      expect(chat.threads.first.workspaceChoice, isNull);
    });

    test(
      'a profile switch drops notices, projects and settled moves',
      () async {
        final send = await startNewChat(pick: pickOther);
        final draft = chat.selectedThread!;
        send.emit(const ThreadBound('stored-9'));
        send.emit(
          const WorkspaceBound(
            cwd: '/home/me',
            project: WorkspaceProjectRef(name: 'P'),
          ),
        );
        await pumpEventQueue();
        final target = thread('s1');
        await chat.moveWorkspace(target, _other);
        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.changed);

        await chat.loadThreads('home');

        expect(chat.workspaceMismatchOf(draft), isNull);
        expect(chat.workspaceProjectOf(draft), isNull);
        await chat.loadThreads('work');
        expect(
          chat.workspaceMoveOf(thread('s1')).phase,
          WorkspaceMovePhase.idle,
        );
      },
    );
  });

  group('where Hermes started the chat', () {
    test(
      'a differing folder is a one-time notice and a log without a path',
      () async {
        final send = await startNewChat(pick: pickOther);
        final draft = chat.selectedThread!;

        send.emit(const ThreadBound('stored-9'));
        send.emit(const WorkspaceBound(cwd: '/home/me'));
        await pumpEventQueue();

        final notice = chat.workspaceMismatchOf(draft)!;
        expect(notice.picked, _other);
        expect(notice.reported, '/home/me');
        expect(notice.profileMayUseOwnFolder, isFalse);
        final events = logged.where((e) => e.$1 == 'workspace.cwd_mismatch');
        expect(events, hasLength(1));
        expect(events.single.$2, {'retried_without_explicit': false});
        for (final (name, attributes) in logged) {
          expect('$name $attributes', isNot(contains('/home')));
          expect('$name $attributes', isNot(contains('other')));
        }

        chat.dismissWorkspaceMismatch(draft);
        expect(chat.workspaceMismatchOf(draft), isNull);
      },
    );

    test('the clause about the profile only follows a retry', () async {
      final send = await startNewChat(pick: pickOther);

      send.emit(const ThreadBound('stored-9'));
      send.emit(
        const WorkspaceBound(cwd: '/home/me', retriedWithoutExplicit: true),
      );
      await pumpEventQueue();

      expect(
        chat.workspaceMismatchOf(chat.selectedThread!)!.profileMayUseOwnFolder,
        isTrue,
      );
    });

    test(
      'trailing separators and a ~ with a known home are no mismatch',
      () async {
        chat.workspaceCatalog();
        await pumpEventQueue();
        expect(chat.workspaceCatalog()!.catalog!.home, '/home/me');

        for (final (pick, reported) in [
          ('$_other/', _other),
          ('~/code/other', _other),
          ('/home//me/code/other', _other),
        ]) {
          final send = await startNewChat(pick: WorkspaceChoice(path: pick));
          final draft = chat.selectedThread!;
          send.emit(ThreadBound('stored-$pick'));
          send.emit(WorkspaceBound(cwd: reported));
          await pumpEventQueue();

          expect(chat.workspaceMismatchOf(draft), isNull, reason: pick);
        }
        expect(logged.where((e) => e.$1 == 'workspace.cwd_mismatch'), isEmpty);
      },
    );

    test('a different folder is still a mismatch after normalising', () async {
      chat.workspaceCatalog();
      await pumpEventQueue();
      final send = await startNewChat(
        pick: const WorkspaceChoice(path: '~/code/other/'),
      );
      final draft = chat.selectedThread!;

      send.emit(const ThreadBound('stored-9'));
      send.emit(const WorkspaceBound(cwd: '/home/me/code/demo'));
      await pumpEventQueue();

      expect(chat.workspaceMismatchOf(draft), isNotNull);
    });

    test(
      'the folder path is the git root when the server reports one',
      () async {
        final send = await startNewChat();
        final draft = chat.selectedThread!;

        send.emit(const ThreadBound('stored-9'));
        send.emit(
          const WorkspaceBound(cwd: '$_other/api', gitRepoRoot: _other),
        );
        await pumpEventQueue();

        expect(draft.workingDirectory, '$_other/api');
        expect(draft.folderPath, _other);
      },
    );

    test('no pick, no comparison', () async {
      final send = await startNewChat();

      send.emit(const ThreadBound('stored-9'));
      send.emit(const WorkspaceBound(cwd: '/home/me'));
      await pumpEventQueue();

      expect(chat.workspaceMismatchOf(chat.selectedThread!), isNull);
      expect(chat.selectedThread!.workingDirectory, '/home/me');
    });

    test('the server project is kept for the chat', () async {
      final send = await startNewChat(pick: pickOther);

      send.emit(const ThreadBound('stored-9'));
      send.emit(
        const WorkspaceBound(
          cwd: _other,
          project: WorkspaceProjectRef(name: 'Other', id: 'p_2'),
        ),
      );
      await pumpEventQueue();

      expect(chat.workspaceProjectOf(chat.selectedThread!)!.name, 'Other');
    });
  });

  group('the row above a new chat', () {
    test('shows the profile default and its project tag', () async {
      chat.newThread();
      expect(chat.newChatWorkspace().lookingUp, isTrue);
      await pumpEventQueue();

      final row = chat.newChatWorkspace();

      expect(row.status, WorkspaceCatalogStatus.ready);
      expect(row.isServerDefault, isTrue);
      expect(row.folder, _demo);
      expect(row.projectName, 'Demo');
      expect(row.lookingUp, isFalse);
    });

    test('a pick replaces the default', () async {
      chat.newThread();
      await pumpEventQueue();
      chat.newChatWorkspace();
      chat.chooseWorkspace(pickOther);

      final row = chat.newChatWorkspace();

      expect(row.isServerDefault, isFalse);
      expect(row.folder, _other);
      expect(row.projectName, 'Other');
    });

    test('an older server leaves the row with nothing to say', () async {
      server.on('GET', '/api/chat/workspaces', {'detail': 'x'}, status: 404);
      chat.newThread();
      chat.newChatWorkspace();
      await pumpEventQueue();

      final row = chat.newChatWorkspace();

      expect(row.status, WorkspaceCatalogStatus.unsupported);
      expect(row.hidden, isTrue);
    });

    test('is empty without a repository', () {
      final bare = ChatController(attention: attention, report: (_) {});
      addTearDown(bare.dispose);

      expect(bare.workspaceCatalog(), isNull);
      expect(bare.newChatWorkspace().hidden, isTrue);
    });
  });

  group('moving a chat', () {
    Future<void> settle() => pumpEventQueue();

    test('sends once, updates the folder and keeps the selection', () async {
      chat.select('s2');
      final moved = thread('s1');

      expect(await chat.moveWorkspace(moved, _other), isNull);
      await settle();

      expect(rpcCalls, hasLength(1));
      expect(rpcCalls.single.$1, 'session.workspace.move');
      expect(rpcCalls.single.$2, {
        'session_key': 's1',
        'cwd': _other,
        'profile': 'work',
      });
      expect(moved.workingDirectory, _other);
      expect(moved.folderPath, _other);
      expect(chat.selectedId, 's2');
      final state = chat.workspaceMoveOf(moved);
      expect(state.phase, WorkspaceMovePhase.changed);
      expect(state.folder, _other);
    });

    test(
      'the folder path is the answer\'s git root, else the folder',
      () async {
        onMove = (_) async => {
          'cwd': '$_other/api',
          'branch': 'dev',
          'git_repo_root': _other,
        };
        final moved = thread('s1');

        await chat.moveWorkspace(moved, '$_other/api');

        expect(moved.workingDirectory, '$_other/api');
        expect(moved.branch, 'dev');
        expect(moved.folderPath, _other);
      },
    );

    test('is bound to the chat it started on, not to the selection', () async {
      final answer = Completer<Map<String, Object?>>();
      onMove = (_) => answer.future;
      chat.select('s1');
      final first = thread('s1');
      final second = thread('s2');

      final future = chat.moveWorkspace(first, _other);
      await settle();
      chat.select('s2');
      answer.complete({'cwd': _other});
      await future;

      expect(first.workingDirectory, _other);
      expect(second.workingDirectory, '/srv/two');
      expect(chat.selectedId, 's2');
      expect(chat.workspaceMoveOf(second).phase, WorkspaceMovePhase.idle);
    });

    test('refuses while a reply runs and sends nothing', () async {
      final target = thread('s1');
      chat.select('s1');
      await settle();
      chat.submit('go', const []);
      await settle();
      expect(target.isReplying, isTrue);

      expect(chat.workspaceMoveBlock(target), WorkspaceMoveBlock.replying);
      expect(
        await chat.moveWorkspace(target, _other),
        WorkspaceMoveBlock.replying,
      );
      expect(rpcCalls, isEmpty);
    });

    test(
      'a reply that started before the confirmation sends nothing',
      () async {
        final target = thread('s1');
        expect(chat.workspaceMoveBlock(target), isNull);

        chat.select('s1');
        await settle();
        chat.submit('go', const []);
        await settle();

        expect(
          await chat.moveWorkspace(target, _other),
          WorkspaceMoveBlock.replying,
        );
        expect(rpcCalls, isEmpty);
      },
    );

    test('refuses a Bot Chat registry chat', () async {
      final target = thread('s1')
        ..botContext = const BotChatContext(
          bot: BotModeBot(serverId: 'server', name: 'research', revision: 0),
          rootId: 's1',
          storedId: 's1',
        );

      expect(
        await chat.moveWorkspace(target, _other),
        WorkspaceMoveBlock.botChat,
      );
      expect(rpcCalls, isEmpty);
    });

    test(
      'refuses a chat that is not an open stored chat of the profile',
      () async {
        final unopened = ChatThread(
          id: 'elsewhere',
          title: 'Other profile',
          updatedAt: DateTime(2026),
          remote: true,
        );
        chat.newThread();
        final draft = chat.selectedThread!;

        expect(
          await chat.moveWorkspace(unopened, _other),
          WorkspaceMoveBlock.notAvailable,
        );
        expect(
          await chat.moveWorkspace(draft, _other),
          WorkspaceMoveBlock.notAvailable,
        );
        expect(rpcCalls, isEmpty);
      },
    );

    test(
      'rejects a path that is not absolute or ~-led before any request',
      () async {
        expect(
          await chat.moveWorkspace(thread('s1'), 'code/other'),
          WorkspaceMoveBlock.notAServerPath,
        );
        expect(rpcCalls, isEmpty);
        expect(
          chat.workspaceMoveOf(thread('s1')).phase,
          WorkspaceMovePhase.idle,
        );
      },
    );

    test('4017 says the folder is missing and changes nothing', () async {
      onMove = (_) async => throw const GatewayRpcException(4017, 'no $_other');
      final target = thread('s1');

      await chat.moveWorkspace(target, _other);

      expect(
        chat.workspaceMoveOf(target).phase,
        WorkspaceMovePhase.folderMissing,
      );
      expect(target.workingDirectory, _demo);
      expect(rpcCalls, hasLength(1));
    });

    test(
      '4007 and 4064 end in their own states with nothing changed',
      () async {
        final target = thread('s1');
        onMove = (_) async => throw const GatewayRpcException(4007, 'gone');
        await chat.moveWorkspace(target, _other);
        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.chatGone);

        onMove = (_) async => throw const GatewayRpcException(4064, 'gone');
        await chat.moveWorkspace(target, _other);
        expect(
          chat.workspaceMoveOf(target).phase,
          WorkspaceMovePhase.profileGone,
        );
        expect(target.workingDirectory, _demo);
      },
    );

    test('an unknown method hides the action for the connection', () async {
      onMove = (_) async =>
          throw const GatewayRpcException(kGatewayMethodNotFound, 'unknown');
      final target = thread('s1');

      await chat.moveWorkspace(target, _other);

      expect(chat.workspaceMoveSupported, isFalse);
      expect(chat.workspaceMoveBlock(target), WorkspaceMoveBlock.unsupported);
      expect(
        await chat.moveWorkspace(target, _other),
        WorkspaceMoveBlock.unsupported,
      );
      expect(rpcCalls, hasLength(1));
      expect(target.workingDirectory, _demo);
    });

    test('5007 re-reads first and shows what the read found', () async {
      onMove = (_) async =>
          throw const GatewayRpcException(5007, 'move failed');
      reread = () => (status: 200, body: _row('s1', cwd: _other));
      final target = thread('s1');

      await chat.moveWorkspace(target, _other);
      await settle();

      expect(rpcCalls, hasLength(1));
      expect(server.requestsTo('GET', '/api/sessions/s1'), hasLength(1));
      final state = chat.workspaceMoveOf(target);
      expect(state.phase, WorkspaceMovePhase.changed);
      expect(state.folder, _other);
      expect(target.workingDirectory, _other);
      expect(target.folderPath, _other);
    });

    test('a lost answer re-reads with the profile and never resends', () async {
      onMove = (_) async => throw const GatewayConnectionClosed();
      final target = thread('s1');

      await chat.moveWorkspace(target, _other);
      await settle();

      expect(rpcCalls, hasLength(1));
      final read = server.requestsTo('GET', '/api/sessions/s1').single;
      expect(read.queryParameters['profile'], 'work');
      // The row still names the old folder.
      expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.unchanged);
      expect(target.workingDirectory, _demo);
    });

    test(
      'the success text comes from the read, not from what was asked',
      () async {
        onMove = (_) async => throw const GatewayConnectionClosed();
        reread = () => (status: 200, body: _row('s1', cwd: '$_other/web'));
        final target = thread('s1');

        await chat.moveWorkspace(target, '$_other/web');
        await settle();

        expect(chat.workspaceMoveOf(target).folder, '$_other/web');
        expect(target.workingDirectory, '$_other/web');
      },
    );

    test('a re-read that names neither folder changes nothing', () async {
      onMove = (_) async => throw const GatewayConnectionClosed();
      reread = () => (status: 200, body: _row('s1', cwd: '/srv/else'));
      final target = thread('s1');

      await chat.moveWorkspace(target, _other);
      await settle();

      expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.unchanged);
      expect(target.workingDirectory, _demo);
    });

    test('a re-read that finds the chat gone says so', () async {
      onMove = (_) async => throw const GatewayConnectionClosed();
      reread = () => (status: 404, body: {'detail': 'Session not found'});
      final target = thread('s1');

      await chat.moveWorkspace(target, _other);
      await settle();

      expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.chatGone);
    });

    test('a ~-led target counts as moved when the folder changed', () async {
      onMove = (_) async => throw const GatewayConnectionClosed();
      reread = () => (status: 200, body: _row('s1', cwd: _other));
      final target = thread('s1');

      await chat.moveWorkspace(target, '~/code/other');
      await settle();

      expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.changed);
    });

    test('Send is held while the move is in flight', () async {
      final answer = Completer<Map<String, Object?>>();
      onMove = (_) => answer.future;
      chat.select('s1');
      await settle();
      final target = thread('s1');

      final future = chat.moveWorkspace(target, _other);
      await settle();

      expect(chat.workspaceMoveOf(target).inFlight, isTrue);
      expect(chat.workspaceMoveBlock(target), WorkspaceMoveBlock.moving);
      expect(await chat.submit('wait', const []), isFalse);
      expect(transport.sends, isEmpty);
      expect(
        await chat.moveWorkspace(target, '/other'),
        WorkspaceMoveBlock.moving,
      );

      answer.complete({'cwd': _other});
      await future;
      expect(await chat.submit('now', const []), isTrue);
      expect(transport.sends, hasLength(1));
    });

    test(
      'no folder, project or branch reaches an event or the telemetry',
      () async {
        onMove = (_) async => throw const GatewayConnectionClosed();
        await chat.moveWorkspace(thread('s1'), _other);
        await settle();

        for (final (name, attributes) in logged) {
          expect('$name $attributes', isNot(contains('/')));
        }
      },
    );
  });

  group('a move across reloads and the background', () {
    test(
      'keeps the hold and shows the outcome on the reloaded thread',
      () async {
        final answer = Completer<Map<String, Object?>>();
        onMove = (_) => answer.future;
        final before = thread('s1');

        final future = chat.moveWorkspace(before, _other);
        await pumpEventQueue();
        await chat.loadThreads('work');
        final after = thread('s1');

        expect(after, isNot(same(before)));
        expect(chat.workspaceMoveOf(after).inFlight, isTrue);
        expect(chat.workspaceMoveBlock(after), WorkspaceMoveBlock.moving);
        expect(
          await chat.moveWorkspace(after, '/third'),
          WorkspaceMoveBlock.moving,
        );
        chat.select('s1');
        expect(await chat.submit('wait', const []), isFalse);
        expect(rpcCalls, hasLength(1));

        answer.complete({'cwd': _other, 'git_repo_root': _other});
        await future;

        expect(chat.workspaceMoveOf(after).phase, WorkspaceMovePhase.changed);
        expect(after.workingDirectory, _other);
        expect(after.folderPath, _other);
      },
    );

    test(
      'an answer that arrives in the background is "could not confirm"',
      () async {
        final answer = Completer<Map<String, Object?>>();
        onMove = (_) => answer.future;
        final target = thread('s1');

        final future = chat.moveWorkspace(target, _other);
        await pumpEventQueue();
        activity.value = false;
        await pumpEventQueue();
        answer.complete({'cwd': _other});
        await future;

        expect(
          chat.workspaceMoveOf(target).phase,
          WorkspaceMovePhase.couldNotConfirm,
        );
        expect(chat.workspaceMoveOf(target).inFlight, isFalse);
        expect(rpcCalls, hasLength(1));

        // Back in front: "check again" reads the row and settles it.
        activity.value = true;
        await pumpEventQueue();
        reread = () => (status: 200, body: _row('s1', cwd: _other));
        final again = thread('s1');
        expect(chat.workspaceMoveBlock(again), isNull);
        await chat.recheckWorkspaceMove(again);
        await pumpEventQueue();

        expect(chat.workspaceMoveOf(again).phase, WorkspaceMovePhase.changed);
        expect(again.workingDirectory, _other);
        expect(rpcCalls, hasLength(1));
      },
    );

    test('a move that never answers while in the background still ends', () {
      fakeAsync((async) {
        onMove = (_) => Completer<Map<String, Object?>>().future;
        final target = thread('s1');

        unawaited(chat.moveWorkspace(target, _other));
        async.flushMicrotasks();
        activity.value = false;
        async.elapse(const Duration(seconds: 11));
        async.flushMicrotasks();

        expect(chat.workspaceMoveOf(target).inFlight, isFalse);
        expect(
          chat.workspaceMoveOf(target).phase,
          WorkspaceMovePhase.couldNotConfirm,
        );
      });
    });
  });

  group('what keeps a chat from being moved', () {
    test('a queued prompt and a settle wait block it', () async {
      chat.select('s1');
      await pumpEventQueue();
      final target = thread('s1');
      await chat.submit('first', const []);
      await chat.submit('second', const []);
      await pumpEventQueue();
      expect(chat.workspaceMoveBlock(target), WorkspaceMoveBlock.replying);

      transport.sends.single
        ..emit(const ReplyStarted())
        ..emit(const ReplyCompleted('done'));
      await pumpEventQueue();

      // The reply ended; the queue still waits for the session to settle.
      expect(chat.workspaceMoveBlock(target), WorkspaceMoveBlock.replying);
      expect(
        await chat.moveWorkspace(target, _other),
        WorkspaceMoveBlock.replying,
      );
      expect(rpcCalls, isEmpty);
    });

    test('a turn of another client blocks it', () async {
      transport.active['s1'] = 'working';
      await chat.refreshActive();
      final target = thread('s1');

      expect(chat.workspaceMoveBlock(target), WorkspaceMoveBlock.replying);
      expect(
        await chat.moveWorkspace(target, _other),
        WorkspaceMoveBlock.replying,
      );
      expect(rpcCalls, isEmpty);
    });
  });

  group('a move that waits, on a fake clock', () {
    void withClock(void Function(FakeAsync async) body) {
      fakeAsync((async) {
        body(async);
      });
    }

    test('no answer for 10 s is a lost answer: re-read, no resend', () {
      withClock((async) {
        final answer = Completer<Map<String, Object?>>();
        onMove = (_) => answer.future;
        final target = thread('s1');

        unawaited(chat.moveWorkspace(target, _other));
        async.flushMicrotasks();
        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.moving);

        async.elapse(const Duration(seconds: 9));
        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.moving);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(rpcCalls, hasLength(1));
        expect(
          server.requestsTo('GET', '/api/sessions/s1'),
          hasLength(1),
          reason: 'the chat is read again',
        );
        expect(
          chat.workspaceMoveOf(target).phase,
          WorkspaceMovePhase.unchanged,
        );
      });
    });

    test('a late answer still shows the folder it reports', () {
      withClock((async) {
        final answer = Completer<Map<String, Object?>>();
        onMove = (_) => answer.future;
        final target = thread('s1');

        unawaited(chat.moveWorkspace(target, _other));
        async.elapse(const Duration(seconds: 11));
        async.flushMicrotasks();
        expect(
          chat.workspaceMoveOf(target).phase,
          WorkspaceMovePhase.unchanged,
        );

        answer.complete({'cwd': _other, 'git_repo_root': _other});
        async.flushMicrotasks();

        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.changed);
        expect(target.workingDirectory, _other);
        expect(rpcCalls, hasLength(1));
      });
    });

    test(
      'no re-read answer for 10 s is "could not confirm", offered again',
      () {
        withClock((async) {
          onMove = (_) async => throw const GatewayConnectionClosed();
          final reads = <Completer<FakeResponse>>[];
          server.onRequest('GET', '/api/sessions/s1', (_) {
            final gate = Completer<FakeResponse>();
            reads.add(gate);
            return gate.future;
          });
          final target = thread('s1');

          unawaited(chat.moveWorkspace(target, _other));
          async.flushMicrotasks();
          expect(
            chat.workspaceMoveOf(target).phase,
            WorkspaceMovePhase.checking,
          );
          expect(chat.workspaceMoveBlock(target), WorkspaceMoveBlock.moving);

          async.elapse(const Duration(seconds: 11));
          async.flushMicrotasks();

          expect(
            chat.workspaceMoveOf(target).phase,
            WorkspaceMovePhase.couldNotConfirm,
          );
          expect(rpcCalls, hasLength(1));
          // The action is offered again, and Send is no longer held.
          expect(chat.workspaceMoveBlock(target), isNull);

          // "Check again" reads the row and sends nothing else.
          unawaited(chat.recheckWorkspaceMove(target));
          async.elapse(const Duration(milliseconds: 5));
          expect(reads, hasLength(2));
          reads.last.complete((status: 200, body: _row('s1', cwd: _other)));
          async.elapse(const Duration(milliseconds: 5));

          expect(
            chat.workspaceMoveOf(target).phase,
            WorkspaceMovePhase.changed,
          );
          expect(rpcCalls, hasLength(1));
        });
      },
    );

    test('a late move answer during the re-read is not overruled by it', () {
      withClock((async) {
        final answer = Completer<Map<String, Object?>>();
        onMove = (_) => answer.future;
        final gate = Completer<FakeResponse>();
        server.onRequest('GET', '/api/sessions/s1', (_) => gate.future);
        final target = thread('s1');

        unawaited(chat.moveWorkspace(target, _other));
        async.elapse(const Duration(seconds: 11));
        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.checking);

        answer.complete({'cwd': _other, 'git_repo_root': _other});
        async.elapse(const Duration(milliseconds: 5));
        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.changed);

        // The re-read comes back with the row as it was before.
        gate.complete((status: 200, body: _row('s1')));
        async.elapse(const Duration(milliseconds: 5));

        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.changed);
        expect(target.workingDirectory, _other);
        expect(rpcCalls, hasLength(1));
      });
    });

    test('"check again" does not drop a move answer still on its way', () {
      withClock((async) {
        final answer = Completer<Map<String, Object?>>();
        onMove = (_) => answer.future;
        final gates = <Completer<FakeResponse>>[];
        server.onRequest('GET', '/api/sessions/s1', (_) {
          final gate = Completer<FakeResponse>();
          gates.add(gate);
          return gate.future;
        });
        final target = thread('s1');

        unawaited(chat.moveWorkspace(target, _other));
        async.elapse(const Duration(seconds: 11));
        async.elapse(const Duration(seconds: 11));
        expect(
          chat.workspaceMoveOf(target).phase,
          WorkspaceMovePhase.couldNotConfirm,
        );

        unawaited(chat.recheckWorkspaceMove(target));
        async.elapse(const Duration(milliseconds: 5));
        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.checking);

        answer.complete({'cwd': _other});
        async.elapse(const Duration(milliseconds: 5));

        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.changed);
        expect(rpcCalls, hasLength(1));
      });
    });

    test('the requester keeps the move longer than the 10 s wait', () {
      withClock((async) {
        final answer = Completer<Map<String, Object?>>();
        onMove = (_) => answer.future;
        final target = thread('s1');

        unawaited(chat.moveWorkspace(target, _other));
        async.elapse(const Duration(seconds: 30));
        // Still not abandoned by the requester: the answer is the move's.
        answer.complete({'cwd': _other});
        async.elapse(const Duration(milliseconds: 5));

        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.changed);
      });
    });

    test('a late re-read answer replaces "could not confirm"', () {
      withClock((async) {
        onMove = (_) async => throw const GatewayConnectionClosed();
        final gate = Completer<FakeResponse>();
        server.onRequest('GET', '/api/sessions/s1', (_) => gate.future);
        final target = thread('s1');

        unawaited(chat.moveWorkspace(target, _other));
        async.elapse(const Duration(seconds: 11));
        async.flushMicrotasks();
        expect(
          chat.workspaceMoveOf(target).phase,
          WorkspaceMovePhase.couldNotConfirm,
        );

        gate.complete((status: 200, body: _row('s1', cwd: _other)));
        async.elapse(const Duration(milliseconds: 5));

        expect(chat.workspaceMoveOf(target).phase, WorkspaceMovePhase.changed);
        expect(target.workingDirectory, _other);
      });
    });
  });

  group('the catalog loader', () {
    late FakeHermesServer catalogServer;

    WorkspaceCatalogLoader build({String profile = 'work'}) =>
        WorkspaceCatalogLoader(
          repository: HermesWorkspacesRepository(
            catalogServer.client().raw,
            (method, params, {required timeout}) async => {},
          ),
          profile: profile,
        );

    setUp(() => catalogServer = FakeHermesServer());

    test('reads once and names the profile', () async {
      catalogServer.on('GET', '/api/chat/workspaces', _catalogBody);
      final loader = build();
      addTearDown(loader.dispose);
      expect(loader.status, WorkspaceCatalogStatus.idle);

      final loading = loader.load();
      expect(loader.status, WorkspaceCatalogStatus.loading);
      await loading;
      await loader.load();

      expect(loader.status, WorkspaceCatalogStatus.ready);
      expect(loader.defaultFolder, _demo);
      expect(loader.projectFor('$_demo/api')!.name, 'Demo');
      expect(loader.projectFor('/elsewhere'), isNull);
      final reads = catalogServer.requestsTo('GET', '/api/chat/workspaces');
      expect(reads, hasLength(1));
      expect(reads.single.queryParameters['profile'], 'work');
    });

    test('maps failures to their states', () async {
      Future<WorkspaceCatalogStatus> statusFor(int status, Object body) async {
        catalogServer.on('GET', '/api/chat/workspaces', body, status: status);
        final loader = build();
        addTearDown(loader.dispose);
        await loader.load();
        return loader.status;
      }

      expect(
        await statusFor(404, {'detail': 'Not Found'}),
        WorkspaceCatalogStatus.unsupported,
      );
      expect(
        await statusFor(404, {'detail': "Profile 'x' does not exist."}),
        WorkspaceCatalogStatus.unknownProfile,
      );
      expect(
        await statusFor(500, {'detail': 'boom'}),
        WorkspaceCatalogStatus.failed,
      );
      expect(
        await statusFor(503, {'detail': 'down'}),
        WorkspaceCatalogStatus.offline,
      );
    });

    test(
      'a reload keeps the earlier catalog while it runs and after a failure',
      () async {
        catalogServer.on('GET', '/api/chat/workspaces', _catalogBody);
        final loader = build();
        addTearDown(loader.dispose);
        await loader.load();

        catalogServer.on('GET', '/api/chat/workspaces', {'d': 1}, status: 500);
        final again = loader.reload();
        expect(loader.status, WorkspaceCatalogStatus.loading);
        expect(loader.defaultFolder, _demo);
        await again;

        expect(loader.status, WorkspaceCatalogStatus.failed);
        expect(loader.defaultFolder, _demo);
      },
    );

    test('a loading with no answer for 10 s is stalled, and a late answer '
        'still applies', () {
      fakeAsync((async) {
        final gate = Completer<FakeResponse>();
        catalogServer.onRequest(
          'GET',
          '/api/chat/workspaces',
          (_) => gate.future,
        );
        final loader = build();

        unawaited(loader.load());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 9));
        expect(loader.stalled, isFalse);

        async.elapse(const Duration(seconds: 2));
        expect(loader.status, WorkspaceCatalogStatus.loading);
        expect(loader.stalled, isTrue);
        expect(
          catalogServer.requestsTo('GET', '/api/chat/workspaces'),
          hasLength(1),
        );

        gate.complete((status: 200, body: _catalogBody));
        async.elapse(const Duration(milliseconds: 5));

        expect(loader.status, WorkspaceCatalogStatus.ready);
        expect(loader.stalled, isFalse);
        expect(loader.defaultFolder, _demo);
        loader.dispose();
      });
    });

    test('an answer after dispose is dropped', () {
      fakeAsync((async) {
        final gate = Completer<FakeResponse>();
        catalogServer.onRequest(
          'GET',
          '/api/chat/workspaces',
          (_) => gate.future,
        );
        final loader = build();
        unawaited(loader.load());
        async.flushMicrotasks();

        loader.dispose();
        gate.complete((status: 200, body: _catalogBody));
        async.elapse(const Duration(milliseconds: 5));

        expect(loader.catalog, isNull);
      });
    });

    test('a reload replaces a read still out', () async {
      final first = Completer<FakeResponse>();
      var calls = 0;
      catalogServer.onRequest('GET', '/api/chat/workspaces', (_) {
        calls++;
        return calls == 1
            ? first.future
            : Future.value((status: 200, body: _catalogBody));
      });
      final loader = build();
      addTearDown(loader.dispose);

      final slow = loader.load();
      await pumpEventQueue();
      await loader.reload();
      first.complete((
        status: 200,
        body: {..._catalogBody, 'default_cwd': '/old'},
      ));
      await slow;

      expect(loader.defaultFolder, _demo);
    });
  });
}
