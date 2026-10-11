import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/intents/request_intents.dart';
import 'package:hermes_app/src/notifications/request_answers.dart'
    show kRequestAnswersPort;
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_surface_storage.dart';
import '../support/memory_token_store.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

const _url = 'http://hermes.test';
const _command = 'rm -rf /srv/secret-project';
const _description = 'Deletes the project';

Map<String, Object?> _session(String key, {String title = 'Trip plan'}) => {
  'id': 'rt-$key',
  'session_key': key,
  'title': title,
  'status': 'waiting',
  'last_active': 1780000000.0,
  'message_count': 2,
};

Map<String, Object?> _approval(
  String id, {
  List<String> choices = const ['once', 'session', 'deny'],
}) => {
  'request_id': id,
  'command': _command,
  'description': _description,
  'choices': choices,
};

PendingRequest _stored(String id, {String chat = 'chat-a', int hour = 9}) =>
    PendingRequest(
      profile: 'work',
      threadId: chat,
      threadTitle: 'Trip plan',
      kind: PendingKind.approval,
      requestId: id,
      createdAt: DateTime.utc(2026, 10, 10, hour),
    );

void main() {
  late FakeHermesServer server;
  late FakeGateway gateway;
  late FakeSurfaceStorage storage;
  late SurfaceSnapshotStore store;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late MemoryTokenStore tokens;
  var lockOn = false;

  /// What `session.active_list` answers, by profile.
  late Map<String?, List<Map<String, Object?>>> sessions;

  /// What `approval.pending` answers, by runtime session id.
  late Map<String, List<Map<String, Object?>>> approvals;

  setUp(() {
    lockOn = false;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({kSavedServerUrlKey: _url});
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': false, 'version': '0.9.0'})
      ..on(
        'GET',
        '/',
        '<script>window.__HERMES_SESSION_TOKEN__="page-token"</script>',
      )
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'd1', title: 'Trip plan')]),
      )
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
      ..on('GET', '/api/cron/jobs', []);
    gateway = FakeGateway();
    sessions = {};
    approvals = {};
    gateway.handlers['session.active_list'] = (params) => {
      'sessions': sessions[params['profile']] ?? [],
    };
    gateway.handlers['approval.pending'] = (params) => {
      'approvals': approvals[params['session_id']] ?? [],
    };
    storage = FakeSurfaceStorage();
    events = RecordedEvents();
    store = SurfaceSnapshotStore(storage: storage, events: events.call);
    tracer = RecordingTracer();
    tokens = MemoryTokenStore();
  });

  tearDown(() => store.dispose());

  HeadlessDeps headless() => HeadlessDeps(
    tokenStore: tokens,
    prefs: SharedPreferencesAsync(),
    devServerUrl: '',
    adapter: server,
    openSocket: (_) => gateway.connect(),
    telemetry: (attributes) => ConnectionTelemetry(
      tracer: tracer,
      events: events.connection(attributes).events,
      serverAttributes: attributes,
    ),
    snapshotStore: store,
    appLockOn: () async => lockOn,
    rejectionRecheck: Duration.zero,
    closeGrace: const Duration(milliseconds: 200),
  );

  RequestIntents intents({
    Duration snapshotWait = const Duration(seconds: 1),
  }) => RequestIntents(
    snapshotWait: snapshotWait,
    headless: headless(),
    appLockOn: () async => lockOn,
    events: () => events.call,
  );

  List<Map<String, Object?>> rpcs(String method) => [
    for (final request in gateway.requests)
      if (request['method'] == method)
        request['params']! as Map<String, Object?>,
  ];

  Map<String, Object?> storedSnapshot() =>
      jsonDecode(storage.saved.last) as Map<String, Object?>;

  RecordingSpan taskSpan() =>
      tracer.spans.singleWhere((span) => span.name == 'background.task');

  void waiting() {
    sessions = {
      'default': [_session('chat-d', title: 'Backup')],
      'work': [_session('chat-w')],
    };
    approvals = {
      'rt-chat-d': [_approval('r-d')],
      'rt-chat-w': [_approval('r-w')],
    };
  }

  void signedOut() => server.on('GET', '/api/status', {
    'auth_required': true,
    'version': '0.9.0',
  });

  void locked() {
    tokens.unreadable = true;
    signedOut();
  }

  void serverDown() =>
      server.on('GET', '/api/status', {'detail': 'down'}, status: 503);

  /// Each way a run ends without having run its body.
  final unfinished = <String, (void Function(), String)>{
    'nobody is signed in': (signedOut, 'signed_out'),
    'the device has not been unlocked': (locked, 'device_locked'),
    'the server cannot be reached': (serverDown, 'unreachable'),
  };

  group('pending', () {
    test('lists the requests of every profile without links', () async {
      waiting();

      final answer = await intents().pending({});

      expect(answer['outcome'], 'answered');
      expect(answer['count'], 2);
      expect(answer['appLock'], isFalse);
      final requests = (answer['requests']! as List).cast<Map>();
      expect(
        requests.map((r) => r['requestId']),
        unorderedEquals(['r-d', 'r-w']),
      );
      final backup = requests.singleWhere((r) => r['requestId'] == 'r-d');
      expect(backup['profile'], 'default');
      expect(backup['threadId'], 'chat-d');
      expect(backup['title'], 'Backup');
      expect(backup['kind'], 'approval');
      expect(DateTime.parse(backup['createdAt'] as String), isNotNull);
      expect(requests.expand((r) => r.keys), isNot(contains('url')));
      expect(jsonEncode(answer), isNot(contains('rm -rf')));
      expect(jsonEncode(answer), isNot(contains(_description)));
    });

    test('lists the oldest request first', () async {
      waiting();
      await store.write(
        SurfaceSnapshot(
          updatedAt: DateTime.utc(2026, 10, 10),
          profile: 'default',
          pending: [
            PendingRequest(
              profile: 'work',
              threadId: 'chat-w',
              threadTitle: 'Trip plan',
              kind: PendingKind.approval,
              requestId: 'r-w',
              createdAt: DateTime.utc(2026, 10, 10, 8),
            ),
          ],
        ),
      );

      final answer = await intents().pending({});

      expect(
        (answer['requests']! as List).map((r) => (r as Map)['requestId']),
        ['r-w', 'r-d'],
      );
    });

    test('lists one profile when asked', () async {
      waiting();

      final answer = await intents().pending({'profile': 'work'});

      expect(answer['count'], 1);
      expect(
        (answer['requests']! as List).single,
        containsPair('profile', 'work'),
      );
    });

    test('says none when nothing waits', () async {
      final answer = await intents().pending({});

      expect(answer['outcome'], 'none');
      expect(answer['count'], 0);
      expect(answer['requests'], isEmpty);
    });

    test('gives the count only while App Lock is on', () async {
      waiting();
      lockOn = true;

      final answer = await intents().pending({});

      expect(answer['outcome'], 'answered');
      expect(answer['count'], 2);
      expect(answer['appLock'], isTrue);
      expect(answer['requests'], isEmpty);
    });

    test(
      'replies from the read alone, without rebuilding the snapshot',
      () async {
        waiting();

        await intents().pending({});

        expect(server.requestsTo('GET', '/api/sessions'), isEmpty);
        expect(server.requestsTo('GET', '/api/cron/jobs'), isEmpty);
      },
    );

    test('keeps the time a request was first seen', () async {
      waiting();
      await store.write(
        SurfaceSnapshot(
          updatedAt: DateTime.utc(2026, 10, 10),
          profile: 'default',
          pending: [
            PendingRequest(
              profile: 'default',
              threadId: 'chat-d',
              threadTitle: 'Backup',
              kind: PendingKind.approval,
              requestId: 'r-d',
              createdAt: DateTime.utc(2026, 10, 10, 8),
            ),
          ],
        ),
      );

      final answer = await intents().pending({});

      final backup = (answer['requests']! as List).cast<Map>().singleWhere(
        (r) => r['requestId'] == 'r-d',
      );
      expect(backup['createdAt'], '2026-10-10T08:00:00.000Z');
    });

    test('stores the fresh list for the widgets and the badge', () async {
      waiting();
      await store.write(
        SurfaceSnapshot(
          updatedAt: DateTime.utc(2026, 10, 10),
          profile: 'default',
        ),
      );

      await intents().pending({});

      expect(
        (storedSnapshot()['pending']! as List).map(
          (r) => (r as Map)['requestId'],
        ),
        unorderedEquals(['r-d', 'r-w']),
      );
    });

    test('announces nothing', () async {
      waiting();

      await intents().pending({});

      expect(
        await SharedPreferencesAsync().getStringList(
          'hermes.background.announced.v1',
        ),
        isNull,
      );
    });

    for (final MapEntry(key: reason, value: (arrange, outcome))
        in unfinished.entries) {
      test('says why when $reason', () async {
        waiting();
        arrange();

        final answer = await intents().pending({});

        expect(answer, {'outcome': outcome, 'appLock': false});
        expect(storage.saved, isEmpty);
      });
    }

    test('says whether App Lock is on when it cannot ask the server', () async {
      serverDown();
      lockOn = true;

      expect(await intents().pending({}), {
        'outcome': 'unreachable',
        'appLock': true,
      });
    });

    test('ends within its budget when the server never answers', () async {
      waiting();
      gateway.deaf = true;
      final watch = Stopwatch()..start();

      final answer = await intents().pending({'budgetMs': 400});

      expect(answer['outcome'], 'unreachable');
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('reads a profile it cannot list as unreachable', () async {
      waiting();
      gateway.handlers['session.active_list'] = (params) {
        if (params['profile'] == 'work') {
          throw const FakeRpcError(-32000, 'profile gone');
        }
        return {
          'sessions': [_session('chat-q')],
        };
      };

      final answer = await intents().pending({});

      expect(answer, {'outcome': 'unreachable', 'appLock': false});
    });

    test('records the task with counts and no text', () async {
      waiting();

      await intents().pending({});

      final attributes = taskSpan().attributes;
      expect(attributes['task'], 'intent.pending');
      expect(attributes['engine'], 'background');
      expect(attributes['result'], 'answered');
      expect(attributes['requests'], 2);
      expect(attributes.values.join(' '), isNot(contains('Backup')));
      expect(attributes.values.join(' '), isNot(contains('chat-d')));
    });
  });

  group('approval detail', () {
    Map<String, Object?> ask({
      String thread = 'chat-w',
      String request = 'r-w',
      String? profile = 'work',
    }) => {'profile': ?profile, 'threadId': thread, 'requestId': request};

    test('reads the command, description and offered choices', () async {
      waiting();

      final detail = await intents().approvalDetail(ask());

      expect(detail, {
        'outcome': 'found',
        'command': _command,
        'description': _description,
        'choices': ['once', 'session', 'deny'],
      });
      expect(rpcs('approval.pending'), [
        {'session_id': 'rt-chat-w', 'profile': 'work'},
      ]);
    });

    test('says gone when the session waits on something else', () async {
      waiting();

      final detail = await intents().approvalDetail(ask(request: 'r-old'));

      expect(detail, {'outcome': 'gone'});
    });

    test('says gone when the session is no longer live', () async {
      waiting();

      final detail = await intents().approvalDetail(ask(thread: 'chat-x'));

      expect(detail, {'outcome': 'gone'});
      expect(rpcs('approval.pending'), isEmpty);
    });

    test('reads nothing while App Lock is on', () async {
      waiting();
      lockOn = true;

      final detail = await intents().approvalDetail(ask());

      expect(detail, {'outcome': 'app_locked'});
      expect(gateway.requests, isEmpty);
    });

    test('says Hermes cannot list approvals when it has no provider', () async {
      waiting();
      gateway.handlers['approval.pending'] = (_) =>
          throw const FakeRpcError(5032, 'no provider');

      expect(await intents().approvalDetail(ask()), {'outcome': 'cannot_list'});
    });

    test(
      'says failed, not unreachable, when Hermes refuses the lookup',
      () async {
        waiting();
        gateway.handlers['approval.pending'] = (_) =>
            throw const FakeRpcError(-32000, 'boom');

        expect(await intents().approvalDetail(ask()), {'outcome': 'failed'});
      },
    );

    test('ends within its budget when the server never answers', () async {
      waiting();
      gateway.deaf = true;
      final watch = Stopwatch()..start();

      final detail = await intents().approvalDetail({
        ...ask(),
        'budgetMs': 400,
      });

      expect(detail['outcome'], 'unreachable');
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('refuses a request without its ids', () async {
      expect(await intents().approvalDetail({'threadId': 'a'}), {
        'outcome': 'failed',
      });
      expect(gateway.requests, isEmpty);
    });

    for (final MapEntry(key: reason, value: (arrange, outcome))
        in unfinished.entries) {
      test('says why when $reason', () async {
        waiting();
        arrange();

        expect(await intents().approvalDetail(ask()), {'outcome': outcome});
      });
    }
  });

  group('answer approval', () {
    Map<String, Object?> answer(
      String choice, {
      String thread = 'chat-w',
      String request = 'r-w',
    }) => {
      'profile': 'work',
      'threadId': thread,
      'requestId': request,
      'choice': choice,
    };

    test('answers by request id first, without resuming the chat', () async {
      waiting();

      final result = await intents().answerApproval(answer('session'));

      expect(result, {'outcome': 'answered'});
      expect(rpcs('request.answer').single, {
        'id': 'r-w',
        'result': {'choice': 'session'},
        'profile': 'work',
      });
      expect(gateway.methods, isNot(contains('session.resume')));
      expect(gateway.methods, isNot(contains('approval.respond')));
    });

    test(
      'falls back to approval.respond by the chat, never resuming it',
      () async {
        waiting();
        gateway.answerStatus = 'expired';

        final result = await intents().answerApproval(answer('once'));

        expect(result, {'outcome': 'answered'});
        expect(rpcs('approval.respond').single, {
          'session_id': 'chat-w',
          'profile': 'work',
          'request_id': 'r-w',
          'choice': 'once',
        });
        expect(gateway.methods, isNot(contains('session.resume')));
      },
    );

    test('says gone when Hermes reports nothing was waiting', () async {
      waiting();
      gateway
        ..answerStatus = 'expired'
        ..approvalsResolved = 0;

      final result = await intents().answerApproval(answer('once'));

      expect(result, {'outcome': 'gone'});
    });

    test('says failed when the answer does not get through', () async {
      waiting();
      gateway.handlers['request.answer'] = (_) =>
          throw const FakeRpcError(-32000, 'boom');

      final result = await intents().answerApproval(answer('once'));

      expect(result, {'outcome': 'failed'});
    });

    test('hands the answer to the running app, which sends it', () async {
      waiting();
      final app = ReceivePort();
      addTearDown(app.close);
      IsolateNameServer.registerPortWithName(app.sendPort, kRequestAnswersPort);
      addTearDown(
        () => IsolateNameServer.removePortNameMapping(kRequestAnswersPort),
      );
      final taken = <Object?>[];
      app.listen((message) {
        final [payload, actionId, input, deadline, reply] = message as List;
        taken.add([payload, actionId]);
        final confirm = ReceivePort();
        (reply as SendPort).send(['offer', confirm.sendPort]);
        confirm.first.then((_) {
          reply.send('ok');
          confirm.close();
        });
      });

      final result = await intents().answerApproval(answer('once'));

      expect(result, {'outcome': 'answered'});
      expect(taken, hasLength(1));
      expect((taken.single! as List)[1], 'hermes.action.allow-once');
      expect(gateway.requests, isEmpty);
    });

    test('answers although the snapshot store is stuck', () async {
      waiting();
      await store.write(
        SurfaceSnapshot(
          updatedAt: DateTime.utc(2026, 10, 10),
          profile: 'default',
          pending: [_stored('r-w', chat: 'chat-w')],
        ),
      );
      storage.loadGate = Completer<void>();
      final watch = Stopwatch()..start();

      final result = await intents(
        snapshotWait: const Duration(milliseconds: 200),
      ).answerApproval(answer('once'));

      expect(result, {'outcome': 'answered'});
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('takes the answered request off the snapshot', () async {
      waiting();
      await store.write(
        SurfaceSnapshot(
          updatedAt: DateTime.utc(2026, 10, 10),
          profile: 'default',
          pending: [
            _stored('r-w', chat: 'chat-w'),
            _stored('r-keep', chat: 'chat-k', hour: 10),
          ],
        ),
      );

      await intents().answerApproval(answer('once'));

      expect(
        (storedSnapshot()['pending']! as List).map(
          (r) => (r as Map)['requestId'],
        ),
        ['r-keep'],
      );
    });

    test(
      'takes a request that was no longer waiting off the snapshot',
      () async {
        waiting();
        gateway
          ..answerStatus = 'expired'
          ..approvalsResolved = 0;
        await store.write(
          SurfaceSnapshot(
            updatedAt: DateTime.utc(2026, 10, 10),
            profile: 'default',
            pending: [_stored('r-w', chat: 'chat-w')],
          ),
        );

        await intents().answerApproval(answer('once'));

        expect(storedSnapshot()['pending'], isEmpty);
      },
    );

    test('ends within its budget when the server never answers', () async {
      waiting();
      gateway.deaf = true;
      final watch = Stopwatch()..start();

      final result = await intents().answerApproval({
        ...answer('once'),
        'budgetMs': 400,
      });

      expect(result['outcome'], isIn(['failed', 'unreachable']));
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('sends nothing while App Lock is on', () async {
      waiting();
      lockOn = true;

      final result = await intents().answerApproval(answer('once'));

      expect(result, {'outcome': 'app_locked'});
      expect(gateway.requests, isEmpty);
    });

    test('sends nothing for a choice Hermes does not know', () async {
      waiting();

      final result = await intents().answerApproval(answer('forever'));

      expect(result, {'outcome': 'failed'});
      expect(gateway.requests, isEmpty);
    });

    for (final MapEntry(key: reason, value: (arrange, outcome))
        in unfinished.entries) {
      test('sends nothing when $reason', () async {
        waiting();
        arrange();

        final result = await intents().answerApproval(answer('once'));

        expect(result, {'outcome': outcome});
        expect(gateway.methods, isNot(contains('approval.respond')));
        expect(gateway.methods, isNot(contains('request.answer')));
      });
    }

    test('logs the choice and the outcome, never the request', () async {
      waiting();

      await intents().answerApproval(answer('always'));

      expect(events.named('intent.answer_approval'), [
        {'outcome': 'answered', 'choice': 'always'},
      ]);
      expect(
        events.named('intent.answer_approval').single.values.join(' '),
        isNot(contains('r-w')),
      );
      final attributes = taskSpan().attributes;
      expect(attributes['task'], 'intent.answer_approval');
      expect(attributes['engine'], 'background');
      expect(attributes['step'], 'answer');
      expect(attributes['result'], 'answered');
      expect(attributes.values.join(' '), isNot(contains('rm -rf')));
      expect(attributes.values.join(' '), isNot(contains('chat-w')));
    });

    test('logs an answer that App Lock stopped', () async {
      waiting();
      lockOn = true;

      await intents().answerApproval(answer('deny'));

      expect(events.named('intent.answer_approval'), [
        {'outcome': 'app_locked', 'choice': 'deny'},
      ]);
    });
  });

  group('outcomes only Swift sees', () {
    test('logs a cancelled confirmation with its choice', () {
      intents().record({'outcome': 'cancelled', 'choice': 'once'});

      expect(events.named('intent.answer_approval'), [
        {'outcome': 'cancelled', 'choice': 'once'},
      ]);
    });

    test('ignores words it does not know', () {
      intents()
        ..record({'outcome': 'cancelled', 'choice': 'rm -rf /'})
        ..record({'outcome': 'answered', 'choice': 'once'})
        ..record({});

      expect(events.named('intent.answer_approval'), isEmpty);
    });
  });

  group('channel', () {
    const channel = MethodChannel(kRequestIntentsChannel);
    late List<String> flushed;
    late RequestIntentsChannel served;

    setUp(() {
      flushed = [];
      served = RequestIntentsChannel(
        intents(),
        channel: channel,
        flush: () async => flushed.add('flush'),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('says it is ready once it can answer', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });

      await served.serve();

      expect(calls, ['ready']);
    });

    test('runs a call and sends its telemetry before answering', () async {
      waiting();

      final result = await served.handle(
        const MethodCall('pending', {'profile': 'work'}),
      );

      expect((result! as Map)['count'], 1);
      expect(flushed, ['flush']);
    });

    test('treats arguments that are not a map as none', () async {
      final result = await served.handle(const MethodCall('pending', 'junk'));

      expect((result! as Map)['outcome'], 'none');
    });

    test('refuses a method it does not serve', () async {
      await expectLater(
        served.handle(const MethodCall('refreshShortcuts')),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });
}
