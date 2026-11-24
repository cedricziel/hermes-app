import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/kanban/kanban_files.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_list_rows.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_log_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_sheet.dart';
import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/adaptive_sheet.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';
import 'package:hermes_app/src/plugins/install_report.dart';
import 'package:hermes_app/src/plugins/plugin_install_result.dart';
import 'package:hermes_app/src/skills/hub_skill_screen.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:hermes_app/src/profiles/widgets/new_profile_dialog.dart';

import '../test/support/fake_hermes_server.dart';
import 'frame.dart';
import 'fixtures.dart';
import 'host.dart';
import 'kanban_screen_use_cases.dart';
import 'platform_theme.dart';
import 'press_when_ready.dart';
import 'skills_messaging_use_cases.dart';

WidgetbookUseCase _open(
  String name,
  Future<void> Function(BuildContext context) open,
) => WidgetbookUseCase(name: name, builder: (_) => openOnShow(open));

WidgetbookUseCase _report(String name, PluginInstallResult result) =>
    _open(name, (context) => reportInstall(context, result));

/// The Material dialog or sheet whatever the viewport's platform is, since the
/// shared edge and surface belong to Material; Apple alerts keep the system
/// look.
WidgetbookUseCase _material(
  String name,
  Future<void> Function(BuildContext context) open,
) => WidgetbookUseCase(
  name: name,
  builder: (context) => Theme(
    data: platformTheme(context, TargetPlatform.android),
    child: Builder(builder: (context) => openOnShow(open)),
  ),
);

const _surfaceModels = ModelOptions(
  current: ModelChoice('acme', 'atlas-1'),
  providers: [
    ModelProviderOption(
      id: 'acme',
      label: 'Acme',
      models: [
        ModelOption(id: 'atlas-1', canDisableReasoning: true),
        ModelOption(id: 'atlas-mini'),
      ],
    ),
  ],
);

class _NoFiles implements KanbanFiles {
  @override
  Future<KanbanPickedFile?> pick() async => null;

  @override
  Future<bool> save(String name, Uint8List bytes) async => true;
}

/// [build] under the Mac look, whatever the viewport's platform is, for the
/// dialogs that `showAppDialog` draws as a fading, click-dismissible window
/// there.
WidgetbookUseCase _mac(String name, Widget Function(BuildContext) build) =>
    WidgetbookUseCase(
      name: name,
      builder: (context) => Theme(
        data: platformTheme(context, TargetPlatform.macOS),
        child: Builder(builder: build),
      ),
    );

/// The callback of the first widget of type [T] under the screen, once it
/// has loaded, for [PressWhenReady].
VoidCallback? Function(Element) _callbackOf<T extends Widget>(
  VoidCallback? Function(T widget) callback,
) => (root) {
  final element = findElement(root, (e) => e.widget is T);
  return element == null ? null : callback(element.widget as T);
};

const _hubSkill = HubSkill(
  name: 'web-scraper',
  identifier: 'github/web-scraper',
  description: 'Scrape pages into markdown.',
  source: 'github',
  tags: ['web'],
);

FakeHermesServer _askingHub() => skillsServer()
  ..on(
    'GET',
    '/api/skills/hub/scan',
    hubScanBody(
      policy: 'ask',
      verdict: 'caution',
      summary: '2 findings',
      reason: 'Community skills with findings need your confirmation.',
      findings: [
        hubFindingRow(),
        hubFindingRow(
          severity: 'medium',
          description: 'Reads environment variables',
          file: 'scripts/env.py',
          line: 4,
        ),
      ],
      counts: const {'critical': 0, 'high': 1, 'medium': 1, 'low': 0},
    ),
  );

WidgetbookNode dialogsNode() => WidgetbookFolder(
  name: 'Dialogs and sheets',
  children: [
    // The edge and surface of every Material dialog and sheet come from the
    // theme. Switch to Dark and look at the boundary against the scrim.
    WidgetbookComponent(
      name: 'Overlay surface',
      useCases: [
        _material(
          'Confirm dialog',
          (context) => showConfirmDialog(
            context,
            title: 'Restart the gateway?',
            message: 'Running chats stop and reconnect.',
            confirmLabel: 'Restart',
          ),
        ),
        _material(
          'Text field dialog',
          (context) => showAppDialog<void>(
            context: context,
            builder: (dialog) => AppAlertDialog(
              title: const Text('New board'),
              content: AppDialogTextField(
                controller: TextEditingController(),
                hint: 'Name',
              ),
              actions: [
                AppDialogAction(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Cancel'),
                ),
                AppDialogAction(
                  isDefault: true,
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
        ),
        _material(
          'Model picker',
          (context) => showModelPicker(
            context,
            options: _surfaceModels,
            selected: const ModelChoice('acme', 'atlas-1', effort: 'medium'),
            onChanged: (_) {},
          ),
        ),
        _material(
          'Date picker',
          (context) => showDatePicker(
            context: context,
            initialDate: DateTime(2030, 5, 14),
            firstDate: DateTime(2030),
            lastDate: DateTime(2031),
          ),
        ),
        _material(
          'Kanban phone sheet (through its route)',
          (context) => showKanbanDetentSheet(
            context,
            (controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: const [Text('Row one'), Text('Row two')],
            ),
          ),
        ),
        _material(
          'Adaptive sheet',
          (context) => showAdaptiveSheet<void>(
            context,
            builder: (_) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'A sheet with a question and nothing else around it.',
              ),
            ),
          ),
        ),
      ],
    ),
    // The message of an alert is centred on Apple platforms and start-aligned
    // on Material.
    WidgetbookComponent(
      name: 'AppAlertDialog',
      useCases: [
        ...onEachPlatform(
          'Message',
          (_) => frame(
            AppAlertDialog(
              title: const Text('Restart the gateway?'),
              content: const Text(
                'Running chats stop and reconnect. This can take a moment.',
              ),
              actions: [
                AppDialogAction(onPressed: () {}, child: const Text('Cancel')),
                AppDialogAction(
                  isDefault: true,
                  onPressed: () {},
                  child: const Text('Restart'),
                ),
              ],
            ),
          ),
        ),
        ...onEachPlatform(
          'Message and data block',
          (_) => frame(
            AppAlertDialog(
              title: const Text('Install web-scraper?'),
              // A data alert keeps all its content on the start edge, as the
              // Kanban export alert and the skill install confirmation do.
              content: DefaultTextStyle.merge(
                textAlign: TextAlign.start,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('The security scan asks for your confirmation.'),
                    SizedBox(height: 12),
                    Text('HIGH  Downloads and runs a remote script'),
                    Text(
                      'scripts/fetch.sh:12',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ],
                ),
              ),
              actions: [
                AppDialogAction(onPressed: () {}, child: const Text('Cancel')),
                AppDialogAction(
                  isDefault: true,
                  onPressed: () {},
                  child: const Text('Install anyway'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    // Nine dialogs open through showAppDialog, which on macOS is a fading
    // window with a barrier a click closes. Each case opens the dialog the
    // way its screen does: the task log directly, the other two by pressing
    // the screen's own button once it has loaded.
    WidgetbookComponent(
      name: 'showAppDialog (Mac)',
      useCases: [
        _mac(
          'Kanban task log',
          (_) => Hosted<KanbanRepository>(
            create: () => KanbanRepository(kanbanServer().client()),
            builder: (_, repository) => openOnShow(
              (context) => showAppDialog<void>(
                context: context,
                builder: (_) => KanbanTaskLogDialog(
                  repository: repository,
                  taskId: 't_run',
                ),
              ),
            ),
          ),
        ),
        _mac(
          'Kanban task log unavailable',
          (_) => Hosted<KanbanRepository>(
            create: () => KanbanRepository(
              (kanbanServer()..on(
                    'GET',
                    '/api/plugins/kanban/tasks/t_run/log',
                    {'detail': 'gone'},
                    status: 500,
                  ))
                  .client(),
            ),
            builder: (_, repository) => openOnShow(
              (context) => showAppDialog<void>(
                context: context,
                builder: (_) => KanbanTaskLogDialog(
                  repository: repository,
                  taskId: 't_run',
                ),
              ),
            ),
          ),
        ),
        for (final (name, inspection) in <(String, Map<String, Object?>)>[
          (
            'Kanban workers, process of a run',
            {
              'alive': true,
              'pid': 4242,
              'status': 'running',
              'memory_rss_bytes': 188743680,
              'num_threads': 12,
            },
          ),
          (
            'Kanban workers, process gone',
            {'alive': false, 'reason': 'No such process'},
          ),
        ])
          _mac(
            name,
            (_) => Hosted<KanbanRepository>(
              create: () => KanbanRepository(
                (kanbanServer()..on(
                      'GET',
                      '/api/plugins/kanban/runs/7/inspect',
                      inspection,
                    ))
                    .client(),
              ),
              builder: (_, repository) => PressWhenReady(
                pick: _callbackOf<KanbanWorkerRow>((row) => row.onInspect),
                child: pushed(KanbanWorkersScreen(repository: repository)),
              ),
            ),
          ),
        _mac(
          'Install a skill the scan flagged',
          (context) => skillsUseCase(
            'Install a skill the scan flagged',
            (skills, hub) => PressWhenReady(
              pick: _callbackOf<OutlinedButton>((button) => button.onPressed),
              child: HubSkillScreen(hub: hub, skill: _hubSkill),
            ),
            serve: _askingHub,
          ).builder(context),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'New profile',
      useCases: onEachPlatform(
        'Empty',
        (_) => openOnShow((context) async {
          await showNewProfileDialog(context);
        }),
      ),
    ),
    WidgetbookComponent(
      name: 'askKanbanText',
      useCases: [
        _open(
          'One line',
          (context) => askKanbanText(
            context,
            title: 'New board',
            hint: 'Name',
            confirm: 'Create',
          ),
        ),
        _open(
          'Several lines, prefilled',
          (context) => askKanbanText(
            context,
            title: 'Add a comment',
            initial: 'Endpoint 1 is done.',
            confirm: 'Post',
            multiline: true,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'confirmKanban',
      useCases: [
        _open(
          'Confirm',
          (context) => confirmKanban(
            context,
            title: 'Delete this board?',
            confirm: 'Delete',
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'runKanbanAction',
      useCases: [
        _open(
          'Plugin refuses',
          (context) => runKanbanAction(
            context,
            () async => throw const KanbanException('The task is running'),
          ),
        ),
        _open(
          'Something went wrong',
          (context) => runKanbanAction(
            context,
            () async => throw const FormatException('x'),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'showKanbanTask',
      useCases: [
        _open(
          'Task sheet or dialog',
          (context) => showKanbanTask(
            context,
            repository: KanbanRepository(kanbanServer().client()),
            taskId: 't_run',
            files: _NoFiles(),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'showMcpCommandReview',
      useCases: [
        _open(
          'Sheet or dialog',
          (context) => showMcpCommandReview(context, const [
            npxServer,
            envServer,
          ], confirmLabel: 'Save servers'),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'reportInstall',
      useCases: [
        _report(
          'Installed',
          const PluginInstallResult(ok: true, pluginName: 'browser-tools'),
        ),
        _report(
          'Installed with warnings',
          const PluginInstallResult(
            ok: true,
            pluginName: 'browser-tools',
            warnings: ['Runs a script on load', 'Adds a hook'],
          ),
        ),
        _report(
          'Environment variables to set',
          const PluginInstallResult(
            ok: true,
            pluginName: 'browser-tools',
            missingEnv: ['BROWSER_PATH', 'BROWSER_PROFILE'],
          ),
        ),
        _report(
          'Refused',
          const PluginInstallResult(ok: false, message: 'Not in the catalog'),
        ),
        _report(
          'Still installing',
          const PluginInstallResult(ok: false, timedOut: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'showSkillJobSheet',
      useCases: [
        for (final entry in {
          'Running': null,
          'Succeeded': 0,
          'Failed': 2,
          'Unknown': -1,
        }.entries)
          ...onEachPlatform(
            '${entry.key} job',
            (_) => openOnShow((context) async {
              final job = SkillJob(
                title: 'Installing web-scraper',
                start: () async => const StartedJob(name: 'install'),
                status: (_) async => JobStatus(
                  running: entry.value == null,
                  exitCode: entry.value == -1 ? null : entry.value,
                  lines: ['Fetching web-scraper', 'Installing'],
                ),
                wait: (_) => Completer<void>().future,
              );
              unawaited(job.run());
              try {
                await showSkillJobStatus(context, job);
              } finally {
                job.dispose();
              }
            }),
          ),
      ],
    ),
  ],
);
