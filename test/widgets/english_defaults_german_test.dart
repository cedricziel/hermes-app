import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/chat/moa_progress_state.dart';
import 'package:hermes_app/src/chat/widgets/moa_progress_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_arguments_view.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/plugins/plugin_actions.dart';
import 'package:hermes_app/src/plugins/widgets/catalog_row.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/settings_search_field.dart';

import '../support/test_localizations.dart';

/// A German device gets German words where a helper used to default its text
/// to an English literal: the default is read from the localizations.
Widget _german(Widget home) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  testWidgets('a confirm dialog without a cancel label says Abbrechen', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      _german(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final answer = showConfirmDialog(
      context,
      title: 'Titel',
      confirmLabel: 'Ja',
    );
    await tester.pumpAndSettle();
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  testWidgets('a settings search field without a hint says Suchen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _german(
        SettingsSearchField(
          search: SettingsSearch(query: '', onChanged: (_) {}),
        ),
      ),
    );
    expect(find.text('Suchen'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('the Mac toolbar search field without a hint says Suchen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _german(
        MacToolbarSearchField(
          query: '',
          active: false,
          onChanged: (_) {},
          onEnd: () {},
        ),
      ),
    );
    expect(find.text('Suchen'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('tool arguments without a title are headed Eingabe', (
    tester,
  ) async {
    await tester.pumpWidget(
      _german(const ToolArgumentsView(arguments: {'command': 'ls'})),
    );
    expect(find.text('Eingabe'), findsOneWidget);
    expect(find.text('Input'), findsNothing);
  });

  testWidgets('a catalog row install button without a label says '
      'Installieren', (tester) async {
    await tester.pumpWidget(
      _german(InstallButton(installing: false, onPressed: () {})),
    );
    expect(find.text('Installieren'), findsOneWidget);
    expect(find.text('Install'), findsNothing);
  });

  testWidgets('a refused plugin change with no reason says so in German', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      _german(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await runPluginChange(
      context,
      () async => const PluginActionResult(ok: false),
    );
    await tester.pump();
    expect(find.text('Das Plugin konnte nicht geändert werden'), findsOne);
    expect(find.text('Could not update this plugin'), findsNothing);
  });

  group('the lost-control notice of the Bot Screen viewer', () {
    Widget view({required bool lostToAgent}) => _german(
      BotScreenViewerView(
        phase: BotScreenViewerPhase.blanked,
        profile: 'research',
        control: BotScreenControl.lost,
        lostToAgent: lostToAgent,
      ),
    );

    testWidgets('names Hermes in German', (tester) async {
      await tester.pumpWidget(view(lostToAgent: true));
      expect(find.text('Hermes hat die Steuerung zurückgenommen.'), findsOne);
      expect(find.text('Hermes took control back.'), findsNothing);
    });

    testWidgets('names someone else in German', (tester) async {
      await tester.pumpWidget(view(lostToAgent: false));
      expect(
        find.text('Jemand anderes hat die Steuerung übernommen.'),
        findsOne,
      );
      expect(find.text('Someone else took control.'), findsNothing);
    });
  });

  group('the advisor progress card', () {
    testWidgets('words the advisors phase in German', (tester) async {
      await tester.pumpWidget(
        _german(const MoaProgressCard(progress: MoaProgress(turn: 't'))),
      );
      expect(find.text('Beraterfortschritt · Berater'), findsOneWidget);
    });

    testWidgets('words the aggregating phase in German', (tester) async {
      await tester.pumpWidget(
        _german(
          const MoaProgressCard(
            progress: MoaProgress(turn: 't', aggregating: true),
          ),
        ),
      );
      expect(find.text('Beraterfortschritt · Zusammenführung'), findsOne);
    });

    testWidgets('shows a reported phase name as it came, and Abgeschlossen '
        'when done', (tester) async {
      await tester.pumpWidget(
        _german(
          const MoaProgressCard(
            progress: MoaProgress(turn: 't', phase: 'X'),
          ),
        ),
      );
      expect(find.text('Beraterfortschritt · X'), findsOneWidget);
      await tester.pumpWidget(
        _german(
          const MoaProgressCard(
            progress: MoaProgress(turn: 't', phase: 'X', live: false),
          ),
        ),
      );
      expect(find.text('Beraterfortschritt · Abgeschlossen'), findsOneWidget);
    });
  });
}
