import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/widgets/swipeable_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/touch_row_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';

import '../support/accessibility_announcements.dart';
import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';
import '../support/tooltip_finder.dart';

/// A German device gets German words on a chat row everywhere: the phone's
/// action sheet, the swipe actions, VoiceOver's custom actions and the
/// iPad popover.
void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    required Size size,
    bool canonical = false,
    bool pinned = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: SwipeableThreadRow(
            title: 'Release notes',
            pinned: pinned,
            canonical: canonical,
            onAction: (_) {},
            child: const SizedBox(height: 44, child: Text('Row')),
          ),
        ),
      ),
    );
  }

  testWidgets('the phone sheet is German', (tester) async {
    await pumpRow(tester, size: const Size(390, 844));

    await tester.longPress(find.text('Row'));
    await tester.pumpAndSettle();

    final sheet = find.byType(CupertinoActionSheet);
    for (final label in [
      'Umbenennen',
      'Anheften',
      'Archivieren',
      'Löschen',
      'Abbrechen',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.text('Rename'), findsNothing);
  });

  testWidgets('the swipe actions are German', (tester) async {
    await pumpRow(tester, size: const Size(390, 844));

    await tester.drag(find.text('Row'), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Anheften'), findsOneWidget);
    await tester.drag(find.text('Row'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Löschen'), findsOneWidget);
  });

  testWidgets('the VoiceOver actions are German', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRow(tester, size: const Size(390, 844));

    final data = tester.getSemantics(find.text('Row')).getSemanticsData();
    final labels = [
      for (final id in data.customSemanticsActionIds!)
        CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(
      labels,
      containsAll(['Umbenennen', 'Anheften', 'Archivieren', 'Löschen']),
    );
    handle.dispose();
  });

  testWidgets('the iPad popover is German and named', (tester) async {
    final said = captureAnnouncements(tester);
    await pumpRow(tester, size: const Size(1024, 768));

    await tester.longPress(find.text('Row'));
    await tester.pumpAndSettle();

    final items = find.byType(CupertinoMenuItem);
    for (final label in ['Umbenennen', 'Anheften', 'Archivieren', 'Löschen']) {
      expect(
        find.descendant(of: items, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(said, [
      (message: 'Chat-Aktionen für Release notes', textDirection: 1),
    ]);
  });

  testWidgets('a Bot Chat popover has no Rename and offers Retire', (
    tester,
  ) async {
    final actions = <ThreadAction>[];
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: TouchRowMenu(
            title: 'Bot',
            pinned: false,
            canonical: true,
            onAction: actions.add,
            child: const SizedBox(height: 44, child: Text('Row')),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Row'));
    await tester.pumpAndSettle();

    final items = find.byType(CupertinoMenuItem);
    expect(
      find.descendant(of: items, matching: find.text('Rename')),
      findsNothing,
    );
    expect(
      find.descendant(of: items, matching: find.text('Archive')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: items, matching: find.text('Retire Bot Chat…')),
    );
    await tester.pumpAndSettle();
    expect(actions, [ThreadAction.archive]);
  });

  testWidgets(
    'a pinned row offers Unpin in German on the sheet and VoiceOver',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, size: const Size(390, 844), pinned: true);

      final data = tester.getSemantics(find.text('Row')).getSemanticsData();
      final labels = [
        for (final id in data.customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(labels, contains('Nicht mehr anheften'));
      await tester.longPress(find.text('Row'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CupertinoActionSheet),
          matching: find.text('Nicht mehr anheften'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets('a Bot Chat row has no Rename and says Retire in German', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpRow(tester, size: const Size(390, 844), canonical: true);

    final data = tester.getSemantics(find.text('Row')).getSemanticsData();
    final labels = [
      for (final id in data.customSemanticsActionIds!)
        CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(labels, contains('Bot-Chat beenden …'));
    expect(labels, isNot(contains('Umbenennen')));
    expect(labels, isNot(contains('Archivieren')));
    await tester.longPress(find.text('Row'));
    await tester.pumpAndSettle();
    final sheet = find.byType(CupertinoActionSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Bot-Chat beenden …')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Umbenennen')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Archivieren')),
      findsNothing,
    );
    handle.dispose();
  });

  group('ThreadActionsButton on macOS', () {
    ThreadHousekeeping housekeeping({bool historyFails = false}) =>
        ThreadHousekeeping(
          repository: HermesChatRepository(FakeHermesServer().client().raw),
          threads: () => const [],
          profile: () => null,
          changed: () {},
          report: (_) {},
          removed: (_) {},
          history: (thread, {cancelled}) async =>
              historyFails ? throw StateError('offline') : const [],
          branch: (_) async {},
        );

    Future<void> openMenu(
      WidgetTester tester, {
      bool historyFails = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: ThreadActionsButton(
              thread: ChatThread(
                id: 's1',
                title: 'Release notes',
                updatedAt: DateTime(2026),
                remote: true,
              ),
              housekeeping: housekeeping(historyFails: historyFails),
              onOpenInNewWindow: (_) {},
              exportJson: ExportJsonOffer(onSelected: () {}),
            ),
          ),
        ),
      );
      await tester.tap(find.tooltip('Chat-Aktionen'));
      await tester.pumpAndSettle();
    }

    testWidgets('every menu item is German', (tester) async {
      await openMenu(tester);
      for (final label in [
        'In neuem Fenster öffnen',
        'Umbenennen …',
        'Anheften',
        'Verlauf kopieren',
        'Chat als JSON exportieren …',
        'In neuem Chat verzweigen',
        'Archivieren',
        'Löschen …',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('copying says so in German', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openMenu(tester);
      await tester.tap(find.text('Verlauf kopieren'));
      await tester.pumpAndSettle();
      expect(find.text('Verlauf kopiert'), findsOneWidget);
    });

    testWidgets('a failed copy says so in German', (tester) async {
      await openMenu(tester, historyFails: true);
      await tester.tap(find.text('Verlauf kopieren'));
      await tester.pumpAndSettle();
      expect(
        find.text('Der Verlauf konnte nicht kopiert werden'),
        findsOneWidget,
      );
    });
  });

  group('ThreadActionsButton on iOS', () {
    ThreadHousekeeping housekeeping() => ThreadHousekeeping(
      repository: HermesChatRepository(FakeHermesServer().client().raw),
      threads: () => const [],
      profile: () => null,
      changed: () {},
      report: (_) {},
      removed: (_) {},
      history: (thread, {cancelled}) async => const [],
    );

    Future<void> pumpButton(
      WidgetTester tester, {
      required ChatThread thread,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: ThreadActionsButton(
              thread: thread,
              housekeeping: housekeeping(),
              includeCopyTranscript: true,
              onShowFiles: () {},
              exportJson: ExportJsonOffer(onSelected: () {}),
            ),
          ),
        ),
      );
    }

    final items = find.byType(CupertinoMenuItem);

    testWidgets('every item, the tooltip and the name are German', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpButton(
        tester,
        thread: ChatThread(
          id: 's1',
          title: 'Release notes',
          updatedAt: DateTime(2026),
          pinned: true,
        ),
      );
      expect(find.tooltip('Chat-Aktionen'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Chat-Aktionen für Release notes'),
        findsOneWidget,
      );

      await tester.tap(find.tooltip('Chat-Aktionen'));
      await tester.pumpAndSettle();

      for (final label in [
        'Dateien',
        'Verlauf kopieren',
        'Chat als JSON exportieren …',
        'Umbenennen',
        'Nicht mehr anheften',
        'Archivieren',
        'Löschen',
      ]) {
        expect(
          find.descendant(of: items, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      handle.dispose();
    });

    testWidgets('Rename asks in German', (tester) async {
      await pumpButton(
        tester,
        thread: ChatThread(
          id: 's1',
          title: 'Release notes',
          updatedAt: DateTime(2026),
        ),
      );

      await tester.tap(find.tooltip('Chat-Aktionen'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: items, matching: find.text('Umbenennen')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chat umbenennen'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('Delete asks in German', (tester) async {
      await pumpButton(
        tester,
        thread: ChatThread(
          id: 's1',
          title: 'Release notes',
          updatedAt: DateTime(2026),
        ),
      );

      await tester.tap(find.tooltip('Chat-Aktionen'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: items, matching: find.text('Löschen')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diesen Chat löschen?'), findsOneWidget);
      expect(
        find.text(
          '„Release notes“ und die Nachrichten darin werden endgültig gelöscht.',
        ),
        findsOneWidget,
      );
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Löschen'), findsOneWidget);
    });

    testWidgets('a Bot Chat offers Retire, and its confirmation is German', (
      tester,
    ) async {
      await pumpButton(
        tester,
        thread: ChatThread(
          id: 's1',
          title: 'Hermes',
          updatedAt: DateTime(2026),
          botContext: const BotChatContext(
            bot: BotModeBot(serverId: 'server', name: 'default', revision: 0),
            rootId: 'root',
            storedId: 'tip',
          ),
        ),
      );

      await tester.tap(find.tooltip('Chat-Aktionen'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: items, matching: find.text('Umbenennen')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: items, matching: find.text('Bot-Chat beenden …')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diesen Bot-Chat beenden?'), findsOneWidget);
      expect(find.text('Bot-Chat beenden'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.textContaining('kanonische Unterhaltung'), findsOneWidget);
    });
  });
}
