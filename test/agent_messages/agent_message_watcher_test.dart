import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_message_record.dart';
import 'package:hermes_app/src/agent_messages/agent_message_watcher.dart';
import 'package:hermes_app/src/agent_messages/find_messages.dart'
    show kUnfinishedGrace;
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import '../support/fake_hermes_server.dart';
import '../support/fake_notification_service.dart';

void main() {
  late FakeHermesServer server;
  late FakeNotificationService service;
  late NotificationSettings settings;
  late AgentMessageFinds finds;
  late BreadcrumbTrail trail;
  late List<(String, Map<String, Object>)> events;
  late AgentMessageWatcher? watcher;
  var appLock = false;
  String? shown;

  Future<void> setUpWatcher({
    bool load = true,
    bool paused = false,
    TargetPlatform? platform,
    AgentMessageRecord? record,
    DateTime Function()? clock,
    Duration lookup = const Duration(seconds: 4),
  }) async {
    settings = NotificationSettings();
    if (load) await settings.load();
    watcher = AgentMessageWatcher(
      chat: HermesChatRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
      service: service,
      settings: settings,
      finds: finds,
      record: record,
      account: () => 'acct',
      shownProfile: () => shown,
      appLock: () => appLock,
      breadcrumbs: Breadcrumbs.of(trail),
      events: (name, [attributes = const {}]) => events.add((name, attributes)),
      platform: platform,
      clock: clock,
      paused: paused,
      lookup: lookup,
    );
  }

  Map<String, Object?> delivery(
    String id, {
    required double at,
    String? title,
    bool unread = true,
    int messages = 1,
  }) => sessionRow(
    id: id,
    title: title,
    startedAt: at,
    unread: unread,
    messageCount: messages,
    source: 'hermes_app',
  );

  void profiles(List<String> names) => server.on('GET', '/api/profiles', {
    'profiles': [
      for (final name in names) {'name': name},
    ],
  });

  void deliveries(String profile, List<Map<String, Object?>> rows) => server.on(
    'GET',
    '/api/sessions',
    sessionListBody(rows),
    query: {'source': 'hermes_app', 'profile': profile},
  );

  void text(String id, String content) => server.on(
    'GET',
    '/api/sessions/$id/messages',
    messageListBody(id, [
      messageRow(id: 1, role: 'assistant', content: content),
    ]),
  );

  /// Holds the text of [id] until the returned completer completes.
  Completer<void> holdText(String id, {String content = 'Hi'}) {
    final held = Completer<void>();
    server.onRequest('GET', '/api/sessions/$id/messages', (_) async {
      await held.future;
      return (
        status: 200,
        body: messageListBody(id, [
          messageRow(id: 1, role: 'assistant', content: content),
        ]),
      );
    });
    return held;
  }

  /// Puts the lifecycle back to resumed whatever the test did to it.
  void restoreLifecycle(WidgetTester tester) => addTearDown(
    () => tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );

  Future<void> untilStarted(Completer<void> started) =>
      started.future.timeout(const Duration(seconds: 5));

  int listings() => server
      .requestsTo('GET', '/api/sessions')
      .where((r) => r.queryParameters['source'] == 'hermes_app')
      .length;

  Future<Map<String, double>?> record() => AgentMessageRecord().read('acct');

  List<String> eventNames() => [for (final (name, _) in events) name];

  Map<String, Object> eventAttributes(String name) =>
      events.singleWhere((e) => e.$1 == name).$2;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    service = FakeNotificationService();
    finds = AgentMessageFinds();
    trail = BreadcrumbTrail();
    events = [];
    appLock = false;
    shown = 'work';
    watcher = null;
    profiles(['default', 'work']);
    deliveries('default', []);
    deliveries('work', []);
  });

  tearDown(() {
    watcher?.dispose();
    finds.dispose();
  });

  group('AgentMessageWatcher', () {
    testWidgets('announces a delivery after the first look, not before', (
      tester,
    ) async {
      await tester.runAsync(() async {
        deliveries('work', [delivery('hermes-app-old', at: 100)]);
        await setUpWatcher();
        await watcher!.check();
        expect(service.shown, isEmpty);
        expect(await record(), {'default': 0, 'work': 100});

        deliveries('work', [
          delivery('hermes-app-new', at: 200, title: 'Message: Report'),
          delivery('hermes-app-old', at: 100),
        ]);
        text('hermes-app-new', 'Daily report ready: 3 builds failed');
        await watcher!.check();

        final alert = service.shown.single;
        expect(alert.threadId, 'hermes-app-new');
        expect(alert.profile, 'work');
        expect(alert.title, 'Message: Report');
        expect(alert.body, 'Daily report ready: 3 builds failed');
        expect(await record(), {'default': 0, 'work': 200});

        await watcher!.check();
        expect(service.shown, hasLength(1));
      });
    });

    testWidgets('gives up on an unfinished delivery by the device clock', (
      tester,
    ) async {
      await tester.runAsync(() async {
        var now = 250.0;
        await setUpWatcher(
          clock: () =>
              DateTime.fromMillisecondsSinceEpoch((now * 1000).round()),
        );
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-b', at: 300),
          delivery('hermes-app-a', at: 200, messages: 0),
        ]);
        text('hermes-app-b', 'Hi');

        await watcher!.check();
        expect(service.shown, isEmpty);

        now = 200 + kUnfinishedGrace + 1;
        await watcher!.check();
        expect(service.shown.single.threadId, 'hermes-app-b');
      });
    });

    testWidgets('names a profile other than the one shown', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher();
        await watcher!.check();
        shown = 'default';
        deliveries('work', [
          delivery('hermes-app-new', at: 200, title: 'Report'),
        ]);
        text('hermes-app-new', 'Hi');

        await watcher!.check();

        expect(service.shown.single.title, 'Report (work)');
      });
    });

    group('with no profile shown', () {
      Future<void> twoDeliveries() async {
        await setUpWatcher();
        await watcher!.check();
        shown = null;
        deliveries('default', [
          delivery('hermes-app-a', at: 200, title: 'Report'),
        ]);
        deliveries('work', [delivery('hermes-app-b', at: 200, title: 'Other')]);
        text('hermes-app-a', 'Hi');
        text('hermes-app-b', 'Hi');
        await watcher!.check();
      }

      testWidgets("names a profile other than the server's active one, "
          'asking once per look', (tester) async {
        await tester.runAsync(() async {
          server.on(
            'GET',
            '/api/profiles/active',
            activeProfileBody(active: 'work'),
          );

          await twoDeliveries();

          expect(
            {for (final alert in service.shown) alert.title},
            {'Report (default)', 'Other'},
          );
          expect(
            server.requestsTo('GET', '/api/profiles/active'),
            hasLength(1),
          );
        });
      });

      testWidgets('asks for the active profile while the texts are read', (
        tester,
      ) async {
        await tester.runAsync(() async {
          server.on(
            'GET',
            '/api/profiles/active',
            activeProfileBody(active: 'work'),
          );
          await setUpWatcher();
          await watcher!.check();
          shown = null;
          deliveries('work', [delivery('hermes-app-new', at: 200)]);
          final held = holdText('hermes-app-new');

          final look = watcher!.check();
          for (var i = 0; i < 100; i++) {
            if (server.requestsTo('GET', '/api/profiles/active').isNotEmpty) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          final asked = server.requestsTo('GET', '/api/profiles/active').length;
          held.complete();
          await look;

          expect(asked, 1);
        });
      });

      testWidgets('names no profile when the active one cannot be read', (
        tester,
      ) async {
        await tester.runAsync(() async {
          server.on('GET', '/api/profiles/active', {
            'detail': 'no',
          }, status: 500);

          await twoDeliveries();

          expect(
            {for (final alert in service.shown) alert.title},
            {'Report', 'Other'},
          );
        });
      });
    });

    testWidgets('looks at every profile in parallel', (tester) async {
      await tester.runAsync(() async {
        final started = <String>[];
        final held = Completer<FakeResponse>();
        for (final name in ['default', 'work']) {
          server.onRequest('GET', '/api/sessions', (request) {
            started.add(request.queryParameters['profile'] as String);
            return held.future;
          }, query: {'source': 'hermes_app', 'profile': name});
        }
        await setUpWatcher();
        await pumpEventQueue();

        expect(started, unorderedEquals(['default', 'work']));
        held.complete((status: 200, body: sessionListBody([])));
        await watcher!.check();
      });
    });

    testWidgets('a failing profile does not stop the others', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher();
        await watcher!.check();
        server.on(
          'GET',
          '/api/sessions',
          {'detail': 'no'},
          status: 500,
          query: {'source': 'hermes_app', 'profile': 'default'},
        );
        deliveries('work', [delivery('hermes-app-new', at: 200)]);
        text('hermes-app-new', 'Hi');

        await watcher!.check();

        expect(service.shown.single.threadId, 'hermes-app-new');
        expect(await record(), {'default': 0, 'work': 200});
        expect(eventNames(), [
          'agent_messages.announced',
          'agent_messages.look_failed',
        ]);
      });
    });

    testWidgets('an unreadable profile list writes and posts nothing', (
      tester,
    ) async {
      await tester.runAsync(() async {
        server.on('GET', '/api/profiles', {'detail': 'no'}, status: 500);
        await setUpWatcher();
        await watcher!.check();

        expect(listings(), 0);
        expect(await record(), isNull);
        expect(service.shown, isEmpty);
        expect(eventAttributes('agent_messages.look_failed'), {
          'error_type': 'DioException',
          'background': false,
        });
      });
    });

    testWidgets('logs a failed look once, whatever fails in it', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final name in ['default', 'work']) {
          server.on(
            'GET',
            '/api/sessions',
            {'detail': 'no'},
            status: 500,
            query: {'source': 'hermes_app', 'profile': name},
          );
        }
        await setUpWatcher();
        await watcher!.check();

        expect(eventNames(), ['agent_messages.look_failed']);
        expect(await record(), isEmpty);
      });
    });

    testWidgets('records before it posts', (tester) async {
      await tester.runAsync(() async {
        SharedPreferencesAsyncPlatform.instance = _FailingWritePrefs();
        deliveries('work', [delivery('hermes-app-new', at: 200)]);
        text('hermes-app-new', 'Hi');
        await setUpWatcher();
        await watcher!.check();

        expect(service.shown, isEmpty);
      });
    });

    testWidgets('reads the texts in parallel', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher();
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-b', at: 300),
          delivery('hermes-app-a', at: 200),
        ]);
        final started = <String>[];
        final held = Completer<void>();
        for (final id in ['hermes-app-a', 'hermes-app-b']) {
          server.onRequest('GET', '/api/sessions/$id/messages', (_) async {
            started.add(id);
            await held.future;
            return (
              status: 200,
              body: messageListBody(id, [
                messageRow(id: 1, role: 'assistant', content: 'Text of $id'),
              ]),
            );
          });
        }

        final look = watcher!.check();
        while (started.length < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        held.complete();
        await look;

        expect([
          for (final alert in service.shown) alert.body,
        ], unorderedEquals(['Text of hermes-app-a', 'Text of hermes-app-b']));
      });
    });

    testWidgets('App Lock hides the title and reads no text', (tester) async {
      await tester.runAsync(() async {
        appLock = true;
        await setUpWatcher();
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-new', at: 200, title: 'Message: Secret'),
        ]);

        await watcher!.check();

        expect(service.shown.single.title, 'Message from Hermes');
        expect(service.shown.single.body, 'New message');
        expect(
          server.requestsTo('GET', '/api/sessions/hermes-app-new/messages'),
          isEmpty,
        );
      });
    });

    testWidgets('many messages are one summary and read no text', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await setUpWatcher();
        await watcher!.check();
        deliveries('work', [
          for (var i = 0; i < 6; i++) delivery('hermes-app-$i', at: 200.0 + i),
        ]);

        await watcher!.check();

        expect(service.shown.single.body, '6 new messages');
        expect(
          server.requests.where((r) => r.path.endsWith('/messages')),
          isEmpty,
        );
        expect(eventAttributes('agent_messages.announced'), {
          'count': 6,
          'summary': true,
          'background': false,
        });
      });
    });

    testWidgets('reports what it found and nothing else', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher();
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-new', at: 200, title: 'Message: Secret'),
        ]);
        text('hermes-app-new', 'Secret text');
        var notified = 0;
        finds.addListener(() => notified++);

        await watcher!.check();

        expect(
          [for (final c in trail.recent) c.name],
          ['agent_messages.found'],
        );
        expect(trail.recent.single.attributes, {'count': 1});
        expect(eventAttributes('agent_messages.announced'), {
          'count': 1,
          'summary': false,
          'background': false,
        });
        expect(finds.profiles, {'work'});
        expect(notified, 1);
      });
    });

    testWidgets('a look that finds nothing tells nobody', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher();
        shown = null;
        var notified = 0;
        finds.addListener(() => notified++);
        await watcher!.check();

        expect(server.requestsTo('GET', '/api/profiles/active'), isEmpty);
        expect(trail.recent, isEmpty);
        expect(events, isEmpty);
        expect(notified, 0);
      });
    });

    testWidgets('gives up on an unfinished delivery whatever the device clock '
        'says, once a newer chat is listed', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher(
          clock: () => DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        );
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-b', at: 200 + kUnfinishedGrace + 10),
          delivery('hermes-app-a', at: 200, messages: 0),
        ]);
        text('hermes-app-b', 'Hi');

        await watcher!.check();

        expect(service.shown.single.threadId, 'hermes-app-b');
      });
    });

    testWidgets('keeps waiting for an unfinished delivery nothing has '
        'outlived', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher(
          clock: () => DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        );
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-b', at: 300),
          delivery('hermes-app-a', at: 200, messages: 0),
        ]);
        text('hermes-app-b', 'Hi');

        await watcher!.check();

        expect(service.shown, isEmpty);
        expect(await record(), {'default': 0, 'work': 0});
      });
    });

    group('a change of lifecycle', () {
      testWidgets('while the texts are read aborts the look before it '
          'records, and the next one announces', (tester) async {
        restoreLifecycle(tester);
        await tester.runAsync(() async {
          await setUpWatcher();
          await watcher!.check();
          deliveries('work', [delivery('hermes-app-new', at: 200)]);
          final held = holdText('hermes-app-new');
          final look = watcher!.check();
          await pumpEventQueue();

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          held.complete();
          await look;

          expect(service.shown, isEmpty);
          expect(await record(), {'default': 0, 'work': 0});

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await watcher!.check();

          expect(service.shown.single.threadId, 'hermes-app-new');
        });
      });

      testWidgets('while the record is written still posts what it recorded', (
        tester,
      ) async {
        restoreLifecycle(tester);
        await tester.runAsync(() async {
          final prefs = _HoldablePrefs();
          SharedPreferencesAsyncPlatform.instance = prefs;
          await setUpWatcher();
          await watcher!.check();
          deliveries('work', [delivery('hermes-app-new', at: 200)]);
          text('hermes-app-new', 'Hi');
          final gate = prefs.hold();
          final look = watcher!.check();
          await untilStarted(prefs.writing);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          final again = watcher!.check();
          gate.complete();
          await look;
          await again;

          expect(service.shown.single.threadId, 'hermes-app-new');
          expect(await record(), {'default': 0, 'work': 200});
          expect(eventAttributes('agent_messages.announced'), {
            'count': 1,
            'summary': false,
            'background': false,
          });
        });
      });
    });

    for (final (name, interrupt) in <(String, void Function())>[
      ('pausing', () => watcher!.paused = true),
      ('disposing', () => watcher!.dispose()),
      ('turning the setting off', () => settings.setAgentMessages(false)),
    ]) {
      group(name, () {
        testWidgets('while the texts are read writes and posts nothing', (
          tester,
        ) async {
          await tester.runAsync(() async {
            await setUpWatcher();
            await watcher!.check();
            deliveries('work', [delivery('hermes-app-new', at: 200)]);
            final held = holdText('hermes-app-new');
            final look = watcher!.check();
            await pumpEventQueue();

            interrupt();
            held.complete();
            await look;

            expect(service.shown, isEmpty);
            expect(await record(), {'default': 0, 'work': 0});
          });
        });

        testWidgets('while the record is written posts nothing', (
          tester,
        ) async {
          await tester.runAsync(() async {
            final prefs = _HoldablePrefs();
            SharedPreferencesAsyncPlatform.instance = prefs;
            await setUpWatcher();
            await watcher!.check();
            deliveries('work', [delivery('hermes-app-new', at: 200)]);
            text('hermes-app-new', 'Hi');
            final gate = prefs.hold();
            final look = watcher!.check();
            await untilStarted(prefs.writing);

            interrupt();
            gate.complete();
            await look;

            expect(service.shown, isEmpty);
            expect(events, isEmpty);
          });
        });
      });
    }

    testWidgets('posts nothing for a record another look moved while the '
        'text was read', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher();
        await watcher!.check();
        deliveries('work', [delivery('hermes-app-new', at: 200)]);
        final held = holdText('hermes-app-new');
        final look = watcher!.check();
        await pumpEventQueue();

        await AgentMessageRecord().write('acct', {'default': 0, 'work': 250});
        held.complete();
        await look;

        expect(service.shown, isEmpty);
        expect(await record(), {'default': 0, 'work': 250});
      });
    });

    testWidgets('hides a text App Lock covered while it was read', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await setUpWatcher();
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-new', at: 200, title: 'Message: Secret'),
        ]);
        final held = holdText('hermes-app-new', content: 'Secret text');
        final look = watcher!.check();
        await pumpEventQueue();

        appLock = true;
        held.complete();
        await look;

        expect(service.shown.single.title, 'Message from Hermes');
        expect(service.shown.single.body, 'New message');
      });
    });

    testWidgets('App Lock turned on while the first of two is posted makes '
        'the second generic', (tester) async {
      await tester.runAsync(() async {
        service = _OnShow(() => appLock = true);
        await setUpWatcher();
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-b', at: 300, title: 'Message: Second'),
          delivery('hermes-app-a', at: 200, title: 'Message: First'),
        ]);
        text('hermes-app-a', 'First text');
        text('hermes-app-b', 'Second text');

        await watcher!.check();

        expect(
          [for (final alert in service.shown) alert.title],
          ['Message: Second', 'Message from Hermes'],
        );
        expect(service.shown.last.body, 'New message');
      });
    });

    testWidgets('a text that takes too long is "New message"', (tester) async {
      await tester.runAsync(() async {
        await setUpWatcher(lookup: const Duration(milliseconds: 100));
        await watcher!.check();
        deliveries('work', [
          delivery('hermes-app-new', at: 200, title: 'Message: Report'),
        ]);
        final held = holdText('hermes-app-new');

        await watcher!.check();
        held.complete();

        expect(service.shown.single.title, 'Message: Report');
        expect(service.shown.single.body, 'New message');
      });
    });

    testWidgets('a listing that takes too long keeps the record of its '
        'profile and spares the others', (tester) async {
      await tester.runAsync(() async {
        await AgentMessageRecord().write('acct', {'default': 0, 'work': 100});
        final held = Completer<FakeResponse>();
        server.onRequest(
          'GET',
          '/api/sessions',
          (_) => held.future,
          query: {'source': 'hermes_app', 'profile': 'work'},
        );
        deliveries('default', [delivery('hermes-app-new', at: 200)]);
        text('hermes-app-new', 'Hi');
        await setUpWatcher(lookup: const Duration(milliseconds: 100));

        await watcher!.check();
        held.complete((status: 200, body: sessionListBody([])));

        expect(service.shown.single.threadId, 'hermes-app-new');
        expect(await record(), {'default': 200, 'work': 100});
        expect(eventAttributes('agent_messages.look_failed'), {
          'error_type': 'TimeoutException',
          'background': false,
        });
      });
    });

    testWidgets('a profile list that takes too long writes nothing', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final held = Completer<FakeResponse>();
        server.onRequest('GET', '/api/profiles', (_) => held.future);
        await setUpWatcher(lookup: const Duration(milliseconds: 100));

        await watcher!.check();
        held.complete((status: 200, body: {'profiles': <Object>[]}));

        expect(listings(), 0);
        expect(await record(), isNull);
        expect(eventAttributes('agent_messages.look_failed'), {
          'error_type': 'TimeoutException',
          'background': false,
        });
      });
    });

    testWidgets('a profile list with no profile writes and posts nothing', (
      tester,
    ) async {
      await tester.runAsync(() async {
        profiles([]);
        await setUpWatcher();
        await watcher!.check();

        expect(listings(), 0);
        expect(await record(), isNull);
        expect(service.shown, isEmpty);
      });
    });

    testWidgets('a record that cannot be saved is a failed look', (
      tester,
    ) async {
      await tester.runAsync(() async {
        SharedPreferencesAsyncPlatform.instance = _FailingWritePrefs();
        deliveries('work', [delivery('hermes-app-new', at: 200)]);
        text('hermes-app-new', 'Hi');
        await setUpWatcher();
        await watcher!.check();

        expect(service.shown, isEmpty);
        expect(eventNames(), ['agent_messages.look_failed']);
        expect(eventAttributes('agent_messages.look_failed'), {
          'error_type': 'StateError',
          'background': false,
        });
      });
    });

    testWidgets('logs a failure once per type until a look succeeds', (
      tester,
    ) async {
      await tester.runAsync(() async {
        void failListing(bool fail) => server.on(
          'GET',
          '/api/sessions',
          fail ? {'detail': 'no'} : sessionListBody([]),
          status: fail ? 500 : 200,
          query: {'source': 'hermes_app', 'profile': 'work'},
        );
        failListing(true);
        await setUpWatcher();
        await watcher!.check();
        await watcher!.check();
        expect(eventNames(), ['agent_messages.look_failed']);

        failListing(false);
        await watcher!.check();
        failListing(true);
        await watcher!.check();

        expect(eventNames(), [
          'agent_messages.look_failed',
          'agent_messages.look_failed',
        ]);
      });
    });

    group('does not look', () {
      testWidgets('while paused', (tester) async {
        await tester.runAsync(() async {
          await setUpWatcher(paused: true);
          await watcher!.check();
          expect(server.requests, isEmpty);

          watcher!.paused = false;
          await watcher!.check();
          expect(listings(), 2);
        });
      });

      testWidgets('with notifications off', (tester) async {
        await tester.runAsync(() async {
          await setUpWatcher();
          await watcher!.check();
          final before = listings();

          await settings.setEnabled(false);
          await watcher!.check();

          expect(listings(), before);
        });
      });

      testWidgets('with the setting off', (tester) async {
        await tester.runAsync(() async {
          await setUpWatcher();
          await settings.setAgentMessages(false);
          await watcher!.check();

          expect(server.requests, isEmpty);
        });
      });

      testWidgets('before the settings have loaded', (tester) async {
        await tester.runAsync(() async {
          await setUpWatcher(load: false);
          await watcher!.check();
          expect(server.requests, isEmpty);

          await settings.load();
          await watcher!.check();
          expect(listings(), 2);
        });
      });

      for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
        testWidgets('on $platform', (tester) async {
          await tester.runAsync(() async {
            await setUpWatcher(platform: platform);
            await watcher!.check();

            expect(server.requests, isEmpty);
          });
        });
      }
    });

    group('the record', () {
      testWidgets('is forgotten when the setting is switched back on', (
        tester,
      ) async {
        await tester.runAsync(() async {
          deliveries('work', [delivery('hermes-app-old', at: 100)]);
          await setUpWatcher();
          await watcher!.check();
          await settings.setAgentMessages(false);
          deliveries('work', [
            delivery('hermes-app-new', at: 200),
            delivery('hermes-app-old', at: 100),
          ]);

          await settings.setAgentMessages(true);
          await watcher!.check();

          expect(service.shown, isEmpty);
          expect(await record(), {'default': 0, 'work': 200});
        });
      });

      testWidgets('is forgotten when notifications are switched back on', (
        tester,
      ) async {
        await tester.runAsync(() async {
          await setUpWatcher();
          await watcher!.check();
          await settings.setEnabled(false);
          deliveries('work', [delivery('hermes-app-new', at: 200)]);

          await settings.setEnabled(true);
          await watcher!.check();

          expect(service.shown, isEmpty);
        });
      });

      testWidgets('is kept when another setting changes', (tester) async {
        await tester.runAsync(() async {
          await setUpWatcher();
          await watcher!.check();
          deliveries('work', [delivery('hermes-app-new', at: 200)]);
          text('hermes-app-new', 'Hi');

          await settings.setScheduleAlerts(false);
          await watcher!.check();

          expect(service.shown, hasLength(1));
        });
      });

      testWidgets('is kept when the settings finish loading', (tester) async {
        await tester.runAsync(() async {
          await AgentMessageRecord().write('acct', {'default': 0, 'work': 100});
          await setUpWatcher(load: false);
          await settings.load();
          deliveries('work', [delivery('hermes-app-new', at: 200)]);
          text('hermes-app-new', 'Hi');

          await watcher!.check();

          expect(service.shown, hasLength(1));
        });
      });

      testWidgets('of another account is not used', (tester) async {
        await tester.runAsync(() async {
          await AgentMessageRecord().write('other', {'work': 100});
          deliveries('work', [delivery('hermes-app-new', at: 200)]);
          await setUpWatcher();
          await watcher!.check();

          expect(service.shown, isEmpty);
        });
      });
    });
  });

  group('timing', () {
    testWidgets('on macOS goes on looking with no window in front', (
      tester,
    ) async {
      restoreLifecycle(tester);
      await setUpWatcher(platform: TargetPlatform.macOS);
      await tester.pumpAndSettle();
      expect(listings(), 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
      expect(listings(), 2);

      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(listings(), 4);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(listings(), 4);

      watcher!.dispose();
    });

    testWidgets('looks every minute in front and not in the background', (
      tester,
    ) async {
      await setUpWatcher();
      await tester.pumpAndSettle();
      expect(listings(), 2);

      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(listings(), 4);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(listings(), 4);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(listings(), 6);

      // The timer would otherwise outlive the test.
      watcher!.dispose();
    });
  });
}

/// Prefs whose next write can be held, to stop a look in the middle of saving
/// its record.
base class _HoldablePrefs extends InMemorySharedPreferencesAsync {
  _HoldablePrefs() : super.empty();

  Completer<void>? _gate;
  Completer<void> writing = Completer<void>();

  /// Holds the next write until the returned completer completes.
  Completer<void> hold() {
    writing = Completer<void>();
    return _gate = Completer<void>();
  }

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    if (_gate case final gate?) {
      _gate = null;
      writing.complete();
      await gate.future;
    }
    return super.setString(key, value, options);
  }
}

base class _FailingWritePrefs extends InMemorySharedPreferencesAsync {
  _FailingWritePrefs()
    : super.withData({
        'hermes.agent_messages.baseline.v1':
            '{"account":"acct","profiles":{"default":0,"work":100}}',
      });

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async => throw StateError('disk full');
}

/// Calls [onShow] when a notification is posted.
class _OnShow extends FakeNotificationService {
  _OnShow(this.onShow);

  final void Function() onShow;

  @override
  Future<void> show(AttentionNotification notification) async {
    await super.show(notification);
    onShow();
  }
}
