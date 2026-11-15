import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';

import '../support/screenshot_recorder.dart';

Future<void> _open(
  WidgetTester tester, {
  required double scale,
  required TargetPlatform platform,
  required String title,
  Locale locale = const Locale('en'),
  Size size = const Size(320, 568),
  List<Widget>? actions,
  List<Widget> children = const [Text('Row')],
  double keyboard = 0,
  bool realFonts = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: realFonts
          ? withScreenshotFont(ThemeData(platform: platform))
          : ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => GroupedDialog(
              title: title,
              actions: actions,
              children: children,
            ),
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
const _bot = 'Edit Research assistant for quarterly reports';
final _footer = <Widget>[
  TextButton(onPressed: () {}, child: const Text('Cancel')),
  FilledButton(onPressed: () {}, child: const Text('Save')),
];
const _wraps = 'Notifications, sounds and everything else you can change';

Rect _doneRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('grouped-dialog-done')));

/// The part of the title that is on screen: the text clipped to its scroll
/// view, which caps the header's height.
Rect _titleRect(WidgetTester tester, String title) {
  final text = tester.getRect(
    find.descendant(of: find.byType(GroupedDialog), matching: find.text(title)),
  );
  final viewport = tester.getRect(
    find
        .descendant(
          of: find.byType(GroupedDialog),
          matching: find.byType(SingleChildScrollView),
        )
        .first,
  );
  return text.intersect(viewport);
}

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

  var root = tester.getSemantics(find.text('Row').first);
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
        // Nothing is cut: the header grew to hold every line (or, past its
        // cap, the title scrolls; see the capped cases below).
        expect(
          tester.getRect(find.text('Row')).top - dialog.top,
          greaterThanOrEqualTo(titleRect.bottom - dialog.top),
        );
      });
    }

    // Each word fits beside Done, the whole title does not fit on one line:
    // the header stacks anyway. A rule that only looked at the longest word
    // would wrap this title off-centre beside Done.
    testWidgets('a title that wraps but whose words fit still stacks: '
        '${platform.name}', (tester) async {
      await _open(
        tester,
        scale: 1,
        platform: platform,
        title: 'Settings and more',
      );
      final done = _doneRect(tester);
      final titleRect = _titleRect(tester, 'Settings and more');
      expect(done.bottom, lessThanOrEqualTo(titleRect.top));
    });

    for (final (name, size, title, actions) in [
      ('portrait with a footer', const Size(320, 568), _bot, _footer),
      ('landscape with a footer', const Size(844, 390), _bot, _footer),
      ('portrait with Done', const Size(320, 568), _long, null),
      ('landscape with Done', const Size(844, 390), _bot, null),
    ]) {
      testWidgets('a long title at x3.1 scrolls instead of overflowing: '
          '${platform.name} $name', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(
          tester,
          scale: 3.1,
          platform: platform,
          title: title,
          size: size,
          actions: actions,
        );
        expect(tester.takeException(), isNull);
        final dialog = _dialogRect(tester);
        final rows = tester.getRect(find.text('Row'));
        // The rows are reachable: on screen, below the header, which stays
        // within its share of the window.
        expect(rows.height, greaterThan(0));
        expect(rows.bottom, lessThanOrEqualTo(size.height));
        expect(rows.top - dialog.top, lessThan(0.5 * size.height));
        expect(dialog.height, lessThanOrEqualTo(size.height));
        expect(_readingOrder(tester), contains('Row'));
        semantics.dispose();
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

  testWidgets('the heading trait is on the node that carries the title', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, scale: 1, platform: TargetPlatform.iOS, title: _short);
    final heading = tester.getSemantics(
      find.descendant(
        of: find.byType(GroupedDialog),
        matching: find.text(_short),
      ),
    );
    expect(heading.flagsCollection.isHeader, isTrue);
    expect(heading.label, _short);
    semantics.dispose();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    for (final (name, size, keyboard) in [
      ('landscape', const Size(844, 390), 209.0),
      ('portrait', const Size(320, 568), 260.0),
    ]) {
      // A landscape keyboard at x3.1 leaves 133 pt, which the fixed two-button
      // footer alone already exceeds, with or without this header; main
      // overflows there too.
      for (final scale in name == 'landscape' ? [2.0] : [2.0, 3.1]) {
        for (final (shape, title) in [
          ('Edit bot', _bot),
          ('Kanban log', 'Log · t_8f3a2c19'),
        ]) {
          testWidgets('a dialog with fields and a two-button footer fits above '
              'the keyboard: $shape ${platform.name} $name x$scale', (
            tester,
          ) async {
            final fields = [
              for (var i = 0; i < 3; i++)
                TextField(key: Key('field-$i'), decoration: null),
            ];
            // Real fonts: Ahem's footer is far taller than a phone's.
            await ScreenshotRecorder('kb').start(tester, size);
            await _open(
              tester,
              scale: scale,
              platform: platform,
              title: title,
              size: size,
              keyboard: keyboard,
              actions: _footer,
              children: fields,
              realFonts: true,
            );
            expect(tester.takeException(), isNull);
            // A landscape keyboard leaves the rows no room at all, on main
            // too (its fixed header and footer fill it): nothing to reach.
            if (name == 'landscape') return;
            // The body scrolls to the field; the keyboard room is what it has.
            await tester.ensureVisible(find.byKey(const Key('field-2')));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('field-2')).hitTestable(),
              findsOneWidget,
              reason: 'the field is reachable, not under the footer',
            );
            await tester.tap(find.byKey(const Key('field-2')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final field = tester.getRect(find.byKey(const Key('field-2')));
            expect(field.top, greaterThanOrEqualTo(0));
            expect(field.bottom, lessThanOrEqualTo(size.height - keyboard));
            expect(
              tester.getRect(find.text('Save')).bottom,
              lessThanOrEqualTo(size.height - keyboard),
            );
            // The footer is never pushed off by the header: the header keeps to
            // one line plus its padding, or less, in the tightest room.
            final dialog = _dialogRect(tester);
            expect(dialog.bottom, lessThanOrEqualTo(size.height - keyboard));
          });
        }
      }
    }
  }

  testWidgets('a title cut to one line keeps its full text in a tooltip and '
      'the label', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(
      tester,
      scale: 3.1,
      platform: TargetPlatform.iOS,
      title: _bot,
      size: const Size(320, 568),
      keyboard: 260,
      actions: _footer,
      children: [for (var i = 0; i < 6; i++) const Text('Row')],
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(GroupedDialog),
        matching: find.text(_bot),
      ),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, _bot);
    // The full title is the heading's label; the tooltip adds no second one.
    expect(tooltip.excludeFromSemantics, isTrue);
    final heading = tester.getSemantics(find.text(_bot));
    expect(heading.label, _bot);
    expect(heading.flagsCollection.isHeader, isTrue);
    semantics.dispose();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('the rows keep their scroll offset when the dialog relays out: '
        '${platform.name}', (tester) async {
      tester.view
        ..physicalSize = const Size(375, 667)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rowCount = ValueNotifier<int>(20);
      final scale = ValueNotifier<double>(1);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: platform),
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: scale,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(value)),
              child: child!,
            ),
          ),
          home: ValueListenableBuilder<int>(
            valueListenable: rowCount,
            builder: (context, count, _) => GroupedDialog(
              title: 'Edit',
              actions: [
                FilledButton(onPressed: () {}, child: const Text('Save')),
              ],
              children: [
                for (var i = 0; i < count; i++)
                  SizedBox(height: 44, child: Text('Row $i')),
              ],
            ),
          ),
        ),
      );
      ScrollPosition position() =>
          Scrollable.of(tester.element(find.text('Row 0'))).position;
      position().jumpTo(200);
      await tester.pump();
      expect(position().pixels, 200);

      rowCount.value = 22;
      await tester.pump();
      expect(position().pixels, 200, reason: 'row count changed');

      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pump();
      expect(position().pixels, 200, reason: 'keyboard shown');

      scale.value = 1.5;
      await tester.pump();
      expect(position().pixels, 200, reason: 'text scale changed');
      tester.view.resetViewInsets();
    });

    testWidgets('a title without Done keeps the same padding on both sides: '
        '${platform.name}', (tester) async {
      await _open(
        tester,
        scale: 1,
        platform: platform,
        title: _wraps,
        actions: _footer,
      );
      final dialog = _dialogRect(tester);
      final titleRect = _titleRect(tester, _wraps);
      expect(titleRect.left - dialog.left, greaterThanOrEqualTo(15.5));
      expect(dialog.right - titleRect.right, greaterThanOrEqualTo(15.5));
    });
  }
}
