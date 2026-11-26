import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_localizations.dart';
import 'support/tooltip_finder.dart';

/// Every tooltip, accessible name and progress line of the reply action bar is
/// said in the screen's language.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    ReadAloudState readAloud = ReadAloudState.idle,
    TurnActionStatus status = TurnActionStatus.idle,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      locale: const Locale('de'),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MessageActions(
          text: 'The build finished.',
          status: status,
          onRetry: () {},
          onEdit: () {},
          onBranch: () {},
          readAloud: readAloud,
          onReadAloud: () {},
        ),
      ),
    ),
  );

  void expectLabel(String german) {
    expect(find.tooltip(german), findsOneWidget, reason: german);
    expect(find.bySemanticsLabel(german), findsOneWidget, reason: german);
  }

  testWidgets('the idle bar is German', (tester) async {
    await pump(tester);

    for (final label in [
      'Kopieren',
      'Vorlesen',
      'Erneut versuchen',
      'Prompt bearbeiten',
      'In neuem Chat verzweigen',
    ]) {
      expectLabel(label);
    }
    for (final english in [
      'Copy',
      'Read aloud',
      'Try again',
      'Edit prompt',
      'Branch in new chat',
    ]) {
      expect(find.tooltip(english), findsNothing, reason: english);
    }
  });

  testWidgets('Copy says Kopiert once copied', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester);

    await tester.tap(find.tooltip('Kopieren'));
    await tester.pump();

    expectLabel('Kopiert');
    await tester.pump(const Duration(seconds: 3));
  });

  for (final state in [ReadAloudState.playing, ReadAloudState.loading]) {
    testWidgets('while $state the stop action is German', (tester) async {
      await pump(tester, readAloud: state);

      expectLabel('Vorlesen beenden');
    });
  }

  for (final (action, text) in [
    (TurnAction.retry, 'Neuer Versuch …'),
    (TurnAction.edit, 'Prompt wird zurückgeholt …'),
    (TurnAction.branch, 'Chat wird verzweigt …'),
  ]) {
    testWidgets('$action says its progress in German', (tester) async {
      await pump(tester, status: TurnActionStatus(running: action));

      expect(find.text(text), findsOneWidget);
    });
  }
}
