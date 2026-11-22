import 'dart:ui' show CheckedState, SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_bulk_bar.dart';
import 'package:hermes_app/src/widgets/grouped_choice_row.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';

import 'support/pump_on_platform.dart';

/// What the bar reported, in order, as `action:value`.
class _Calls {
  final List<String> log = [];
}

KanbanBulkBar _bar(_Calls calls, {int selected = 3}) => KanbanBulkBar(
  selectedCount: selected,
  assignees: const ['coder'],
  onMove: (v) => calls.log.add('move:$v'),
  onAssign: (v) => calls.log.add('assign:$v'),
  onPriority: (v) => calls.log.add('priority:$v'),
  onEffort: (v) => calls.log.add('effort:$v'),
  onArchive: () => calls.log.add('archive'),
);

Future<void> _open(
  WidgetTester tester,
  TargetPlatform platform,
  _Calls calls,
  String action, {
  int selected = 3,
}) async {
  await pumpOnPlatform(
    tester,
    const SizedBox.shrink(),
    platform: platform,
    bottom: _bar(calls, selected: selected),
  );
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

final _dialog = find.byType(GroupedDialog);

final _rows = find.byWidgetPredicate((widget) => widget is GroupedChoiceRow);

/// Every row is an unchecked member of a mutually exclusive group you can tap.
void _expectNoRowChecked(WidgetTester tester) {
  final count = _rows.evaluate().length;
  expect(count, greaterThan(1));
  for (var i = 0; i < count; i++) {
    final data = tester.getSemantics(_rows.at(i)).getSemanticsData();
    // CheckedState.isFalse: it has a checked state, and it is off.
    expect(
      data.flagsCollection.isChecked,
      CheckedState.isFalse,
      reason: 'row $i',
    );
    expect(
      data.flagsCollection.isInMutuallyExclusiveGroup,
      isTrue,
      reason: 'row $i',
    );
    expect(data.hasAction(SemanticsAction.tap), isTrue, reason: 'row $i');
  }
}

/// Action, the row to pick and what the bar must then report.
const _picks = [
  ('Move', 'Review', 'move:review'),
  ('Assign', 'coder', 'assign:coder'),
  ('Priority', 'P2', 'priority:2'),
  ('Effort', 'Profile default', 'effort:'),
];

const _platforms = {
  'iOS': TargetPlatform.iOS,
  'macOS': TargetPlatform.macOS,
  'Android': TargetPlatform.android,
};

void main() {
  for (final MapEntry(key: name, value: platform) in _platforms.entries) {
    group('bulk picker on $name', () {
      for (final (action, row, reported) in _picks) {
        testWidgets('$action opens a grouped dialog with no row checked', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await _open(tester, platform, _Calls(), action);

          expect(_dialog, findsOneWidget);
          expect(find.byType(SimpleDialog), findsNothing);
          expect(find.text(row), findsOneWidget);
          _expectNoRowChecked(tester);
          semantics.dispose();
        });

        testWidgets('$action applies the pick once and closes', (tester) async {
          final calls = _Calls();
          await _open(tester, platform, calls, action);

          await tester.tap(find.text(row));
          await tester.pumpAndSettle();

          expect(calls.log, [reported]);
          expect(_dialog, findsNothing);
        });
      }

      testWidgets('names the scope for three tasks', (tester) async {
        await _open(tester, platform, _Calls(), 'Priority');
        expect(find.text('Applies to the 3 selected tasks.'), findsOneWidget);
      });

      testWidgets('names the scope for one task', (tester) async {
        await _open(tester, platform, _Calls(), 'Priority', selected: 1);
        expect(find.text('Applies to the selected task.'), findsOneWidget);
      });

      testWidgets('Cancel closes it and applies nothing', (tester) async {
        final calls = _Calls();
        await _open(tester, platform, calls, 'Move');

        expect(find.text('Done'), findsOneWidget, reason: 'only the status');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(_dialog, findsNothing);
        expect(calls.log, isEmpty);
      });

      if (platform == TargetPlatform.iOS) {
        testWidgets('a barrier tap leaves it open, Esc closes it', (
          tester,
        ) async {
          final calls = _Calls();
          await _open(tester, platform, calls, 'Move');

          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
          expect(_dialog, findsOneWidget);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(_dialog, findsNothing);
          expect(calls.log, isEmpty);
        });
      } else {
        testWidgets('a barrier click closes it and applies nothing', (
          tester,
        ) async {
          final calls = _Calls();
          await _open(tester, platform, calls, 'Move');

          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();

          expect(_dialog, findsNothing);
          expect(calls.log, isEmpty);
        });
      }

      if (platform == TargetPlatform.macOS) {
        testWidgets('Esc closes it and applies nothing', (tester) async {
          final calls = _Calls();
          await _open(tester, platform, calls, 'Move');

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();

          expect(_dialog, findsNothing);
          expect(calls.log, isEmpty);
        });
      }
    });
  }
}
