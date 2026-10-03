import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_bulk_bar.dart';

import 'support/pump_on_platform.dart';

KanbanBulkBar _bar({int selected = 2}) => KanbanBulkBar(
  selectedCount: selected,
  assignees: const ['coder'],
  onMove: (_) {},
  onAssign: (_) {},
  onPriority: (_) {},
  onEffort: (_) {},
  onArchive: () {},
);

void main() {
  group('bulk bar', () {
    testWidgets('is a 44 point toolbar above the home indicator on iOS', (
      tester,
    ) async {
      await pumpOnPlatform(
        tester,
        const SizedBox.shrink(),
        platform: TargetPlatform.iOS,
        bottom: _bar(),
        padding: const EdgeInsets.only(bottom: 34),
      );

      final bar = tester.getRect(find.byType(KanbanBulkBar));
      expect(bar.bottom, 852);
      expect(bar.height, 44 + 34);
      for (final label in ['Move', 'Assign', 'Priority', 'Effort', 'Archive']) {
        final button = tester.getRect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(CupertinoButton),
          ),
        );
        expect(button.height, greaterThanOrEqualTo(44));
        expect(button.bottom, lessThanOrEqualTo(852 - 34));
      }
    });

    testWidgets('keeps the Material bottom app bar on Android', (tester) async {
      await pumpOnPlatform(
        tester,
        const SizedBox.shrink(),
        platform: TargetPlatform.android,
        bottom: _bar(),
      );

      expect(find.byType(BottomAppBar), findsOneWidget);
      expect(find.byType(CupertinoButton), findsNothing);
      expect(tester.getSize(find.byType(BottomAppBar)).height, 80);
    });

    testWidgets('offers no action while nothing is selected', (tester) async {
      await pumpOnPlatform(
        tester,
        const SizedBox.shrink(),
        platform: TargetPlatform.iOS,
        bottom: _bar(selected: 0),
      );

      final move = tester.widget<CupertinoButton>(
        find.ancestor(
          of: find.text('Move'),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(move.onPressed, isNull);
    });
  });
}
