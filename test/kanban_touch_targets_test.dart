import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_toolbar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card_drag.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_status_chips.dart';

import 'support/pump_on_platform.dart';

const _task = KanbanTask(id: 't1', title: 'Rotate keys', status: 'todo');

KanbanBoardToolbar _toolbar({ValueChanged<String>? onQuery}) =>
    KanbanBoardToolbar(
      assignees: const ['coder'],
      tenants: const [],
      includeArchived: false,
      wide: false,
      onQueryChanged: onQuery ?? (_) {},
      onAssigneeChanged: (_) {},
      onTenantChanged: (_) {},
      onIncludeArchivedChanged: (_) {},
    );

void main() {
  group('touch targets on iOS', () {
    testWidgets('status chips and filter chips are 44 points tall', (
      tester,
    ) async {
      await pumpOnPlatform(
        tester,
        Column(
          children: [
            KanbanStatusChips(
              columns: const [
                KanbanColumn(name: 'todo', tasks: [_task]),
                KanbanColumn(name: 'done', tasks: []),
              ],
              selected: 'todo',
              onSelected: (_) {},
            ),
            _toolbar(),
          ],
        ),
        platform: TargetPlatform.iOS,
      );

      for (final finder in [
        find.byType(ChoiceChip).first,
        find.byType(FilterChip),
        find.byType(KanbanFilterMenu),
      ]) {
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('a tap just outside the drawn status chip still selects it', (
      tester,
    ) async {
      final picked = <String>[];
      await pumpOnPlatform(
        tester,
        KanbanStatusChips(
          columns: const [
            KanbanColumn(name: 'todo', tasks: [_task]),
            KanbanColumn(name: 'done', tasks: []),
          ],
          selected: 'todo',
          onSelected: picked.add,
        ),
        platform: TargetPlatform.iOS,
      );

      final chip = tester.getRect(find.byType(ChoiceChip).last);
      await tester.tapAt(Offset(chip.center.dx, chip.center.dy + 20));
      expect(picked, ['done']);
    });

    testWidgets('the drag handle is a 44 point square', (tester) async {
      await pumpOnPlatform(
        tester,
        const Align(
          alignment: Alignment.topRight,
          child: KanbanDragHandle(task: _task),
        ),
        platform: TargetPlatform.iOS,
      );

      final size = tester.getSize(find.byType(KanbanDragHandle));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('the drag handle keeps its size on Android', (tester) async {
      await pumpOnPlatform(
        tester,
        const Align(
          alignment: Alignment.topRight,
          child: KanbanDragHandle(task: _task),
        ),
        platform: TargetPlatform.android,
      );

      expect(tester.getSize(find.byType(KanbanDragHandle)), const Size(32, 32));
    });
  });
}
