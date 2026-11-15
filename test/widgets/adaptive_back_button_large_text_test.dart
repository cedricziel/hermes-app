import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/messaging_setup_screen.dart';
import 'package:hermes_app/src/messaging/telegram_pairing_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../support/fake_hermes_server.dart';

Widget _app(
  double scale,
  Widget Function(BuildContext) screen, {
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: brightness == Brightness.light
      ? buildHermesLightTheme(platform: TargetPlatform.iOS)
      : buildHermesDarkTheme(platform: TargetPlatform.iOS),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: screen)),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'POST',
        '/api/messaging/telegram/onboarding/start',
        telegramPairingStartBody(),
      )
      ..on('GET', '/api/messaging/telegram/onboarding/p1', {
        'status': 'waiting',
      })
      ..on('DELETE', '/api/messaging/telegram/onboarding/p1', {'ok': true});
  });

  final screens = <String, Widget Function(BuildContext)>{
    'messaging setup': (_) => MessagingSetupScreen(
      platform: const HermesMessagingPlatform(id: 'discord', name: 'Discord'),
      repository: HermesMessagingRepository(server.client().raw),
    ),
    'telegram pairing': (_) => TelegramPairingScreen(
      repository: HermesMessagingRepository(server.client().raw),
      launchLink: (_) async => true,
    ),
  };

  for (final entry in screens.entries) {
    for (final scale in [1.5, 2.0, 3.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('${entry.key} back collapses cleanly at ${scale}x '
            '(${brightness.name})', (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _app(scale, entry.value, brightness: brightness),
          );
          await tester.tap(find.text('Open'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull);
          expect(find.text('Messaging'), findsNothing);
          final chevron = find.byIcon(CupertinoIcons.back);
          expect(chevron, findsOneWidget);
          final rect = tester.getRect(chevron);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.width, greaterThanOrEqualTo(30));

          await tester.tap(chevron);
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('Open'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }

  testWidgets('below 1.5x the back button keeps its label', (tester) async {
    await tester.pumpWidget(_app(1.2, screens['messaging setup']!));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Messaging'), findsOneWidget);
  });
}
