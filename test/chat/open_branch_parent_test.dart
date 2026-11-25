import 'dart:async';
import 'dart:convert' show jsonEncode;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/profiles/profile_resolver.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_builder.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/recorded_breadcrumbs.dart';

/// What a tap on "Branched from …" does: one read of the parent's tip, then
/// the open. The ids and titles are distinctive so a search of the recorded
/// breadcrumbs can prove none of them is there.
const _parent = 'parent-secret-id';
const _parentTitle = 'Secret parent title';
const _tip = 'tip-secret-id';
const _tipTitle = 'Secret tip title';
const _farParent = 'far-parent-id';
const _farTitle = 'Secret far title';

String _descendant(String id) => '/api/sessions/$id/latest-descendant';

Map<String, Object?> _answer(String requested, String tip) => {
  'requested_session_id': requested,
  'session_id': tip,
  'path': [requested, tip],
  'changed': requested != tip,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late ValueNotifier<bool> activity;
  late AppLockController lock;
  late RecordedBreadcrumbs crumbs;
  late AttentionNotifier attention;
  late ChatController chat;

  Future<void> flush() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ChatThread thread(String id) => chat.threads.firstWhere((t) => t.id == id);
  ChatThread branch() => thread('branch');

  /// The one outcome the breadcrumb of the last tap carries.
  String? outcome() {
    final all = crumbs.named('chat.branch_parent.open');
    return all.isEmpty ? null : all.last['outcome'] as String?;
  }

  void answerParent([String? id]) =>
      server.on('GET', _descendant(_parent), _answer(_parent, id ?? _parent));

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'hermes.app_lock_enabled': true,
        });
    activity = ValueNotifier(true);
    transport = FakeChatTransport();
    crumbs = RecordedBreadcrumbs();
    lock = AppLockController(
      authenticator: FakeDeviceAuthenticator(),
      coverWhenInactive: false,
    );
    await lock.load();
    final branchRow = sessionRow(
      id: 'branch',
      title: 'Try another way',
      lastActive: 1780000500,
    )..['_branched_from'] = _parent;
    final farBranchRow = sessionRow(
      id: 'far-branch',
      title: 'From far away',
      lastActive: 1780000400,
    )..['_branched_from'] = _farParent;
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          branchRow,
          farBranchRow,
          sessionRow(id: _parent, title: _parentTitle, lastActive: 1780000300),
          sessionRow(id: 'other', title: 'Unrelated', lastActive: 1780000200),
        ]),
      )
      // A tip the list does not hold, and a parent beyond its first page.
      ..on(
        'GET',
        '/api/sessions/$_tip',
        sessionDetailRow(id: _tip, title: _tipTitle),
      )
      ..on(
        'GET',
        '/api/sessions/$_farParent',
        sessionDetailRow(id: _farParent, title: _farTitle),
      );
    for (final id in [
      'branch',
      'far-branch',
      _parent,
      _tip,
      _farParent,
      'other',
    ]) {
      server.on('GET', '/api/sessions/$id/messages', messageListBody(id, []));
    }
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      profileResolver: ProfileResolver.known('default'),
      repository: HermesChatRepository(server.client().raw),
      activity: activity,
      appLock: lock,
      transport: transport,
      attention: attention,
      breadcrumbs: crumbs.breadcrumbs,
      report: (_) {},
    );
    await chat.loadThreads();
    await flush();
    chat.select('branch');
    await flush();
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
    activity.dispose();
    lock.dispose();
  });

  group('a tap on the original', () {
    test('a loaded parent is opened after one read of its tip', () async {
      answerParent();
      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.resting);
      expect(chat.branchParentTitleOf(branch()), _parentTitle);

      await chat.openBranchParent(branch());
      await flush();

      expect(server.requestsTo('GET', _descendant(_parent)), hasLength(1));
      expect(chat.selectedId, _parent);
      expect(outcome(), 'opened');
      // Nothing else was written: the parent and the branch stay as they are.
      expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
    });

    test('a parent that is not loaded is read by id and opened', () async {
      server.on(
        'GET',
        _descendant(_farParent),
        _answer(_farParent, _farParent),
      );
      chat.select('far-branch');
      await flush();
      expect(chat.branchParentTitleOf(thread('far-branch')), isNull);

      await chat.openBranchParent(thread('far-branch'));
      await flush();

      expect(server.requestsTo('GET', '/api/sessions/$_farParent'), isNotEmpty);
      expect(chat.selectedId, _farParent);
      expect(outcome(), 'opened');
    });

    test('a parent that compressed since opens its tip, and the row then '
        'names it', () async {
      answerParent(_tip);

      await chat.openBranchParent(branch());
      await flush();

      expect(chat.selectedId, _tip);
      expect(chat.branchParentTitleOf(branch()), _tipTitle);
      expect(outcome(), 'opened');
    });

    test(
      'the row names the tip even when the original is listed above it',
      () async {
        server.on(
          'GET',
          '/api/sessions',
          sessionListBody([
            sessionRow(
              id: _parent,
              title: _parentTitle,
              lastActive: 1780000900,
            ),
            sessionRow(id: _tip, title: _tipTitle, lastActive: 1780000800),
            sessionRow(id: 'branch', title: 'Try another way')
              ..['_branched_from'] = _parent,
          ]),
        );
        answerParent(_tip);
        await chat.loadThreads();
        await flush();
        chat.select('branch');
        await flush();
        expect(chat.branchParentTitleOf(branch()), _parentTitle);

        await chat.openBranchParent(branch());
        await flush();

        expect(chat.branchParentTitleOf(branch()), _tipTitle);
      },
    );

    test('a deleted parent ends in deleted, and a second tap sends '
        'nothing', () async {
      server.on('GET', _descendant(_parent), {
        'detail': 'Session not found',
      }, status: 404);

      await chat.openBranchParent(branch());
      await flush();

      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.deleted);
      expect(chat.canOpenBranchParent(branch()), isFalse);
      expect(chat.selectedId, 'branch');
      expect(outcome(), 'deleted');

      await chat.openBranchParent(branch());
      await flush();

      expect(server.requestsTo('GET', _descendant(_parent)), hasLength(1));
      expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
    });

    for (final failure in [
      (name: '5xx', status: 503, body: <String, Object?>{'detail': 'down'}),
      (
        name: 'a route the server lacks',
        status: 404,
        body: <String, Object?>{'detail': 'Not Found'},
      ),
    ]) {
      test('${failure.name} ends in unreachable, resends nothing, and the '
          'next tap asks again', () async {
        server.on(
          'GET',
          _descendant(_parent),
          failure.body,
          status: failure.status,
        );

        await chat.openBranchParent(branch());
        await flush();

        expect(
          chat.branchParentStatusOf(branch()),
          BranchParentStatus.unreachable,
        );
        expect(chat.canOpenBranchParent(branch()), isTrue);
        expect(chat.selectedId, 'branch');
        expect(outcome(), 'unreachable');
        await flush();
        expect(server.requestsTo('GET', _descendant(_parent)), hasLength(1));

        answerParent();
        await chat.openBranchParent(branch());
        await flush();

        expect(server.requestsTo('GET', _descendant(_parent)), hasLength(2));
        expect(chat.selectedId, _parent);
        expect(outcome(), 'opened');
      });
    }

    test('a read with no answer for 10 s ends in unreachable', () {
      server.onRequest(
        'GET',
        _descendant(_parent),
        (_) => Completer<FakeResponse>().future,
      );
      fakeAsync((async) {
        unawaited(chat.openBranchParent(branch()));
        async.flushMicrotasks();
        expect(chat.branchParentStatusOf(branch()), BranchParentStatus.opening);

        async.elapse(const Duration(seconds: 9));
        expect(chat.branchParentStatusOf(branch()), BranchParentStatus.opening);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(
          chat.branchParentStatusOf(branch()),
          BranchParentStatus.unreachable,
        );
        expect(chat.selectedId, 'branch');
        expect(outcome(), 'unreachable');
        expect(server.requestsTo('GET', _descendant(_parent)), hasLength(1));
      });
    });

    test('a tap while opening is ignored', () async {
      final answer = Completer<FakeResponse>();
      server.onRequest('GET', _descendant(_parent), (_) => answer.future);

      final first = chat.openBranchParent(branch());
      await flush();
      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.opening);
      expect(chat.canOpenBranchParent(branch()), isFalse);
      await chat.openBranchParent(branch());

      expect(server.requestsTo('GET', _descendant(_parent)), hasLength(1));

      answer.complete((status: 200, body: _answer(_parent, _parent)));
      await first;
      await flush();

      expect(chat.selectedId, _parent);
      expect(crumbs.named('chat.branch_parent.open'), hasLength(1));
    });

    test('a chat with no parent sends nothing', () async {
      chat.select('other');
      await flush();

      await chat.openBranchParent(thread('other'));

      expect(chat.branchParentStatusOf(thread('other')), isNull);
      expect(server.requests.where((r) => r.path.contains('latest')), isEmpty);
      expect(outcome(), isNull);
    });
  });

  group('an answer that lands too late', () {
    late Completer<FakeResponse> answer;

    setUp(() {
      answer = Completer<FakeResponse>();
      server.onRequest('GET', _descendant(_parent), (_) => answer.future);
    });

    Future<void> land() async {
      answer.complete((status: 200, body: _answer(_parent, _parent)));
      await flush();
    }

    test('under the App Lock cover leaves the selection and the row at '
        'rest', () async {
      final tap = chat.openBranchParent(branch());
      await flush();
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await flush();
      expect(lock.locked, isTrue);

      await land();
      await tap;

      expect(chat.selectedId, 'branch');
      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.resting);
      expect(outcome(), 'dropped');
    });

    test('after the user chose another chat opens nothing', () async {
      final tap = chat.openBranchParent(branch());
      await flush();
      chat.select('other');
      await flush();

      await land();
      await tap;

      expect(chat.selectedId, 'other');
      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.resting);
      expect(outcome(), 'dropped');
    });

    test('after App Lock engaged and was lifted opens nothing', () async {
      final tap = chat.openBranchParent(branch());
      await flush();
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await flush();
      await lock.unlock();
      expect(lock.locked, isFalse);

      await land();
      await tap;

      expect(chat.selectedId, 'branch');
      expect(outcome(), 'dropped');
    });

    test('a tap made under the App Lock cover sends nothing', () async {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await flush();
      expect(lock.locked, isTrue);
      expect(chat.canOpenBranchParent(branch()), isFalse);

      await chat.openBranchParent(branch());

      expect(server.requestsTo('GET', _descendant(_parent)), isEmpty);
      expect(outcome(), isNull);
    });

    test('after a profile switch opens nothing', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'elsewhere', title: 'Elsewhere')]),
        query: {'profile': 'work'},
      );
      final tap = chat.openBranchParent(branch());
      await flush();
      await chat.loadThreads('work');
      await flush();

      await land();
      await tap;

      expect(chat.profile, 'work');
      expect(chat.selectedId, isNot(_parent));
      expect(outcome(), 'dropped');
    });

    test('after sign-out opens nothing', () async {
      final tap = chat.openBranchParent(branch());
      await flush();
      activity.value = false;
      await flush();

      await land();
      await tap;
      await flush();

      expect(chat.selectedId, isNot(_parent));
      expect(outcome(), 'dropped');
    });
  });

  group('what is remembered', () {
    Future<void> learnDeleted() async {
      server.on('GET', _descendant(_parent), {
        'detail': 'Session not found',
      }, status: 404);
      await chat.openBranchParent(branch());
      await flush();
      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.deleted);
    }

    test('an ordinary list read keeps the deleted parent', () async {
      await learnDeleted();

      await chat.loadThreads();
      await flush();

      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.deleted);
    });

    test('a profile switch forgets it', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'elsewhere', title: 'Elsewhere')]),
        query: {'profile': 'work'},
      );
      await learnDeleted();

      await chat.loadThreads('work');
      await flush();
      await chat.loadThreads();
      await flush();

      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.resting);
    });

    test('sign-out forgets it', () async {
      await learnDeleted();

      activity.value = false;
      await flush();
      activity.value = true;
      await flush();

      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.resting);
    });

    test('a server change forgets it', () async {
      await learnDeleted();

      chat.clearWorkspaceState();

      expect(chat.branchParentStatusOf(branch()), BranchParentStatus.resting);
    });

    test(
      'App Lock keeps the row at rest and forgets an open in flight',
      () async {
        final answer = Completer<FakeResponse>();
        server.onRequest('GET', _descendant(_parent), (_) => answer.future);
        final tap = chat.openBranchParent(branch());
        await flush();
        expect(chat.branchParentStatusOf(branch()), BranchParentStatus.opening);

        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        await flush();

        expect(chat.branchParentStatusOf(branch()), BranchParentStatus.resting);
        answer.complete((status: 200, body: _answer(_parent, _parent)));
        await tap;
      },
    );
  });

  group('privacy', () {
    test('the breadcrumb carries the outcome and nothing else', () async {
      for (final (status, body, expected) in [
        (200, _answer(_parent, _tip), 'opened'),
        (404, {'detail': 'Session not found'}, 'deleted'),
        (503, {'detail': 'down'}, 'unreachable'),
      ]) {
        chat.select('branch');
        await flush();
        crumbs.all.clear();
        server.on('GET', _descendant(_parent), body, status: status);
        // A deleted parent is remembered; a fresh controller state per case
        // is what the sign-out test above covers.
        chat.clearWorkspaceState();

        await chat.openBranchParent(branch());
        await flush();

        final recorded = crumbs.named('chat.branch_parent.open');
        expect(recorded, hasLength(1), reason: expected);
        expect(recorded.single.keys, ['outcome']);
        expect(recorded.single['outcome'], expected);
        for (final secret in [_parent, _parentTitle, _tip, _tipTitle]) {
          expect(crumbs.text, isNot(contains(secret)), reason: expected);
        }
      }
    });

    test('the surface snapshot names no original', () async {
      server
        ..on('GET', '/api/profiles', {
          'profiles': [
            {'name': 'default'},
          ],
        })
        ..on('GET', '/api/dashboard/plugins', [])
        ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
        ..on('GET', '/api/cron/jobs', []);

      final built = await SurfaceSnapshotBuilder(
        HermesRepositories(server.client()),
        timeout: const Duration(milliseconds: 200),
      ).build(signedIn: true, refreshRemote: true);

      // The list holds the branch whose original it does not hold.
      expect(jsonEncode(built.snapshot.toJson()), contains('From far away'));
      expect(jsonEncode(built.snapshot.toJson()), isNot(contains(_farParent)));
    });
  });
}
