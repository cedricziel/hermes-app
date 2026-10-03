import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_menu.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_toolbar.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_attachments.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/accessibility.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

void main() {
  testWidgets('the board toolbar names Refresh', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KanbanBoardToolbar(
        assignees: const [],
        tenants: const [],
        includeArchived: false,
        wide: true,
        onQueryChanged: (_) {},
        onAssigneeChanged: (_) {},
        onTenantChanged: (_) {},
        onIncludeArchivedChanged: (_) {},
        onRefresh: () {},
      ),
    );

    expect(
      tester.getSemantics(find.byIcon(Icons.refresh)),
      namedButton('Refresh'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the board menu is named Switch board', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KanbanBoardMenu(
        boards: const [KanbanBoardInfo(slug: 'ops', name: 'Ops')],
        selected: 'ops',
        onSelected: (_) {},
        onManage: () {},
      ),
    );

    expect(
      tester.getSemantics(find.byIcon(Icons.dashboard_customize_outlined)),
      namedButton('Switch board'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('each attachment can be saved and removed by its name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KanbanTaskAttachments(
        attachments: const [
          KanbanAttachment(id: 1, filename: 'notes.txt'),
          KanbanAttachment(id: 2, filename: 'plan.pdf'),
        ],
        onAttach: () {},
        onDownload: (_) {},
        onRemove: (_) {},
      ),
    );

    for (final (i, name) in ['notes.txt', 'plan.pdf'].indexed) {
      expect(
        tester.getSemantics(find.byIcon(Icons.download_outlined).at(i)),
        namedButton('Save $name'),
      );
      expect(
        tester.getSemantics(find.byIcon(Icons.close).at(i)),
        namedButton('Remove $name'),
      );
    }
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
