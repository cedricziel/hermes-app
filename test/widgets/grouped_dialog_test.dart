import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';

Future<void> _open(
  WidgetTester tester, {
  required double scale,
  required TargetPlatform platform,
  required String title,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    // Ahem is so wide that the long title takes six lines at x3.1, taller
    // than a 568 pt window; a real font takes about three (see the
    // screenshots in the PR).
    ..physicalSize = Size(320, scale > 3 ? 900 : 568)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                GroupedDialog(title: title, children: const [Text('Row')]),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

// The test font (Ahem) is a full-em square, much wider than a real font, so
// "Appearance and display" is already too wide for one line beside Done at
// x1.0 here. Cases that need the one-line layout use a short title.
const _short = 'Set';
const _long = 'Appearance and display';
const _wraps = 'Notifications, sounds and everything else you can change';

Rect _doneRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('grouped-dialog-done')));

Rect _titleRect(WidgetTester tester, String title) => tester.getRect(
  find.descendant(of: find.byType(GroupedDialog), matching: find.text(title)),
);

Rect _dialogRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byType(GroupedDialog),
        matching: find.byType(Material),
      )
      .first,
);

/// The labels of the dialog's semantics in the order a screen reader
/// visits them.
List<String> _readingOrder(WidgetTester tester) {
  final labels = <String>[];
  void walk(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      walk(child);
    }
  }

  var root = tester.getSemantics(find.text('Row'));
  while (root.parent != null) {
    root = root.parent!;
  }
  walk(root);
  return labels;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    final ios = platform == TargetPlatform.iOS;
    final minHeader = ios ? 52.0 : 44.0;
    for (final scale in [1.0, 2.0, 3.1]) {
      for (final title in [_short, _long]) {
        testWidgets('title stays clear of Done: ${platform.name} x$scale '
            '"$title"', (tester) async {
          await _open(tester, scale: scale, platform: platform, title: title);
          expect(tester.takeException(), isNull);

          final done = _doneRect(tester);
          final titleRect = _titleRect(tester, title);
          final dialog = _dialogRect(tester);
          expect(titleRect.overlaps(done), isFalse);
          expect(done.right, lessThanOrEqualTo(dialog.right));
          expect(titleRect.left, greaterThanOrEqualTo(dialog.left));
          expect(titleRect.right, lessThanOrEqualTo(dialog.right));
          // The rows start below the header, which is never shorter than at
          // rest and never cuts the title.
          final rows = tester.getRect(find.text('Row'));
          expect(rows.top - dialog.top, greaterThanOrEqualTo(minHeader));
          expect(titleRect.bottom, lessThanOrEqualTo(rows.top));
        });

        testWidgets('screen readers get title, Done, rows: ${platform.name} '
            'x$scale "$title"', (tester) async {
          final semantics = tester.ensureSemantics();
          await _open(tester, scale: scale, platform: platform, title: title);
          final order = _readingOrder(tester);
          final titleAt = order.lastIndexOf(title);
          final doneAt = order.indexOf('Done');
          final rowAt = order.indexOf('Row');
          expect([titleAt, doneAt, rowAt], everyElement(greaterThan(-1)));
          expect(titleAt, lessThan(doneAt));
          expect(doneAt, lessThan(rowAt));
          semantics.dispose();
        });
      }
    }

    testWidgets('a title that fits stays on one line beside Done, centred: '
        '${platform.name}', (tester) async {
      await _open(tester, scale: 1, platform: platform, title: _short);
      final done = _doneRect(tester);
      final titleRect = _titleRect(tester, _short);
      final dialog = _dialogRect(tester);
      expect(titleRect.center.dy, closeTo(done.center.dy, 0.5));
      expect(titleRect.center.dx, closeTo(dialog.center.dx, 0.5));
      expect(tester.getRect(find.text('Row')).top - dialog.top, minHeader);
    });

    for (final (scale, title) in [(2.0, _long), (3.1, _long), (1.0, _wraps)]) {
      testWidgets('Done takes its own row, the title wraps under it: '
          '${platform.name} x$scale', (tester) async {
        await _open(tester, scale: scale, platform: platform, title: title);
        final done = _doneRect(tester);
        final titleRect = _titleRect(tester, title);
        final dialog = _dialogRect(tester);
        expect(done.bottom, lessThanOrEqualTo(titleRect.top));
        expect(done.right, closeTo(dialog.right - (ios ? 4 : 8), 0.5));
        expect(titleRect.center.dx, closeTo(dialog.center.dx, 0.5));
        // Done's row is at least a tap target tall.
        expect(titleRect.top - dialog.top, greaterThanOrEqualTo(44));
        // Nothing is cut: the header grew to hold every line.
        expect(
          tester.getRect(find.text('Row')).top - dialog.top,
          greaterThanOrEqualTo(titleRect.bottom - dialog.top),
        );
      });
    }
  }

  testWidgets('Material chrome has no overflow at the largest text', (
    tester,
  ) async {
    for (final scale in [2.0, 3.1]) {
      await _open(
        tester,
        scale: scale,
        platform: TargetPlatform.android,
        title: 'Appearance and display',
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('grouped-dialog-done')), findsNothing);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the header is as tall as before at the default scale', (
    tester,
  ) async {
    await _open(tester, scale: 1, platform: TargetPlatform.iOS, title: 'Prefs');
    final done = tester.getRect(find.byKey(const Key('grouped-dialog-done')));
    final row = tester.getRect(find.text('Row'));
    // Done sits in the middle of the 52 pt bar, and the rows follow it.
    expect(row.top - done.center.dy, 26);
  });

  testWidgets('Done is localized and closes the dialog', (tester) async {
    await _open(
      tester,
      scale: 1,
      platform: TargetPlatform.iOS,
      title: 'Titel',
      locale: const Locale('de'),
    );
    expect(find.text('Fertig'), findsOneWidget);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupedDialog), findsNothing);
  });

  testWidgets('the title mirrors to the start side in right to left', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const GroupedDialog(title: 'Titel', children: [Text('Row')]),
      ),
    );
    final done = tester.getRect(find.byKey(const Key('grouped-dialog-done')));
    final dialog = tester.getRect(find.byType(GroupedDialog));
    expect(done.left - dialog.left, lessThan(30));
  });
}
