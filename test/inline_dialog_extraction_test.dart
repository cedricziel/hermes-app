import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart'
    show ExportJsonOffer;
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/macos/mac_toolbar.dart'
    show macToolbarButtonStyle;
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/named_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';

import 'support/fake_hermes_server.dart';
import 'support/test_localizations.dart';

/// What a user sees and can do in three pieces the screens build from their
/// own widgets: the Kanban workers Inspect dialog, the hub skill's install
/// confirmation and the Mac chat toolbar's "…" menu. Each case drives the
/// real screen, opens the piece and asserts the app's own output: the texts,
/// the actions' semantics, which menu items there are and whether they are
/// enabled, what a dialog answers, and the few app-owned properties a user
/// sees (text alignment, gap, icon size, colour role). Nothing here reads a
/// framework widget's private state, so a Flutter upgrade does not move it.

AppLocalizations _de() => lookupAppLocalizations(const Locale('de'));

Widget _app(
  Widget home, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  builder: (_, child) => AppThemeScopes(child: child!),
  theme: theme,
  home: home,
);

List<String> _texts(WidgetTester tester, Finder within) => [
  for (final w in tester.widgetList<Text>(
    find.descendant(of: within, matching: find.byType(Text)),
  ))
    w.data ?? w.textSpan?.toPlainText() ?? '',
];

/// The label and whether it is a button with a tap action, for the action
/// whose text is [label] inside [within].
String _action(WidgetTester tester, Finder within, String label) {
  final node = tester.getSemantics(
    find.descendant(
      of: within,
      matching: find.widgetWithText(AppDialogAction, label),
    ),
  );
  final data = node.getSemanticsData();
  return '${node.label}|button=${data.flagsCollection.isButton}'
      '|tap=${data.hasAction(SemanticsAction.tap)}';
}

void main() {
  group('Kanban Inspect dialog', () {
    Future<Finder> open(
      WidgetTester tester,
      Map<String, Object?> inspection, {
      Locale locale = const Locale('en'),
    }) async {
      final server = FakeHermesServer()
        ..on('GET', '/api/plugins/kanban/workers/active', {
          'workers': [
            {
              'run_id': 7,
              'task_id': 't1',
              'task_title': 'Migrate webhooks',
              'profile': 'coder',
              'worker_pid': 4242,
              'started_at': 1780000000,
            },
          ],
        })
        ..on('GET', '/api/plugins/kanban/runs/7/inspect', inspection);
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          KanbanWorkersScreen(
            repository: KanbanRepository(server.client()),
            board: 'ops',
          ),
          locale: locale,
          theme: buildHermesLightTheme(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<RowAction>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          locale.languageCode == 'de'
              ? 'Prozess untersuchen'
              : 'Inspect process',
        ),
      );
      await tester.pumpAndSettle();
      return find.byType(AppAlertDialog);
    }

    testWidgets('a run with a process lists its figures', (tester) async {
      final handle = tester.ensureSemantics();
      final dialog = await open(tester, {
        'alive': true,
        'pid': 4242,
        'cpu_percent': 12.5,
        'memory_rss_bytes': 104857600,
        'num_threads': 9,
        'status': 'sleeping',
        'reason': 'child of dispatcher',
      });

      expect(_texts(tester, dialog), [
        'Run #7',
        'Process 4242\nStatus: sleeping\nMemory: 100 MB\nThreads: 9\n'
            'child of dispatcher',
        'Close',
      ]);
      expect(_action(tester, dialog, 'Close'), 'Close|button=true|tap=true');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AppAlertDialog), findsNothing);
      handle.dispose();
    });

    testWidgets('rounds the memory to whole megabytes', (tester) async {
      final dialog = await open(tester, {
        'alive': true,
        'memory_rss_bytes': 1572864,
      });
      expect(_texts(tester, dialog), ['Run #7', 'Memory: 2 MB', 'Close']);
    });

    testWidgets('a process that is gone says why', (tester) async {
      final dialog = await open(tester, {
        'alive': false,
        'reason': 'process not found',
      });
      expect(_texts(tester, dialog), [
        'Run #7',
        'The process is not running: process not found.',
        'Close',
      ]);
    });

    testWidgets('a process that is gone without a note', (tester) async {
      final dialog = await open(tester, {'alive': false});
      expect(_texts(tester, dialog), [
        'Run #7',
        'The process is not running.',
        'Close',
      ]);
    });

    testWidgets('in German', (tester) async {
      final l10n = _de();
      final dialog = await open(tester, {
        'alive': true,
        'pid': 4242,
        'memory_rss_bytes': 104857600,
        'num_threads': 9,
      }, locale: const Locale('de'));
      expect(_texts(tester, dialog), [
        l10n.kanbanInspectTitle(7),
        [
          l10n.kanbanInspectProcess(4242),
          l10n.kanbanInspectMemory('100'),
          l10n.kanbanInspectThreads(9),
        ].join('\n'),
        l10n.kanbanInspectClose,
      ]);
    });
  });

  group('Hub skill install confirmation', () {
    late FakeHermesServer server;

    Future<Finder> open(
      WidgetTester tester, {
      String reason = 'Findings need a look.',
      List<Map<String, Object?>>? findings,
      Locale locale = const Locale('en'),
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      server = FakeHermesServer()
        ..on('GET', '/api/skills', [])
        ..on('GET', '/api/skills/hub/official', {'skills': []})
        ..on('GET', '/api/skills/hub/sources', {
          'sources': [
            {'id': 'github', 'label': 'GitHub'},
          ],
          'featured': [],
          'installed': {},
        })
        ..on('GET', '/api/skills/hub/search', {
          'results': [
            hubSkillRow(name: 'web-scraper', description: 'Scrape pages'),
          ],
          'timed_out': [],
          'installed': {},
        })
        ..on('GET', '/api/skills/hub/preview', {
          'name': 'web-scraper',
          'skill_md': '# Web scraper',
          'files': ['SKILL.md'],
        })
        ..on('POST', '/api/skills/hub/install', {
          'ok': true,
          'pid': 4242,
          'name': 'skills-install-web-scraper',
        })
        ..on(
          'GET',
          '/api/actions/skills-install-web-scraper/status',
          jobStatusBody(lines: ['Done']),
        )
        ..on(
          'GET',
          '/api/skills/hub/scan',
          hubScanBody(
            policy: 'ask',
            reason: reason,
            findings:
                findings ??
                [
                  hubFindingRow(),
                  hubFindingRow(
                    severity: 'low',
                    description: 'Reads the environment',
                    file: 'scripts/env.sh',
                    line: 3,
                  ),
                ],
          ),
        );
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          SkillsScreen(
            repository: HermesSkillsRepository(server.client().raw),
            hubRepository: HermesSkillsHubRepository(server.client().raw),
            chatProfile: 'work',
          ),
          locale: locale,
          theme: ThemeData(platform: platform),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(locale.languageCode == 'de' ? 'Entdecken' : 'Discover'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'scrape');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('web-scraper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install anyway…'));
      await tester.pumpAndSettle();
      return find.byType(AppAlertDialog);
    }

    testWidgets('lists the reason and every finding', (tester) async {
      final handle = tester.ensureSemantics();
      final dialog = await open(tester);

      expect(_texts(tester, dialog), [
        'Install web-scraper?',
        'Findings need a look.',
        'HIGH  Downloads and runs a remote script',
        'scripts/fetch.sh:12',
        'LOW  Reads the environment',
        'scripts/env.sh:3',
        'Cancel',
        'Install anyway',
      ]);
      expect(_action(tester, dialog, 'Cancel'), 'Cancel|button=true|tap=true');
      expect(
        _action(tester, dialog, 'Install anyway'),
        'Install anyway|button=true|tap=true',
      );
      handle.dispose();
    });

    testWidgets('the findings start-align, a 12 gap follows the reason', (
      tester,
    ) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final dialog = await open(tester, platform: platform);
        final reason = find.descendant(
          of: dialog,
          matching: find.text('Findings need a look.'),
        );
        expect(
          DefaultTextStyle.of(tester.element(reason)).textAlign,
          TextAlign.start,
          reason: '$platform',
        );
        final column = tester.widget<Column>(
          find.ancestor(of: reason, matching: find.byType(Column)).first,
        );
        expect((column.children[1] as SizedBox).height, 12);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Install anyway is the default action, Cancel is not', (
      tester,
    ) async {
      final dialog = await open(tester);
      bool isDefault(String label) => tester
          .widget<AppDialogAction>(
            find.descendant(
              of: dialog,
              matching: find.widgetWithText(AppDialogAction, label),
            ),
          )
          .isDefault;
      expect(isDefault('Install anyway'), isTrue);
      expect(isDefault('Cancel'), isFalse);
    });

    testWidgets('without a policy reason it says the scan asks', (
      tester,
    ) async {
      final dialog = await open(tester, reason: '');
      expect(_texts(tester, dialog).sublist(0, 2), [
        'Install web-scraper?',
        'The security scan asks for your confirmation.',
      ]);
    });

    testWidgets('without findings only the reason is listed', (tester) async {
      final dialog = await open(tester, findings: []);
      expect(_texts(tester, dialog), [
        'Install web-scraper?',
        'Findings need a look.',
        'Cancel',
        'Install anyway',
      ]);
    });

    testWidgets('in German', (tester) async {
      final l10n = _de();
      final dialog = await open(
        tester,
        reason: '',
        findings: [],
        locale: const Locale('de'),
      );
      expect(_texts(tester, dialog), [
        l10n.skillsHubInstallTitle('web-scraper'),
        l10n.skillsHubInstallScanAsks,
        l10n.skillsHubInstallCancel,
        l10n.skillsHubInstallAnyway,
      ]);
    });
  });

  group('Mac chat toolbar "…" menu', () {
    Future<void> pump(
      WidgetTester tester, {
      VoidCallback? onShowFiles,
      VoidCallback? onCopyTranscript,
      ExportJsonOffer? exportJson,
      Locale locale = const Locale('en'),
      List<String>? log,
    }) async {
      tester.view
        ..physicalSize = const Size(680, 700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: MacChatToolbar(
                title: 'Plan the release',
                subtitle: 'default · example-model',
                onNewChat: () {},
                onShowConnection: () => log?.add('connection'),
                onCopyTranscript: onCopyTranscript,
                onShowFiles: onShowFiles,
                exportJson: exportJson,
                searchQuery: '',
                searchActive: false,
                onSearchBegin: () {},
                onSearchChanged: (_) {},
                onSearchEnd: () {},
              ),
            ),
          ),
          locale: locale,
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        ),
      );
    }

    /// Each row of the open menu: its texts, its semantics label and whether
    /// it is enabled.
    Future<List<String>> rows(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('toolbar-more')));
      await tester.pumpAndSettle();
      return [
        for (final item in tester.widgetList<PopupMenuItem<dynamic>>(
          find.byWidgetPredicate((w) => w is PopupMenuItem),
        ))
          () {
            final finder = find.byWidget(item);
            final texts = _texts(tester, finder).join(' ');
            final label = tester
                .getSemantics(finder)
                .label
                .replaceAll('\n', ' ');
            return '$texts|label=$label|${item.enabled ? 'on' : 'off'}';
          }(),
      ];
    }

    testWidgets('lists every item, enabled', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        onShowFiles: () {},
        onCopyTranscript: () {},
        exportJson: ExportJsonOffer(onSelected: () {}),
      );
      expect(await rows(tester), [
        'Show Files ⇧⌘F|label=Show Files ⇧⌘F|on',
        'Copy Transcript|label=Copy Transcript|on',
        'Export Chat as JSON…|label=Export Chat as JSON…|on',
        'Connection Details|label=Connection Details|on',
      ]);
      handle.dispose();
    });

    testWidgets('an export in progress greys its item', (tester) async {
      await pump(
        tester,
        onShowFiles: () {},
        onCopyTranscript: () {},
        exportJson: ExportJsonOffer(onSelected: () {}, enabled: false),
      );
      expect(await rows(tester), [
        'Show Files ⇧⌘F|label=Show Files ⇧⌘F|on',
        'Copy Transcript|label=Copy Transcript|on',
        'Export Chat as JSON…|label=Export Chat as JSON…|off',
        'Connection Details|label=Connection Details|on',
      ]);
    });

    testWidgets('Copy Transcript is greyed without a chat', (tester) async {
      await pump(
        tester,
        onShowFiles: () {},
        exportJson: ExportJsonOffer(onSelected: () {}),
      );
      expect(await rows(tester), [
        'Show Files ⇧⌘F|label=Show Files ⇧⌘F|on',
        'Copy Transcript|label=Copy Transcript|off',
        'Export Chat as JSON…|label=Export Chat as JSON…|on',
        'Connection Details|label=Connection Details|on',
      ]);
    });

    testWidgets('leaves out Show Files and the export when not offered', (
      tester,
    ) async {
      await pump(tester, onCopyTranscript: () {});
      expect(await rows(tester), [
        'Copy Transcript|label=Copy Transcript|on',
        'Connection Details|label=Connection Details|on',
      ]);
    });

    testWidgets('the button is named More, 18 wide, in the subtle colour', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, onCopyTranscript: () {});
      final more = find.byKey(const Key('toolbar-more'));
      final button = tester.widget<NamedPopupMenuButton<Object?>>(more);
      expect(button.iconSize, 18);
      expect(button.color, tester.element(more).hermesColors.subtleText);
      expect(button.padding, EdgeInsets.zero);
      final style = macToolbarButtonStyle(tester.element(more));
      expect(
        button.style?.fixedSize?.resolve({}),
        style.fixedSize?.resolve({}),
      );
      expect(
        button.style?.minimumSize?.resolve({}),
        style.minimumSize?.resolve({}),
      );
      expect(button.style?.padding?.resolve({}), style.padding?.resolve({}));
      expect(button.style?.iconSize?.resolve({}), style.iconSize?.resolve({}));
      expect(button.style?.tapTargetSize, style.tapTargetSize);
      expect(button.style?.visualDensity, style.visualDensity);
      expect(find.bySemanticsLabel('More'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('choosing an item runs only its callback, once', (
      tester,
    ) async {
      for (final (label, event) in [
        ('Show Files', 'files'),
        ('Copy Transcript', 'copy'),
        ('Export Chat as JSON…', 'export'),
        ('Connection Details', 'connection'),
      ]) {
        final log = <String>[];
        await pump(
          tester,
          log: log,
          onShowFiles: () => log.add('files'),
          onCopyTranscript: () => log.add('copy'),
          exportJson: ExportJsonOffer(onSelected: () => log.add('export')),
        );
        await tester.tap(find.byKey(const Key('toolbar-more')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(log, [event], reason: label);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('in German', (tester) async {
      final l10n = _de();
      await pump(
        tester,
        onShowFiles: () {},
        onCopyTranscript: () {},
        exportJson: ExportJsonOffer(onSelected: () {}),
        locale: const Locale('de'),
      );
      expect(
        find.bySemanticsLabel(l10n.chatWidgetsMacToolbarMore),
        findsOneWidget,
      );
      final shown = await rows(tester);
      expect(shown.map((r) => r.split('|').first), [
        '${l10n.macosMenuShowFiles} ⇧⌘F',
        l10n.macosMenuCopyTranscript,
        l10n.macosMenuExportChat,
        l10n.macosMenuConnectionDetails,
      ]);
    });
  });
}
