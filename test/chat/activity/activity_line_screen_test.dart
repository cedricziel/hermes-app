import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/widgets/chat_header.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_gateway.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/pump_chat.dart';

/// The chat screen's activity line against the real gateway transport and a
/// scripted gateway.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late ChatProfiles profiles;
  late BreadcrumbTrail trail;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail(capacity: 100);
    gateway = FakeGateway()..activeSessions = {};
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
    await transport.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    TargetPlatform? platform,
    Size size = const Size(1400, 900),
  }) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      chatProfiles: profiles,
      platform: platform,
      size: size,
      providers: [Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail))],
    );
    await openThread(tester, 'First chat');
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  // The line is up while a turn runs and the server reports a status; the
  // turn completing takes it down (the server never clears a status).
  const sentence = 'Compiling the zebra report';
  Future<void> status(WidgetTester tester, String text) async {
    if (text.isEmpty) {
      gateway.event('message.complete', 'rt-1', {
        'text': 'Done',
        'status': 'complete',
      });
    } else {
      await tester.enterText(composerField, 'Go on');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await settle(tester);
      gateway.event('status.update', 'rt-1', {'kind': 'status', 'text': text});
    }
    await settle(tester);
  }

  final line = find.byKey(const Key('activity-line'));
  final inspector = find.byKey(const Key('activity-inspector'));
  List<String> crumbs() => [
    for (final c in trail.recent)
      if (c.name.startsWith('chat.activity')) '${c.name} ${c.attributes}',
  ];

  // The inspector docks at desktop width and is drawn over the chat on a
  // tablet, where the scrim closes it.
  for (final (name, size, close) in [
    (
      'Material desktop',
      const Size(1400, 900),
      (WidgetTester t) => t.tap(find.byKey(const Key('header-activity'))),
    ),
    (
      'tablet',
      const Size(1024, 768),
      (WidgetTester t) => t.tapAt(const Offset(320, 500)),
    ),
  ]) {
    testWidgets('$name: the line sits under the header while something works, '
        'opens the inspector, hides while it is open and goes when the turn '
        'settles', (tester) async {
      await pumpScreen(tester, size: size);
      expect(line, findsNothing);

      await status(tester, sentence);
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.text(sentence)),
        findsOneWidget,
      );
      final header = tester.getRect(find.byType(ChatHeader));
      final rect = tester.getRect(line);
      // Under the header and its divider, above the transcript.
      expect(rect.top, moreOrLessEquals(header.bottom + 1, epsilon: 1));
      expect(rect.height, 48);

      final before = trail.recent.length;
      await tester.tap(line);
      await tester.pump(const Duration(milliseconds: 400));
      expect(inspector, findsOneWidget);
      // Opening from the line records one activity crumb, and no text of the
      // sentence is in any breadcrumb. (The panel's rows record their own.)
      expect(
        [
          for (final c in trail.recent.skip(before))
            if (c.name.startsWith('chat.activity.')) c.name,
        ],
        ['chat.activity.opened'],
      );
      expect(
        trail.recent.any((c) => '${c.name} ${c.attributes}'.contains('zebra')),
        isFalse,
      );
      expect(line, findsNothing);
      expect(crumbs(), [
        'chat.activity.opened {surface: inspector, source: line}',
      ]);

      await close(tester);
      // The line's spinner never settles.
      await tester.pump(const Duration(milliseconds: 400));
      expect(inspector, findsNothing);
      expect(line, findsOneWidget);

      await status(tester, '');
      await tester.pumpAndSettle();
      expect(line, findsNothing);
      await finish(tester);
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('a phone (${platform.name}): the line stays while the sheet '
        'covers the chat', (tester) async {
      await pumpScreen(tester, platform: platform);
      tester.view.physicalSize = const Size(390, 844);
      await settle(tester);
      await status(tester, sentence);
      expect(line, findsOneWidget);

      await tester.tap(line);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('activity-close')), findsOneWidget);
      expect(crumbs(), ['chat.activity.opened {surface: sheet, source: line}']);
      expect(
        find.descendant(
          of: find.byType(ActivityLine),
          matching: find.text(sentence),
        ),
        findsOneWidget,
      );
      await finish(tester);
    });
  }

  testWidgets('macOS: no line, the toolbar subtitle carries the sentence', (
    tester,
  ) async {
    await pumpScreen(tester, platform: TargetPlatform.macOS);
    expect(find.byType(MacChatToolbar), findsOneWidget);
    expect(find.byKey(const Key('mac-subtitle-status')), findsNothing);

    await status(tester, sentence);
    expect(find.byType(ActivityLine), findsNothing);
    expect(
      find.descendant(
        of: find.byType(MacChatToolbar),
        matching: find.text(sentence),
      ),
      findsOneWidget,
    );

    await status(tester, '');
    expect(find.byKey(const Key('mac-subtitle-status')), findsNothing);
    await finish(tester);
  });
}
