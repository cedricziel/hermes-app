import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/messaging/messaging_screen.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_on_platform.dart';

/// The messaging screen against a fake dashboard, through the real generated
/// client.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'telegram',
            name: 'Telegram',
            description: 'Run Hermes from Telegram.',
            enabled: true,
            configured: true,
            state: 'connected',
          ),
          platformRow(
            id: 'discord',
            name: 'Discord',
            configured: true,
            state: 'disabled',
          ),
          platformRow(id: 'whatsapp', name: 'WhatsApp'),
          platformRow(
            id: 'signal',
            name: 'Signal',
            enabled: true,
            state: 'error',
          ),
          platformRow(
            id: 'slack',
            name: 'Slack',
            enabled: true,
            configured: true,
            state: 'error',
            errorMessage: 'Invalid bot token',
          ),
        ]),
      )
      ..on('PUT', '/api/messaging/platforms/discord', {'ok': true});
  });

  Future<void> pumpMessaging(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagingScreen(
          repository: HermesMessagingRepository(server.client().raw),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String name) => find.widgetWithText(MessagingPlatformRow, name);

  Switch switchIn(WidgetTester tester, String name) => tester.widget<Switch>(
    find.descendant(of: tile(name), matching: find.byType(Switch)),
  );

  testWidgets('lists every messaging platform with its description', (
    tester,
  ) async {
    await pumpMessaging(tester);

    expect(find.text('Messaging'), findsOneWidget);
    expect(
      find.text(
        'Connect Hermes to Telegram, Discord, and other messaging platforms.',
      ),
      findsOneWidget,
    );
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Discord'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.textContaining('Run Hermes from Telegram.'), findsOneWidget);
  });

  testWidgets('keeps its rows to a readable width on a wide window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpMessaging(tester);

    expect(tester.getSize(tile('Telegram')).width, lessThanOrEqualTo(640));
  });

  testWidgets('shows a spinner while the platforms load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagingScreen(
          repository: HermesMessagingRepository(server.client().raw),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('reflects which platforms are switched on', (tester) async {
    await pumpMessaging(tester);

    expect(switchIn(tester, 'Telegram').value, isTrue);
    expect(switchIn(tester, 'Discord').value, isFalse);
  });

  testWidgets(
    'a platform without credentials offers setup in place of its switch',
    (tester) async {
      await pumpMessaging(tester);

      expect(
        find.descendant(of: tile('WhatsApp'), matching: find.byType(Switch)),
        findsNothing,
      );
      await tester.tap(
        find.descendant(
          of: tile('WhatsApp'),
          matching: find.widgetWithText(OutlinedButton, 'Set up'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set up WhatsApp'), findsOneWidget);
      expect(
        server.requestsTo('PUT', '/api/messaging/platforms/whatsapp'),
        isEmpty,
      );
    },
  );

  testWidgets(
    'an enabled platform that lost its credential can be switched off',
    (tester) async {
      server.on('PUT', '/api/messaging/platforms/signal', {'ok': true});
      await pumpMessaging(tester);

      expect(switchIn(tester, 'Signal').value, isTrue);
      expect(switchIn(tester, 'Signal').onChanged, isNotNull);
      expect(
        find.descendant(of: tile('Signal'), matching: find.text('Needs setup')),
        findsOneWidget,
      );

      server.on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([platformRow(id: 'signal', name: 'Signal')]),
      );
      await tester.tap(
        find.descendant(of: tile('Signal'), matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      final request = server
          .requestsTo('PUT', '/api/messaging/platforms/signal')
          .single;
      expect((jsonBody(request) as Map)['enabled'], isFalse);
      expect(
        find.descendant(of: tile('Signal'), matching: find.byType(Switch)),
        findsNothing,
      );
      expect(
        find.descendant(of: tile('Signal'), matching: find.text('Set up')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows the error a platform reports', (tester) async {
    await pumpMessaging(tester);

    expect(
      find.descendant(
        of: tile('Slack'),
        matching: find.textContaining('Invalid bot token'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'switching a platform on sends the change and shows the new state',
    (tester) async {
      await pumpMessaging(tester);
      server.on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'discord',
            name: 'Discord',
            enabled: true,
            configured: true,
            state: 'connected',
          ),
        ]),
      );

      await tester.tap(
        find.descendant(of: tile('Discord'), matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      final request = server
          .requestsTo('PUT', '/api/messaging/platforms/discord')
          .single;
      expect((jsonBody(request) as Map)['enabled'], isTrue);
      expect(switchIn(tester, 'Discord').value, isTrue);
    },
  );

  testWidgets('a rejected change leaves the platform as it was and says so', (
    tester,
  ) async {
    await pumpMessaging(tester);
    server.on('PUT', '/api/messaging/platforms/discord', {
      'detail': 'x',
    }, status: 500);

    await tester.tap(
      find.descendant(of: tile('Discord'), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not update this messaging platform'),
      findsOneWidget,
    );
    expect(switchIn(tester, 'Discord').value, isFalse);
  });

  testWidgets('a failed load shows an error with a working retry', (
    tester,
  ) async {
    server.on('GET', '/api/messaging/platforms', {
      'detail': 'boom',
    }, status: 500);
    await pumpMessaging(tester);
    expect(find.text('Could not load messaging platforms'), findsOneWidget);

    server.on(
      'GET',
      '/api/messaging/platforms',
      platformListBody([platformRow(id: 'telegram', name: 'Telegram')]),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load messaging platforms'), findsNothing);
    expect(find.text('Telegram'), findsOneWidget);
  });

  Future<void> pumpOn(WidgetTester tester, TargetPlatform platform) async {
    await pumpOnPlatform(
      tester,
      MessagingScreen(
        repository: HermesMessagingRepository(server.client().raw),
      ),
      platform: platform,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('on a Mac the bar counts the platforms switched on', (
    tester,
  ) async {
    await pumpOn(tester, TargetPlatform.macOS);

    expect(find.text('3 of 5 on'), findsOneWidget);
    expect(
      find.descendant(
        of: tile('WhatsApp'),
        matching: find.widgetWithText(OutlinedButton, 'Set Up…'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('on an iPhone a platform without credentials reads Set Up and '
      'opens its setup', (tester) async {
    await pumpOn(tester, TargetPlatform.iOS);

    expect(find.text('3 of 5 on'), findsNothing);
    await tester.tap(
      find.descendant(of: tile('WhatsApp'), matching: find.text('Set Up')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up WhatsApp'), findsOneWidget);
  });
}
