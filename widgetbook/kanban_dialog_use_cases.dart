import 'package:flutter/material.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_orchestration_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_edit_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_text_dialog.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';
import 'host.dart';
import 'kanban_screen_use_cases.dart';

/// A text dialog over an empty page, opened once shown, the way
/// `askKanbanText` opens it.
Widget _text({String? hint, String? initial, bool multiline = false}) =>
    openOnShow(
      (context) => showAppDialog<String>(
        context: context,
        builder: (_) => KanbanTextDialog(
          title: 'Rename board',
          hint: hint,
          initial: initial,
          confirm: 'Rename',
          multiline: multiline,
        ),
      ),
    );

/// The task edit dialog over an empty page, opened once shown.
Widget _editTask(KanbanTask task) => openOnShow(
  (context) => showKanbanDialog<(String, String)>(
    context,
    textEntry: true,
    builder: (_) => KanbanTaskEditDialog(task: task),
  ),
);

const _describedTask = KanbanTask(
  id: 't_1a2b3c',
  title: 'Write the release notes',
  status: 'todo',
  body: 'Cover the new board filters and the keyboard shortcuts.',
);

const _bareTask = KanbanTask(
  id: 't_7d8e9f',
  title: 'Tidy the backlog',
  status: 'todo',
);

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
      name: 'KanbanTextDialog',
      useCases: [
        ...onEachPlatform('Empty', (_) => _text()),
        ...onEachPlatform('Prefilled', (_) => _text(initial: 'Ops')),
        ...onEachPlatform(
          'Multiline',
          (_) => _text(
            multiline: true,
            initial: 'The run stalled\nafter the second step.',
          ),
        ),
        ...onEachPlatform('With a hint', (_) => _text(hint: 'Board name')),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanTaskEditDialog',
      useCases: [
        ...onEachPlatform(
          'With a description',
          (_) => _editTask(_describedTask),
        ),
        ...onEachPlatform('Without a description', (_) => _editTask(_bareTask)),
      ],
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
