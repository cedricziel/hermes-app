import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/memory/memory_settings.dart';
import 'package:hermes_app/src/memory/widgets/memory_learning_section.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedule_widgets.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/schedules/widgets/schedule_sections.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_controller.dart';
import 'package:hermes_app/src/skills/widgets/installed_skills_list.dart';
import 'package:hermes_app/src/skills/widgets/skill_badges.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_localizations.dart';

/// The label helpers take the localizations (`arch.label-helper-takes-l10n`):
/// every known value in both languages, a value the app does not know as the
/// server sent it, and each place that shows one in German.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  Widget german(Widget home) => MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  );

  group('MemoryLearningSection.intervalLabel', () {
    test('English', () {
      expect(MemoryLearningSection.intervalLabel(en, 0), 'Off');
      expect(MemoryLearningSection.intervalLabel(en, 1), 'After every message');
      expect(
        MemoryLearningSection.intervalLabel(en, 10),
        'After every 10 messages',
      );
    });
    test('German', () {
      expect(MemoryLearningSection.intervalLabel(de, 0), 'Aus');
      expect(
        MemoryLearningSection.intervalLabel(de, 1),
        'Nach jeder Nachricht',
      );
      expect(
        MemoryLearningSection.intervalLabel(de, 10),
        'Nach jeweils 10 Nachrichten',
      );
    });
  });

  group('MemoryLearningSection.reportLabel', () {
    test('English', () {
      expect(MemoryLearningSection.reportLabel(en, 'off'), 'Off');
      expect(MemoryLearningSection.reportLabel(en, 'on'), 'Short note');
      expect(MemoryLearningSection.reportLabel(en, 'verbose'), 'With details');
      expect(MemoryLearningSection.reportLabel(en, 'loud'), 'loud');
    });
    test('German', () {
      expect(MemoryLearningSection.reportLabel(de, 'off'), 'Aus');
      expect(MemoryLearningSection.reportLabel(de, 'on'), 'Kurze Notiz');
      expect(MemoryLearningSection.reportLabel(de, 'verbose'), 'Mit Details');
      expect(MemoryLearningSection.reportLabel(de, 'loud'), 'loud');
    });
  });

  group('deliveryLabel', () {
    test('English', () {
      expect(deliveryLabel(en, null), 'Local');
      expect(deliveryLabel(en, ''), 'Local');
      expect(deliveryLabel(en, 'local'), 'Local');
      expect(deliveryLabel(en, 'origin'), 'Origin chat');
      expect(deliveryLabel(en, 'telegram'), 'Telegram');
    });
    test('German', () {
      expect(deliveryLabel(de, null), 'Lokal');
      expect(deliveryLabel(de, ''), 'Lokal');
      expect(deliveryLabel(de, 'local'), 'Lokal');
      expect(deliveryLabel(de, 'origin'), 'Ursprungschat');
      expect(deliveryLabel(de, 'telegram'), 'Telegram');
    });
  });

  group('skillSourceLabel', () {
    test('English', () {
      expect(skillSourceLabel(en, SkillSource.hub), 'Hub');
      expect(skillSourceLabel(en, SkillSource.bundled), 'Bundled');
      expect(skillSourceLabel(en, SkillSource.agent), 'Agent');
    });
    test('German', () {
      expect(skillSourceLabel(de, SkillSource.hub), 'Hub');
      expect(skillSourceLabel(de, SkillSource.bundled), 'Mitgeliefert');
      expect(skillSourceLabel(de, SkillSource.agent), 'Agent');
    });
  });

  group('trustLabel', () {
    test('English', () {
      expect(trustLabel(en, 'builtin'), 'Official');
      expect(trustLabel(en, 'trusted'), 'Trusted');
      expect(trustLabel(en, 'community'), 'Community');
      expect(trustLabel(en, 'unheard-of'), 'Community');
    });
    test('German', () {
      expect(trustLabel(de, 'builtin'), 'Offiziell');
      expect(trustLabel(de, 'trusted'), 'Vertrauenswürdig');
      expect(trustLabel(de, 'community'), 'Community');
      expect(trustLabel(de, 'unheard-of'), 'Community');
    });
  });

  testWidgets('the memory learning section shows its choices in German', (
    tester,
  ) async {
    await tester.pumpWidget(
      german(
        ListView(
          children: [
            MemoryLearningSection(
              settings: MemorySettings.defaults.withValue(
                MemorySetting.updatesInChat,
                'loud',
              ),
              onChanged: (_, _) {},
              onRetry: () {},
            ),
          ],
        ),
      ),
    );
    // Mutation: put 'After every $turns messages' back in intervalLabel.
    expect(find.text('Nach jeweils 10 Nachrichten'), findsOneWidget);
    // Mutation: translate or drop the server's own word for an unknown mode.
    expect(find.text('loud'), findsOneWidget);

    await tester.tap(find.text('Review chats'));
    await tester.pumpAndSettle();
    // Mutation: put 'Off' back in intervalLabel.
    expect(find.text('Aus'), findsOneWidget);
    expect(find.text('Nach jeweils 5 Nachrichten'), findsOneWidget);
    expect(find.text('Off'), findsNothing);
  });

  testWidgets('the report choices are German', (tester) async {
    await tester.pumpWidget(
      german(
        ListView(
          children: [
            MemoryLearningSection(
              settings: MemorySettings.defaults,
              onChanged: (_, _) {},
              onRetry: () {},
            ),
          ],
        ),
      ),
    );
    // Mutation: put 'Short note' back in reportLabel.
    expect(find.text('Kurze Notiz'), findsOneWidget);
    await tester.tap(find.text('Memory updates in chat'));
    await tester.pumpAndSettle();
    // Mutation: put 'With details' back in reportLabel.
    expect(find.text('Mit Details'), findsOneWidget);
    expect(find.text('With details'), findsNothing);
  });

  testWidgets("a schedule's delivery is German in the list and the facts", (
    tester,
  ) async {
    const job = CronJob(id: 'a', name: 'Daily', deliver: 'origin');
    const local = CronJob(id: 'b', name: 'Nightly');
    await tester.pumpWidget(
      german(
        ListView(
          children: [
            JobTile(
              job: job,
              now: DateTime(2026),
              onTap: () {},
              onPausedChanged: (_) {},
            ),
            JobTile(
              job: local,
              now: DateTime(2026),
              onTap: () {},
              onPausedChanged: (_) {},
            ),
            Builder(
              builder: (context) =>
                  Column(children: scheduleFactSections(context.l10n, job)),
            ),
          ],
        ),
      ),
    );
    // Mutation: put 'Origin chat' / 'Local' back in deliveryLabel.
    expect(find.textContaining('Ursprungschat'), findsNWidgets(2));
    expect(find.textContaining('Lokal'), findsOneWidget);
    expect(find.textContaining('Origin chat'), findsNothing);
    expect(find.textContaining('Local'), findsNothing);
  });

  testWidgets('the skill badges and subtitle are German', (tester) async {
    await tester.pumpWidget(
      german(
        Column(
          children: [
            const TrustBadge('builtin'),
            const TrustBadge('trusted'),
            const TrustBadge('community'),
            const SourceBadge(SkillSource.bundled),
            Expanded(
              child: InstalledSkillsList(
                groups: const [
                  SkillGroup('apple', [
                    HermesSkill(name: 'notes', source: SkillSource.bundled),
                  ]),
                ],
                onOpen: (_) {},
                onToggle: (_, _) {},
                onClearFilters: () {},
              ),
            ),
          ],
        ),
      ),
    );
    // Mutation: put 'Official' / 'Trusted' back in trustLabel.
    expect(find.text('Offiziell'), findsOneWidget);
    expect(find.text('Vertrauenswürdig'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    // Mutation: put 'Bundled' back in skillSourceLabel (badge and subtitle).
    expect(find.text('Mitgeliefert'), findsNWidgets(2));
    expect(find.text('Official'), findsNothing);
    expect(find.textContaining('Bundled'), findsNothing);
  });
}
