import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/widgets/command_row.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_chip.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/server_care/widgets/log_line_tile.dart';
import 'package:hermes_app/src/server_care/widgets/server_restart_banner.dart';
import 'package:hermes_app/src/server_care/widgets/update_status_card.dart';
import 'package:hermes_app/src/server_care/widgets/update_step_list.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Widget _german(Widget child) => MaterialApp(
  theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
  locale: const Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('the update status card speaks German', (tester) async {
    await tester.pumpWidget(
      _german(
        UpdateStatusCard(
          status: const UpdateAvailable(
            changeCount: 12,
            currentVersion: '0.22.0',
          ),
          onUpdate: () {},
        ),
      ),
    );
    expect(find.text('Update verfügbar'), findsOneWidget);
    expect(
      find.text('12 Änderungen seit deiner Version (0.22.0).'),
      findsOneWidget,
    );
    expect(find.text('Hermes aktualisieren'), findsOneWidget);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('the outcome card speaks German', (tester) async {
    await tester.pumpWidget(
      _german(
        const UpdateOutcomeCard(
          kind: UpdateOutcomeKind.success,
          version: '0.23.0',
        ),
      ),
    );
    expect(find.text('Hermes ist aktuell'), findsOneWidget);
    expect(find.text('Jetzt läuft 0.23.0.'), findsOneWidget);
    expect(find.text('Fertig'), findsOneWidget);
  });

  testWidgets('the step list words steps and states in German', (tester) async {
    await tester.pumpWidget(
      _german(
        const UpdateStepList(
          steps: [
            UpdateStep.starting(UpdateStepState.done),
            UpdateStep.restarting(UpdateStepState.failed),
          ],
          detailLines: ['x'],
        ),
      ),
    );
    expect(find.text('Wird aktualisiert …'), findsOneWidget);
    expect(find.text('Update wird gestartet'), findsOneWidget);
    expect(find.text('Hermes wird neu gestartet'), findsOneWidget);
    expect(find.text('Fehlgeschlagen'), findsOneWidget);
    expect(find.text('Details anzeigen'), findsOneWidget);
  });

  testWidgets('the restart banner speaks German', (tester) async {
    await tester.pumpWidget(
      _german(ServerRestartBanner.ready(version: '0.23.0', onClose: () {})),
    );
    expect(find.text('Hermes 0.23.0 ist bereit'), findsOneWidget);
    expect(find.byTooltip('Schließen'), findsOneWidget);
  });

  testWidgets('log widgets speak German', (tester) async {
    await tester.pumpWidget(
      _german(
        Column(
          children: [
            const LogLevelChip(level: LogLevel.warning),
            LogLevelMenuButton(value: LogLevelFilter.errors, onChanged: (_) {}),
            const LogLineTile(
              message: 'm',
              continuation: ['a', 'b', 'c', 'd', 'e'],
            ),
            CommandRow(command: 'hermes update'),
          ],
        ),
      ),
    );
    expect(find.text('Warnung'), findsOneWidget);
    expect(find.text('Nur Fehler'), findsOneWidget);
    expect(find.text('2 weitere Zeilen anzeigen'), findsOneWidget);
    expect(find.text('Kopieren'), findsOneWidget);
  });
}
