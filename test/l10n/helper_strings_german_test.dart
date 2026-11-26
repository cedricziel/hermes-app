import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/widgets/takeover_confirmation.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposals_list.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profiles_view.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/schedules/widgets/schedules_mac_toolbar.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_localizations.dart';
import '../support/tooltip_finder.dart';

/// Widgets whose English text used to sit in the widget file, drawn in German.
/// Each area asserts the German words and that the English ones are gone.
Widget _german(Widget child) => MaterialApp(
  theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
  locale: const Locale('de'),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: const [Locale('en'), Locale('de')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('the takeover confirmation reads in German', (tester) async {
    await tester.pumpWidget(
      _german(TakeoverConfirmation(onCancel: () {}, onConfirm: (_) {})),
    );
    expect(find.text('Bildschirm übernehmen?'), findsOneWidget);
    expect(find.text('Nicht mehr fragen'), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Übernehmen'), findsOneWidget);
    expect(
      find.textContaining('Was du tippst, geht an den Desktop'),
      findsOneWidget,
    );
    expect(find.text('Take over'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });

  group('the waiting list', () {
    Widget list(ProposalsSnapshot snapshot) => _german(
      SizedBox(
        height: 900,
        child: MemoryProposalsList(
          snapshot: snapshot,
          onOpen: (_) {},
          onRetry: () {},
          onRejectAll: () {},
        ),
      ),
    );

    testWidgets('says in German that nothing waits', (tester) async {
      await tester.pumpWidget(
        list(
          const ProposalsSnapshot(
            memory: KindRead(ProposalReadStatus.ok),
            skills: KindRead(ProposalReadStatus.ok),
          ),
        ),
      );
      expect(find.text('Nichts wartet'), findsOneWidget);
      expect(
        find.text('Änderungen, die Hermes vorschlägt, erscheinen hier.'),
        findsOneWidget,
      );
      expect(find.text('Nothing is waiting'), findsNothing);
    });

    testWidgets('names what could not be read in German', (tester) async {
      await tester.pumpWidget(
        list(
          const ProposalsSnapshot(
            memory: KindRead(ProposalReadStatus.failed),
            skills: KindRead(ProposalReadStatus.unreadable, [], 'x'),
          ),
        ),
      );
      expect(
        find.text('Änderungen am Gedächtnis konnten nicht gelesen werden'),
        findsOneWidget,
      );
      expect(
        find.text('Hermes hat so geantwortet, dass die App es nicht versteht'),
        findsOneWidget,
      );
      expect(find.textContaining("Couldn't read"), findsNothing);
    });

    testWidgets('names a failed skills read in German', (tester) async {
      await tester.pumpWidget(
        list(
          const ProposalsSnapshot(
            memory: KindRead(ProposalReadStatus.ok),
            skills: KindRead(ProposalReadStatus.failed),
          ),
        ),
      );
      expect(
        find.text('Änderungen an Skills konnten nicht gelesen werden'),
        findsOneWidget,
      );
    });

    testWidgets('says in German that this server cannot list changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        list(
          const ProposalsSnapshot(
            memory: KindRead(ProposalReadStatus.unsupported),
            skills: KindRead(ProposalReadStatus.unsupported),
          ),
        ),
      );
      expect(
        find.text('Änderungen lassen sich auf diesem Server nicht lesen'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the Mac profile page names its sections in German', (
    tester,
  ) async {
    await tester.pumpWidget(
      _german(
        SizedBox(
          height: 1200,
          width: 900,
          child: MacProfilesView(
            profiles: const [HermesProfile(name: 'default')],
            selected: 'default',
            onSelect: (_) {},
            counts: const {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    for (final text in [
      'Gedächtnis',
      'MCP-Server',
      'Hilfsmodelle',
      'Was der Agent kann',
      'Chat-Plattformen, auf denen der Agent antwortet',
      'Modelle für Nebenaufgaben',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('MCP servers'), findsNothing);
    expect(find.text('Helper models'), findsNothing);
    expect(find.text('Models for side tasks'), findsNothing);
  });

  group('the schedule picker', () {
    Widget picker(ScheduleSpec spec) => _german(
      SchedulePicker(
        spec: spec,
        now: DateTime(2026, 9, 20, 12),
        onChanged: (_) {},
      ),
    );

    testWidgets('names the five modes and the every row in German', (
      tester,
    ) async {
      await tester.pumpWidget(picker(const EverySpec(3, EveryUnit.hours)));
      for (final text in [
        'Alle',
        'Intervall',
        'Täglich',
        'Wöchentlich',
        'Einmal',
        'Cron',
        'Einheit',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Daily'), findsNothing);
      expect(find.text('Unit'), findsNothing);
    });

    testWidgets('names the time and the cron rows in German', (tester) async {
      await tester.pumpWidget(picker(const DailySpec(9, 30)));
      expect(find.text('Uhrzeit'), findsOneWidget);
      expect(find.text('Time'), findsNothing);
      await tester.pumpWidget(picker(const CronSpec('0 9 * * 1-5')));
      expect(find.text('Zeitplan'), findsOneWidget);
    });

    testWidgets('names the date row in German', (tester) async {
      await tester.pumpWidget(picker(OnceSpec(DateTime(2026, 9, 21, 8))));
      expect(find.text('Datum'), findsOneWidget);
    });
  });

  testWidgets('the Schedules toolbar reads in German', (tester) async {
    await tester.pumpWidget(
      _german(
        SchedulesMacToolbar(
          jobCount: 2,
          allProfiles: false,
          onScopeChanged: (_) {},
          filterMenu: const SizedBox.shrink(),
          onRefresh: () {},
          onNew: () {},
        ),
      ),
    );
    expect(find.text('Zeitpläne'), findsOneWidget);
    expect(find.tooltip('Neuer Zeitplan ⌘N'), findsOneWidget);
    expect(find.text('Dieses Profil'), findsOneWidget);
    expect(find.text('Alle Profile'), findsOneWidget);
    expect(find.tooltip('New Schedule ⌘N'), findsNothing);
    expect(find.text('This profile'), findsNothing);
  });
}
