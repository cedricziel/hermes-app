import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';

import '../support/legacy_grouped_dialog.dart';
import '../support/screenshot_recorder.dart';

/// The rule for the dialog header, swept over phones, keyboards and text
/// scales and checked against main's real dialog (`LegacyGroupedDialog`,
/// frozen in `test/support`) rendered in the same cell with the same content:
///
///  - the rows get at least the height they get on main, except where main's
///    fixed bar cut Done: there Done is kept whole and the rows lose exactly
///    that much;
///  - nothing overflows, Done is whole and reachable, the title is not painted
///    over the rows, and the full title is the heading's semantics label.
///
/// Text is drawn with the real Roboto, so the cells are the ones a phone sees.
const _long = 'Edit Research assistant for quarterly reports';
const _short = 'Set';

final _widths = [320.0, 360.0, 390.0, 430.0];
final _heights = [568.0, 667.0, 740.0, 844.0, 932.0];
const _keyboards = [0.0, 0.35, 0.45];
const _scales = [1.0, 1.3, 1.6, 2.0, 2.4, 2.8, 3.1];
const _rowCounts = [1, 6, 12];

class _Cell {
  _Cell(
    this.platform,
    this.size,
    this.keyboard,
    this.scale,
    this.title,
    this.footer,
    this.rows,
  );

  final TargetPlatform platform;
  final Size size;
  final double keyboard;
  final double scale;
  final String title;
  final bool footer;
  final int rows;

  @override
  String toString() =>
      '${platform.name} ${size.width.toInt()}x${size.height.toInt()} '
      'kb${keyboard.toInt()} x$scale ${title == _short ? 'short' : 'long'} '
      '${footer ? 'footer' : 'done'} rows$rows';
}

Widget _app(_Cell cell, {required bool legacy}) {
  final actions = cell.footer
      ? [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          FilledButton(onPressed: () {}, child: const Text('Save')),
        ]
      : null;
  final children = [
    for (var i = 0; i < cell.rows; i++)
      const SizedBox(height: 44, child: Center(child: Text('Row'))),
  ];
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: withScreenshotFont(
      buildHermesLightTheme().copyWith(platform: cell.platform),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(cell.scale)),
      child: child!,
    ),
    home: legacy
        ? LegacyGroupedDialog(
            title: cell.title,
            actions: actions,
            children: children,
          )
        : GroupedDialog(
            title: cell.title,
            actions: actions,
            children: children,
          ),
  );
}

Rect _rows(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.text('Row').first,
        matching: find.byType(SingleChildScrollView),
      )
      .first,
);

/// Renders [cell] and returns the rows' height, or null with the problem
/// recorded when the render threw.
Future<({double? rows, Object? error, double? done})> _measure(
  WidgetTester tester,
  _Cell cell, {
  required bool legacy,
}) async {
  tester.view
    ..physicalSize = cell.size
    ..devicePixelRatio = 1
    ..viewInsets = FakeViewPadding(bottom: cell.keyboard);
  await tester.pumpWidget(_app(cell, legacy: legacy));
  final error = tester.takeException();
  if (error != null) return (rows: null, error: error, done: null);
  final done = find.text('Done');
  return (
    rows: _rows(tester).height,
    error: null,
    done: done.evaluate().isEmpty
        ? null
        : tester.getSize(find.byType(TextButton)).height,
  );
}

void main() {
  var cells = 0;
  var doneExceptions = 0;
  var legacyOverflows = 0;
  var rowsLost = 0;
  var doneMin = double.infinity;
  var doneMax = 0.0;
  var lostMax = 0.0;

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    for (final width in _widths) {
      testWidgets(
        'rows keep main\'s height: ${platform.name} ${width.toInt()}',
        (tester) async {
          // Loads Roboto for the whole test.
          await ScreenshotRecorder('sweep').start(tester, Size(width, 568));
          WidgetController.hitTestWarningShouldBeFatal = false;
          final minBar = platform == TargetPlatform.iOS ? 52.0 : 44.0;
          final problems = <String>[];

          for (final height in _heights) {
            for (final keyboardShare in _keyboards) {
              for (final scale in _scales) {
                for (final title in [_short, _long]) {
                  for (final footer in [false, true]) {
                    for (final rows in _rowCounts) {
                      final cell = _Cell(
                        platform,
                        Size(width, height),
                        (keyboardShare * height).roundToDouble(),
                        scale,
                        title,
                        footer,
                        rows,
                      );
                      cells++;
                      final main = await _measure(tester, cell, legacy: true);
                      if (main.error != null) legacyOverflows++;
                      final ours = await _measure(tester, cell, legacy: false);
                      if (ours.error != null) {
                        problems.add('$cell: threw ${ours.error}');
                        continue;
                      }
                      // Done is whole: its bar is at least Done's own height.
                      final doneHeight = ours.done;
                      final bar = doneHeight == null
                          ? minBar
                          : (doneHeight > minBar ? doneHeight : minBar);
                      final lost = bar - minBar;
                      if (lost > 0.01) {
                        doneExceptions++;
                        doneMin = math.min(doneMin, doneHeight!);
                        doneMax = math.max(doneMax, doneHeight);
                      }
                      if (main.rows != null && ours.rows! < main.rows! - 0.5) {
                        rowsLost++;
                        lostMax = math.max(lostMax, main.rows! - ours.rows!);
                      }
                      if (main.rows != null &&
                          ours.rows! < main.rows! - lost - 0.5) {
                        problems.add(
                          '$cell: rows ${ours.rows} < main ${main.rows} - $lost',
                        );
                      }

                      final dialogFinder = find.byType(GroupedDialog);
                      final bodyTop = _rows(tester).top;
                      final dialogTop = tester
                          .getRect(
                            find
                                .descendant(
                                  of: dialogFinder,
                                  matching: find.byType(Material),
                                )
                                .first,
                          )
                          .top;
                      if (doneHeight != null) {
                        final done = find.byKey(
                          const Key('grouped-dialog-done'),
                        );
                        final rect = tester.getRect(done);
                        if (done.hitTestable().evaluate().isEmpty) {
                          problems.add('$cell: Done not hit-testable');
                        }
                        if (rect.top < dialogTop - 0.5 ||
                            rect.bottom > bodyTop + 0.5) {
                          problems.add('$cell: Done outside the header');
                        }
                      }
                      // A title that wraps or scrolls lives in a scroll view
                      // inside the header; it must not reach into the rows.
                      final tip = find.byType(Tooltip);
                      if (tip.evaluate().isEmpty) {
                        final box = tester.getRect(
                          find
                              .descendant(
                                of: dialogFinder,
                                matching: find.byType(SingleChildScrollView),
                              )
                              .first,
                        );
                        if (box.bottom > bodyTop + 0.5 ||
                            box.top < dialogTop - 0.5) {
                          problems.add('$cell: title box outside the header');
                        }
                      }
                      // The header node itself carries the full title.
                      final handle = tester.ensureSemantics();
                      final heading = tester.getSemantics(
                        find.descendant(
                          of: dialogFinder,
                          matching: find.text(cell.title),
                        ),
                      );
                      if (!heading.flagsCollection.isHeader ||
                          heading.label != cell.title) {
                        problems.add(
                          '$cell: heading label "${heading.label}" '
                          '(header: ${heading.flagsCollection.isHeader})',
                        );
                      }
                      handle.dispose();
                    }
                  }
                }
              }
            }
          }
          expect(problems.take(40).join('\n'), isEmpty);
        },
        timeout: const Timeout(Duration(minutes: 30)),
      );
    }
  }

  tearDownAll(() {
    // ignore: avoid_print
    print(
      'SWEEP cells=$cells doneExceptions=$doneExceptions '
      'mainOverflows=$legacyOverflows rowsLost=$rowsLost lostMax=$lostMax '
      'doneTallerThanBar: min=$doneMin max=$doneMax',
    );
  });
}
