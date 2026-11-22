import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_orchestration_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';
import 'host.dart';
import 'kanban_screen_use_cases.dart';

/// The four Kanban dialogs with their own actions, opened by the functions the
/// screens call, so the route (barrier, Esc, motion) is the one that ships.
WidgetbookNode kanbanDialogsNode() => WidgetbookFolder(
  name: 'Kanban dialogs',
  children: [
    WidgetbookComponent(
      name: 'Board export',
      useCases: onEachPlatform(
        'Open',
        (_) => openOnShow(
          (context) => showKanbanExportDialog(context, name: 'Ops'),
        ),
      ),
    ),
    WidgetbookComponent(
      name: 'Board import',
      useCases: onEachPlatform(
        'Open',
        (_) => openOnShow(showKanbanImportDialog),
      ),
    ),
    WidgetbookComponent(
      name: 'Edit task',
      useCases: onEachPlatform(
        'Open',
        (_) => openOnShow(
          (context) => showKanbanTaskEditDialog(context, busyTask),
        ),
      ),
    ),
    WidgetbookComponent(
      name: 'Orchestration',
      useCases: onEachPlatform(
        'Open',
        (_) => openOnShow(
          (context) => showKanbanOrchestrationDialog(
            context,
            repository: KanbanRepository(
              // Named profiles: the "Active profile (...)" label does not fit
              // beside its title in a 310 pt Mac dialog (a shared row's limit,
              // not this change's).
              (kanbanServer()..on('GET', '/api/plugins/kanban/orchestration', {
                    'orchestrator_profile': 'lead',
                    'default_assignee': 'coder',
                    'auto_decompose': false,
                    'auto_promote_children': true,
                    'active_profile': 'default',
                  }))
                  .client(),
            ),
          ),
        ),
      ),
    ),
  ],
);
