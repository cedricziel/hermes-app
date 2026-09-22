import 'package:flutter/material.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_actions.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_attachments.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_channels.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_comments.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_fields.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_header.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_runs.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookUseCase _use(String name, Widget widget) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(widget, maxWidth: 560));

const _triageTask = KanbanTask(
  id: 't_7a8b9c',
  title: 'Plan the offline mode',
  status: 'triage',
);

const _doneTask = KanbanTask(
  id: 't_0d1e2f',
  title: 'Bump dependencies',
  status: 'done',
  result: 'All packages on their latest minor version.',
);

final _earlier = DateTime.now().subtract(const Duration(hours: 3));

final _fullDetail = KanbanTaskDetail(
  task: const KanbanTask(
    id: 't_4d5e6f',
    title: 'Migrate the settings screen to the new layout',
    status: 'running',
    body: 'Move every section into the new two-pane layout.',
    latestSummary: 'Two of five sections moved.',
  ),
  parents: const ['t_1a2b3c'],
  childResults: const [
    KanbanChildResult(
      id: 't_9f8e7d',
      title: 'Move the account section',
      status: 'done',
      summary: 'Done, with tests.',
    ),
  ],
  diagnostics: const [
    KanbanDiagnostic(
      title: 'Worker has not reported in a while',
      severity: 'warning',
      detail: 'No heartbeat for 12 minutes.',
    ),
    KanbanDiagnostic(title: 'Failed twice', severity: 'error'),
  ],
);

KanbanTaskActions _actions(
  KanbanTask task, {
  KanbanEstimate? estimate,
  bool estimating = false,
}) => KanbanTaskActions(
  task: task,
  estimate: estimate,
  estimating: estimating,
  onDecompose: () {},
  onSpecify: () {},
  onReclaim: () {},
  onComplete: () {},
  onBlock: () {},
  onEstimate: () {},
);

KanbanTaskRuns _runs(List<KanbanRun> runs, List<KanbanEvent> events) =>
    KanbanTaskRuns(
      runs: runs,
      events: events,
      taskRunning: true,
      onTerminate: (_) {},
      onShowLog: () {},
    );

List<WidgetbookComponent> kanbanTaskComponents() => [
  WidgetbookComponent(
    name: 'KanbanTaskHeader',
    useCases: [
      for (final (name, task) in [('Plain', plainTask), ('Busy', busyTask)])
        _use(
          name,
          KanbanTaskHeader(
            task: task,
            onEdit: () {},
            onAssign: () {},
            onPrioritise: () {},
            onMove: (_) {},
          ),
        ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskActions',
    useCases: [
      _use('Triage', _actions(_triageTask)),
      _use('Running', _actions(busyTask)),
      _use('Done', _actions(_doneTask)),
      _use('Estimating', _actions(plainTask, estimating: true)),
      _use(
        'Estimated',
        _actions(
          plainTask,
          estimate: const KanbanEstimate(
            ok: true,
            tokens: 12000,
            complexity: 'M',
            rationale: 'Touches three screens and their tests.',
          ),
        ),
      ),
      _use(
        'No estimate',
        _actions(
          plainTask,
          estimate: const KanbanEstimate(
            ok: false,
            reason: 'No model is set up for estimates.',
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskFooter',
    useCases: [
      _use('Default', KanbanTaskFooter(onArchive: () {}, onDelete: () {})),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskFields',
    useCases: [
      _use(
        'Bare',
        KanbanTaskFields(
          detail: const KanbanTaskDetail(task: plainTask),
          onAddParent: () {},
          onRemoveParent: (_) {},
        ),
      ),
      _use(
        'Full',
        KanbanTaskFields(
          detail: _fullDetail,
          onAddParent: () {},
          onRemoveParent: (_) {},
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskComments',
    useCases: [
      _use(
        'None',
        KanbanTaskComments(comments: const [], onSend: (_) async => true),
      ),
      _use(
        'Some',
        KanbanTaskComments(
          comments: [
            KanbanComment(
              author: 'researcher',
              body: 'The account section is done.',
              createdAt: _earlier,
            ),
            const KanbanComment(author: 'you', body: 'Looks good so far.'),
          ],
          onSend: (_) =>
              Future.delayed(const Duration(milliseconds: 400), () => true),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskChannels',
    useCases: [
      for (final (name, switching) in [
        ('Channels', const <String>{}),
        ('Switching', const {'telegram'}),
      ])
        _use(
          name,
          KanbanTaskChannels(
            channels: const [
              KanbanHomeChannel(platform: 'telegram', name: 'Team chat'),
              KanbanHomeChannel(
                platform: 'slack',
                name: '#builds',
                subscribed: true,
              ),
            ],
            switching: switching,
            onToggle: (_, _) {},
          ),
        ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskAttachments',
    useCases: [
      for (final (name, attachments, transferring) in [
        ('None', const <KanbanAttachment>[], false),
        (
          'Some',
          const [
            KanbanAttachment(id: 1, filename: 'layout.png', size: 245760),
            KanbanAttachment(id: 2, filename: 'notes.txt', size: 812),
          ],
          false,
        ),
        (
          'Transferring',
          const [KanbanAttachment(id: 1, filename: 'layout.png', size: 245760)],
          true,
        ),
      ])
        _use(
          name,
          KanbanTaskAttachments(
            attachments: attachments,
            transferring: transferring,
            onAttach: () {},
            onDownload: (_) {},
            onRemove: (_) {},
          ),
        ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskRuns',
    useCases: [
      _use('Nothing yet', _runs(const [], const [])),
      _use(
        'Runs and history',
        _runs(
          [
            KanbanRun(
              id: 3,
              status: 'done',
              profile: 'researcher',
              outcome: 'completed',
              summary: 'Moved the account section.',
              startedAt: _earlier,
              endedAt: _earlier,
            ),
            KanbanRun(
              id: 4,
              status: 'running',
              profile: 'researcher',
              startedAt: _earlier,
            ),
          ],
          [
            KanbanEvent(kind: 'status_changed', createdAt: _earlier),
            const KanbanEvent(kind: 'claimed'),
          ],
        ),
      ),
    ],
  ),
];
