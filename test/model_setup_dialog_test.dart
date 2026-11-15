import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/models/widgets/model_setup_dialog.dart';

Future<void> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  String? profile = 'default',
  Locale? locale,
  Size size = const Size(1366, 1024),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      locale: locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModelSetup(context, profile),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('the setup dialog stays within the dialog cap on an iPad '
        'sized screen ($platform)', (tester) async {
      await _open(tester, platform: platform);

      expect(find.text('Set up a model'), findsOneWidget);
      final isIos = platform == TargetPlatform.iOS;
      final dialog = find.byType(isIos ? CupertinoAlertDialog : AlertDialog);
      expect(dialog, findsOneWidget);
      // The alert widget is laid out at the window's width; measure the panel
      // the user sees: its first Material, or a button row on Cupertino.
      final panel = find.descendant(
        of: dialog,
        matching: find.byType(isIos ? CupertinoDialogAction : Material),
      );
      expect(tester.getSize(panel.first).width, lessThanOrEqualTo(560));
    });
  }

  testWidgets('a profile name with a quote is shell-quoted in the command', (
    tester,
  ) async {
    await _open(tester, platform: TargetPlatform.android, profile: "it's x");

    final command = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(command.data, "hermes -p 'it'\"'\"'s x' model");
  });

  testWidgets('the title is German in the German locale', (tester) async {
    await _open(
      tester,
      platform: TargetPlatform.android,
      locale: const Locale('de'),
    );

    expect(find.text('Modell einrichten'), findsOneWidget);
    expect(find.text('Erneut prüfen'), findsOneWidget);
  });

  testWidgets('the command is a monospace line', (tester) async {
    await _open(tester, platform: TargetPlatform.android);

    final command = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(command.style?.fontFamily, 'monospace');
    expect(command.data, 'hermes model');
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final locale in [const Locale('en'), const Locale('de')]) {
      testWidgets('at 320x568 and double text size nothing overflows and the '
          'command and button are reachable '
          '($platform, ${locale.languageCode})', (tester) async {
        await _open(
          tester,
          platform: platform,
          profile: 'work-assistant',
          locale: locale,
          size: const Size(320, 568),
          textScale: 2,
        );

        expect(tester.takeException(), isNull);
        final command = find.text('hermes -p work-assistant model');
        expect(command, findsOneWidget);
        final button = find.text(
          locale.languageCode == 'de' ? 'Erneut prüfen' : 'Check again',
        );
        expect(button, findsOneWidget);
        const screen = Rect.fromLTWH(0, 0, 320, 568);
        // The button stays on screen; the command is on screen or can be
        // scrolled into view.
        expect(screen.contains(tester.getCenter(button)), isTrue);
        await tester.ensureVisible(command);
        await tester.pumpAndSettle();
        expect(screen.contains(tester.getCenter(command)), isTrue);
        expect(tester.takeException(), isNull);

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(SelectableText), findsNothing);
      });
    }
  }
}
