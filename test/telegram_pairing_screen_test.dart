import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/bots/telegram_pairing_screen.dart';

import 'support/fake_hermes_server.dart';

/// Pairing a Telegram bot from the app, against a fake dashboard through the
/// real generated client.
void main() {
  const start = '/api/messaging/telegram/onboarding/start';
  const pairing = '/api/messaging/telegram/onboarding/p1';
  const interval = Duration(seconds: 3);

  late FakeHermesServer server;
  late List<Uri> launched;
  bool? result;

  setUp(() {
    server = FakeHermesServer()
      ..on('POST', start, telegramPairingStartBody())
      ..on('GET', pairing, {'status': 'waiting'})
      ..on('DELETE', pairing, {'ok': true})
      ..on('POST', '$pairing/apply', {'ok': true});
    launched = [];
    result = null;
  });

  /// Leaving a pairing cancels it, and the request that does so must finish
  /// before the test does.
  void pairingTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  /// The waiting spinner never stops animating, so `pumpAndSettle` can't be
  /// used while a pairing is open.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openPairing(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => TelegramPairingScreen(
                    repository: HermesBotsRepository(server.client().raw),
                    pollInterval: interval,
                    launchLink: (uri) async {
                      launched.add(uri);
                      return true;
                    },
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> claim(WidgetTester tester, {String owner = '4711'}) async {
    server.on('GET', pairing, {
      'status': 'ready',
      'bot_username': 'hermes_1_bot',
      'owner_user_id': owner,
    });
    await tester.pump(interval);
    await settle(tester);
  }

  pairingTest('starts a pairing and shows what to do', (tester) async {
    await openPairing(tester);

    expect(server.requestsTo('POST', start), hasLength(1));
    expect(find.textContaining('Telegram'), findsWidgets);
    expect(find.text('https://t.me/HermesBot?start=pair_p1'), findsOneWidget);
    expect(find.text('Waiting for you in Telegram'), findsOneWidget);
  });

  pairingTest('opens the link in Telegram', (tester) async {
    await openPairing(tester);

    await tester.tap(find.text('Open Telegram'));
    await tester.pump();

    expect(launched.single.toString(), 'https://t.me/HermesBot?start=pair_p1');
  });

  pairingTest('keeps polling while nobody has claimed the bot', (tester) async {
    await openPairing(tester);

    await tester.pump(interval);
    await tester.pump(interval);

    expect(server.requestsTo('GET', pairing).length, greaterThanOrEqualTo(2));
    expect(find.text('Waiting for you in Telegram'), findsOneWidget);
  });

  pairingTest('once claimed, names the bot and offers the owner as the '
      'allowed user', (tester) async {
    await openPairing(tester);

    await claim(tester);

    expect(find.textContaining('@hermes_1_bot'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '4711',
    );
    final polls = server.requestsTo('GET', pairing).length;
    await tester.pump(interval * 3);
    expect(server.requestsTo('GET', pairing), hasLength(polls));
  });

  pairingTest('saving sends the allowed user ids and finishes', (tester) async {
    await openPairing(tester);
    await claim(tester);
    await tester.enterText(find.byType(TextField), '4711, 42');

    await tester.tap(find.text('Finish setup'));
    await settle(tester);

    expect(jsonBody(server.requestsTo('POST', '$pairing/apply').single), {
      'allowed_user_ids': ['4711', '42'],
    });
    expect(result, isTrue);
    expect(find.byType(TelegramPairingScreen), findsNothing);
    expect(server.requestsTo('DELETE', pairing), isEmpty);
  });

  pairingTest('ids that are not numeric never leave the app', (tester) async {
    await openPairing(tester);
    await claim(tester);
    await tester.enterText(find.byType(TextField), 'abc');

    await tester.tap(find.text('Finish setup'));
    await settle(tester);

    expect(
      find.text('Use numeric Telegram user IDs, separated by commas'),
      findsOneWidget,
    );
    expect(server.requestsTo('POST', '$pairing/apply'), isEmpty);
  });

  pairingTest('at least one user id is needed', (tester) async {
    await openPairing(tester);
    await claim(tester, owner: '');

    await tester.tap(find.text('Finish setup'));
    await settle(tester);

    expect(find.text('Add at least one Telegram user ID'), findsOneWidget);
    expect(server.requestsTo('POST', '$pairing/apply'), isEmpty);
  });

  pairingTest('a refused save keeps the form and gives the reason', (
    tester,
  ) async {
    server.on('POST', '$pairing/apply', {
      'detail': 'Failed to save Telegram setup.',
    }, status: 400);
    await openPairing(tester);
    await claim(tester);

    await tester.tap(find.text('Finish setup'));
    await settle(tester);

    expect(find.text('Failed to save Telegram setup.'), findsOneWidget);
    expect(find.text('Finish setup'), findsOneWidget);
    expect(result, isNull);
  });

  pairingTest('an unexplained save failure says so and keeps the form', (
    tester,
  ) async {
    server.on('POST', '$pairing/apply', {'detail': 'x'}, status: 500);
    await openPairing(tester);
    await claim(tester);

    await tester.tap(find.text('Finish setup'));
    await settle(tester);

    expect(find.text('Could not save the setup'), findsOneWidget);
    expect(find.text('Finish setup'), findsOneWidget);
  });

  pairingTest('an expired pairing says so and can be started again', (
    tester,
  ) async {
    await openPairing(tester);
    server.on('GET', pairing, {
      'detail': 'Telegram setup expired. Start a new setup.',
    }, status: 410);
    await tester.pump(interval);
    await settle(tester);

    expect(
      find.text('Telegram setup expired. Start a new setup.'),
      findsOneWidget,
    );
    server
      ..on('POST', start, telegramPairingStartBody(id: 'p2'))
      ..on('GET', '/api/messaging/telegram/onboarding/p2', {
        'status': 'waiting',
      });

    await tester.tap(find.text('Start again'));
    await settle(tester);

    expect(server.requestsTo('POST', start), hasLength(2));
    expect(find.text('https://t.me/HermesBot?start=pair_p2'), findsOneWidget);
  });

  pairingTest('a setup service that cannot be reached says so and can be '
      'retried', (tester) async {
    server.on('POST', start, {
      'detail': 'Telegram setup service is unavailable. Try again shortly.',
    }, status: 502);
    await openPairing(tester);

    expect(
      find.text('Telegram setup service is unavailable. Try again shortly.'),
      findsOneWidget,
    );
    server.on('POST', start, telegramPairingStartBody());

    await tester.tap(find.text('Start again'));
    await settle(tester);

    expect(find.text('Waiting for you in Telegram'), findsOneWidget);
  });

  pairingTest('leaving before it is claimed cancels the pairing', (
    tester,
  ) async {
    await openPairing(tester);

    await tester.pageBack();
    await settle(tester);

    expect(server.requestsTo('DELETE', pairing), hasLength(1));
    expect(result, isNull);
  });

  pairingTest('leaving stops the polling', (tester) async {
    await openPairing(tester);
    await tester.pageBack();
    await settle(tester);
    final polls = server.requestsTo('GET', pairing).length;

    await tester.pump(interval * 3);

    expect(server.requestsTo('GET', pairing), hasLength(polls));
  });
}
