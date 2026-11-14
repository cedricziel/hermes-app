import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_dock.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/connector_operation_card.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_gateway.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/pump_chat.dart';
import '../billing_fixtures.dart' show billingVerificationFixture;
import '../connector_fixtures.dart';

/// The chat screen owning the Needs-you queue of the open chat, against the
/// real gateway transport and a scripted gateway.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late ChatProfiles profiles;
  late BreadcrumbTrail trail;
  late List<String> announced;
  late _Lock lock;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail(capacity: 100);
    announced = [];
    lock = _Lock();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['connection.respond'] = (_) => {
      'status': 'ok',
      'settled': false,
    };
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'default', isDefault: true)]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'First chat')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', [
          messageRow(id: 1, role: 'user', content: 'Hello'),
        ]),
      );
    profiles = ChatProfiles(HermesProfilesRepository(server.client().raw));
  });

  tearDown(() async {
    profiles.dispose();
    lock.dispose();
    await transport.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map && message['type'] == 'announce') {
          announced.add((message['data'] as Map)['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      chatProfiles: profiles,
      providers: [
        Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
        ChangeNotifierProvider<AppLockController>.value(value: lock),
      ],
    );
    await openThread(tester, 'First chat');
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> emit(
    WidgetTester tester,
    String type,
    Map<String, Object?> payload, {
    String runtime = 'rt-1',
  }) async {
    gateway.event(type, runtime, payload);
    await settle(tester);
  }

  Future<void> request(WidgetTester tester) =>
      emit(tester, 'connection.request', connectionRequestFixture);

  Finder dock() => find.byKey(const Key('needs-you-dock'));
  Finder button(String key) => find.byKey(Key(key));
  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

  testWidgets('a connector sign-in docks directly above the composer', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(dock(), findsNothing);
    await request(tester);

    expect(dock(), findsOneWidget);
    expect(find.text('Connect synthetic-connector to continue'), findsOne);
    expect(find.byType(ConnectorOperationCard), findsNothing);
    final dockRect = tester.getRect(find.byType(NeedsYouDock));
    final composer = tester.getRect(find.byType(ChatComposer));
    expect(dockRect.bottom, moreOrLessEquals(composer.top, epsilon: 0.5));
    expect(find.byKey(const Key('chat-activity-strip')), findsNothing);
    await finish(tester);
  });

  testWidgets('the Activity button marks and counts what waits', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('activity-waiting-marker')), findsNothing);
    expect(find.bySemanticsLabel('Activity'), findsOneWidget);

    await request(tester);
    expect(find.byKey(const Key('activity-waiting-marker')), findsOneWidget);
    expect(find.bySemanticsLabel('Activity, 1 needs you'), findsOneWidget);

    // The operation settles: the marker goes and the label stops counting.
    await emit(tester, 'connection.update', {
      ...connectionUpdateFixture,
      'seq': 9,
      'settled': true,
      'owner': {'type': 'session', 'session_id': 'rt-1'},
    });
    expect(dock(), findsNothing);
    expect(find.byKey(const Key('activity-waiting-marker')), findsNothing);
    expect(find.bySemanticsLabel('Activity'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a new request is announced once, by kind, never by its '
      'content', (tester) async {
    await pumpScreen(tester);
    await request(tester);
    expect(announced, ['A connection needs you']);

    await emit(tester, 'connection.update', {
      ...connectionUpdateFixture,
      'seq': 5,
      'owner': {'type': 'session', 'session_id': 'rt-1'},
    });
    await tester.pump(const Duration(seconds: 20));
    expect(announced, ['A connection needs you']);
    for (final text in announced) {
      expect(text, isNot(contains('synthetic')));
      expect(text, isNot(contains('connect.invalid')));
    }
    await finish(tester);
  });

  testWidgets('the breadcrumbs say that a request was shown and nothing '
      'about it', (tester) async {
    await pumpScreen(tester);
    await request(tester);
    final crumbs = [
      for (final c in trail.recent)
        if (c.name.startsWith('chat.activity.needs_you')) c,
    ];
    expect([for (final c in crumbs) c.name], ['chat.activity.needs_you.shown']);
    expect(crumbs.single.attributes, {'kind': 'connector', 'count': 1});
    await finish(tester);
  });

  testWidgets('Continue shows sending, then "Couldn\'t confirm" after 10 '
      'seconds, and a late settlement removes the card', (tester) async {
    gateway.silent.add('connection.respond');
    await pumpScreen(tester);
    await request(tester);

    await tester.tap(button('needs-you-continue'));
    await tester.pump();
    expect(find.text('Sending your answer…'), findsOneWidget);
    expect(enabled(tester, 'needs-you-continue'), isFalse);
    expect(enabled(tester, 'needs-you-skip'), isFalse);
    expect(enabled(tester, 'needs-you-open'), isFalse);
    await settle(tester);
    expect(
      gateway.methods.where((m) => m == 'connection.respond'),
      hasLength(1),
    );

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Sending your answer…'), findsNothing);
    expect(find.textContaining("Couldn't confirm your answer"), findsOne);
    expect(enabled(tester, 'needs-you-continue'), isTrue);
    expect(enabled(tester, 'needs-you-skip'), isTrue);

    // Time passes; the card keeps its line and nothing is resent. The
    // transport's own timeout is covered with the controller.
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining("Couldn't confirm your answer"), findsOne);
    expect(
      gateway.methods.where((m) => m == 'connection.respond'),
      hasLength(1),
    );

    await emit(tester, 'connection.update', {
      ...connectionUpdateFixture,
      'seq': 9,
      'settled': true,
      'owner': {'type': 'session', 'session_id': 'rt-1'},
    });
    expect(dock(), findsNothing);
    await finish(tester);
  });

  testWidgets('a refused answer says so and offers the actions again', (
    tester,
  ) async {
    gateway.handlers['connection.respond'] = (_) => {
      'status': 'denied',
      'settled': false,
    };
    await pumpScreen(tester);
    await request(tester);
    await tester.tap(button('needs-you-continue'));
    await settle(tester);
    expect(find.text('The server refused your answer.'), findsOneWidget);
    expect(enabled(tester, 'needs-you-continue'), isTrue);
    await finish(tester);
  });

  testWidgets('Skip is per target: one in the row for a single target, one '
      'under each target for several', (tester) async {
    await pumpScreen(tester);
    await request(tester);
    expect(button('needs-you-skip'), findsOneWidget);
    await tester.tap(button('needs-you-skip'));
    await settle(tester);
    final one = gateway.requestOf('connection.respond')['params'] as Map;
    expect((one['result'] as Map)['targets'], [
      {'name': 'synthetic-connector', 'status': 'skipped'},
    ]);

    final target =
        (connectionRequestFixture['targets']! as List).single
            as Map<String, Object?>;
    await emit(tester, 'connection.request', {
      ...connectionRequestFixture,
      'op_id': 'two',
      'targets': [
        {...target, 'name': 'first'},
        {...target, 'name': 'second'},
      ],
    });
    await tester.tap(find.byKey(const Key('needs-you-next')));
    await settle(tester);
    expect(button('needs-you-skip'), findsNothing);
    expect(button('needs-you-skip-first'), findsOneWidget);
    expect(button('needs-you-skip-second'), findsOneWidget);
    await tester.tap(button('needs-you-skip-second'));
    await settle(tester);
    final two =
        gateway.requests
                .where((r) => r['method'] == 'connection.respond')
                .last['params']
            as Map;
    expect(two['op_id'], 'two');
    expect((two['result'] as Map)['targets'], [
      {'name': 'second', 'status': 'skipped'},
    ]);
    await finish(tester);
  });

  group('billing verification', () {
    Future<void> details(WidgetTester tester) => emit(
      tester,
      'billing.step_up.verification',
      billingVerificationFixture,
    );

    testWidgets('shows in the dock with its code, announced by kind only', (
      tester,
    ) async {
      await pumpScreen(tester);
      await details(tester);
      expect(find.text('Billing access needs approval'), findsOneWidget);
      expect(find.text('PRIVATE-CODE'), findsOneWidget);
      expect(find.text('Copy code'), findsOneWidget);
      expect(announced, ['Billing access needs approval']);
      expect(announced.join(), isNot(contains('PRIVATE')));
      expect(find.bySemanticsLabel('Activity, 1 needs you'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('leaves when App Lock covers the app', (tester) async {
      await pumpScreen(tester);
      await details(tester);
      expect(find.text('PRIVATE-CODE'), findsOneWidget);
      lock.covered = true;
      await tester.pump();
      expect(find.text('PRIVATE-CODE'), findsNothing);
      expect(dock(), findsNothing);
      await finish(tester);
    });

    testWidgets('is discarded when the connection drops', (tester) async {
      await pumpScreen(tester);
      await details(tester);
      gateway.drop();
      await settle(tester);
      expect(find.text('PRIVATE-CODE'), findsNothing);
      expect(dock(), findsNothing);
      await finish(tester);
    });
  });

  group('while the connection is lost', () {
    Future<void> drop(WidgetTester tester) async {
      gateway.drop();
      await settle(tester);
    }

    testWidgets('Reopen stays available on a reclaimed chat, because it '
        'reconnects', (tester) async {
      await pumpScreen(tester);
      await emit(tester, 'session.reclaimed', {
        'session_id': 'rt-1',
        'stored_session_id': 'stored-1',
        'reason': 'Opened elsewhere',
      });
      expect(find.byKey(const Key('needs-you-reopen')), findsOneWidget);
      await drop(tester);
      expect(find.textContaining('Offline. These actions'), findsNothing);
      expect(enabled(tester, 'needs-you-reopen'), isTrue);
      await finish(tester);
    });

    testWidgets('a connector sign-in stays, display-only, with its actions '
        'disabled', (tester) async {
      await pumpScreen(tester);
      await request(tester);
      expect(enabled(tester, 'needs-you-continue'), isTrue);
      await drop(tester);

      expect(dock(), findsOneWidget);
      expect(find.textContaining('Offline. These actions'), findsOneWidget);
      for (final key in [
        'needs-you-continue',
        'needs-you-skip',
        'needs-you-open',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
        expect(
          tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed,
          isNull,
          reason: '$key is disabled offline',
        );
      }
      // No second announcement and the marker stays.
      expect(announced, ['A connection needs you']);
      expect(find.bySemanticsLabel('Activity, 1 needs you'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('the reconnect replay brings the actions back', (tester) async {
      var resumes = 0;
      gateway.handlers['session.resume'] = (params) {
        resumes++;
        return {
          // The reconnect lands on a new runtime session.
          'session_id': resumes == 1 ? 'rt-1' : 'rt-2',
          'stored_session_id': params['session_id'],
          'session_key': params['session_id'],
          if (resumes > 1) 'pending_connection': connectionRequestFixture,
        };
      };
      await pumpScreen(tester);
      await request(tester);
      await drop(tester);
      expect(enabled(tester, 'needs-you-continue'), isFalse);

      // The next send reconnects and resumes the chat, which replays the
      // operation the server still holds.
      await tester.enterText(composerField, 'Back again');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await settle(tester);
      await settle(tester);

      expect(find.textContaining('Offline. These actions'), findsNothing);
      expect(enabled(tester, 'needs-you-continue'), isTrue);
      // The same operation under a new runtime: not announced again.
      expect(announced, ['A connection needs you']);
      expect(find.bySemanticsLabel('Activity, 1 needs you'), findsOneWidget);
      await finish(tester);
    });
  });
}

class _Lock extends AppLockController {
  var _covered = false;

  @override
  bool get covered => _covered;

  set covered(bool value) {
    _covered = value;
    notifyListeners();
  }
}
