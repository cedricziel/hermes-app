import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/swipeable_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/touch_row_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';

/// A German device gets German words on a chat row everywhere: the phone's
/// action sheet, the swipe actions, VoiceOver's custom actions and the
/// iPad popover.
void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    required Size size,
    bool canonical = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: SwipeableThreadRow(
            title: 'Release notes',
            pinned: false,
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

  testWidgets('the iPad popover is German', (tester) async {
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
}
