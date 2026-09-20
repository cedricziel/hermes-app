import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/bots/bots_screen.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';

import 'support/fake_hermes_server.dart';

/// The bots screen against a fake dashboard, through the real generated
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

  Future<void> pumpBots(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BotsScreen(repository: HermesBotsRepository(server.client().raw)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String name) => find.widgetWithText(ListTile, name);

  Switch switchIn(WidgetTester tester, String name) => tester.widget<Switch>(
    find.descendant(of: tile(name), matching: find.byType(Switch)),
  );

  testWidgets('lists every messaging platform with its description', (
    tester,
  ) async {
    await pumpBots(tester);

    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Discord'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.textContaining('Run Hermes from Telegram.'), findsOneWidget);
  });

  testWidgets('shows a spinner while the bots load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BotsScreen(repository: HermesBotsRepository(server.client().raw)),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('reflects which bots are switched on', (tester) async {
    await pumpBots(tester);

    expect(switchIn(tester, 'Telegram').value, isTrue);
    expect(switchIn(tester, 'Discord').value, isFalse);
  });

  testWidgets('a bot without credentials says it needs setup and cannot be '
      'switched on', (tester) async {
    await pumpBots(tester);

    expect(
      find.descendant(of: tile('WhatsApp'), matching: find.text('Needs setup')),
      findsOneWidget,
    );
    expect(switchIn(tester, 'WhatsApp').onChanged, isNull);
  });

  testWidgets('an enabled bot that lost its credential can be switched off', (
    tester,
  ) async {
    server.on('PUT', '/api/messaging/platforms/signal', {'ok': true});
    await pumpBots(tester);

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
    expect(switchIn(tester, 'Signal').value, isFalse);
    expect(switchIn(tester, 'Signal').onChanged, isNull);
  });

  testWidgets('shows the error a bot reports', (tester) async {
    await pumpBots(tester);

    expect(
      find.descendant(
        of: tile('Slack'),
        matching: find.textContaining('Invalid bot token'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('switching a bot on sends the change and shows the new state', (
    tester,
  ) async {
    await pumpBots(tester);
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
  });

  testWidgets('a rejected change leaves the bot as it was and says so', (
    tester,
  ) async {
    await pumpBots(tester);
    server.on('PUT', '/api/messaging/platforms/discord', {
      'detail': 'x',
    }, status: 500);

    await tester.tap(
      find.descendant(of: tile('Discord'), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not update this bot'), findsOneWidget);
    expect(switchIn(tester, 'Discord').value, isFalse);
  });

  testWidgets('a failed load shows an error with a working retry', (
    tester,
  ) async {
    server.on('GET', '/api/messaging/platforms', {
      'detail': 'boom',
    }, status: 500);
    await pumpBots(tester);
    expect(find.text('Could not load bots'), findsOneWidget);

    server.on(
      'GET',
      '/api/messaging/platforms',
      platformListBody([platformRow(id: 'telegram', name: 'Telegram')]),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load bots'), findsNothing);
    expect(find.text('Telegram'), findsOneWidget);
  });
}
