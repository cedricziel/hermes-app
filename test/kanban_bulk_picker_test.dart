import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_bulk_bar.dart';
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

/// A choice group that holds no value: no row is checked.
final _emptyGroup = find.byWidgetPredicate(
  (widget) => widget is RadioGroup && (widget as dynamic).groupValue == null,
);

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
          await _open(tester, platform, _Calls(), action);

          expect(_dialog, findsOneWidget);
          expect(find.byType(SimpleDialog), findsNothing);
          expect(find.text(row), findsOneWidget);
          expect(_emptyGroup, findsOneWidget);
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

      if (platform != TargetPlatform.android) {
        testWidgets('Done closes it and applies nothing', (tester) async {
          final calls = _Calls();
          // Priority, since Move has a row of its own named Done.
          await _open(tester, platform, calls, 'Priority');

          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();

          expect(_dialog, findsNothing);
          expect(calls.log, isEmpty);
        });
      }

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
