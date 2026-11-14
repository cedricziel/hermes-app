import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/kanban/kanban_files.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
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
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:hermes_app/src/profiles/widgets/new_profile_dialog.dart';

import 'frame.dart';
import 'fixtures.dart';
import 'host.dart';
import 'kanban_screen_use_cases.dart';

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
    data: Theme.of(context).copyWith(platform: TargetPlatform.android),
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
