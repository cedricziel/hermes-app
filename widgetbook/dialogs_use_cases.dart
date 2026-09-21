import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/kanban/kanban_files.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/plugins/install_report.dart';
import 'package:hermes_app/src/plugins/plugin_install_result.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'host.dart';
import 'kanban_screen_use_cases.dart';

WidgetbookUseCase _open(
  String name,
  Future<void> Function(BuildContext context) open,
) => WidgetbookUseCase(name: name, builder: (_) => openOnShow(open));

WidgetbookUseCase _report(String name, PluginInstallResult result) =>
    _open(name, (context) => reportInstall(context, result));

class _NoFiles implements KanbanFiles {
  @override
  Future<KanbanPickedFile?> pick() async => null;

  @override
  Future<bool> save(String name, Uint8List bytes) async => true;
}

WidgetbookNode dialogsNode() => WidgetbookFolder(
  name: 'Dialogs and sheets',
  children: [
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
          (context) =>
              runKanbanAction(context, () async => throw StateError('x')),
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
        _open(
          'Running job',
          (context) => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => SkillJobSheet(
              job: SkillJob(
                title: 'Installing web-scraper',
                start: () async => const StartedJob(name: 'install'),
                status: (_) async => const JobStatus(
                  running: true,
                  lines: ['Fetching web-scraper', 'Installing'],
                ),
                wait: (_) => Completer<void>().future,
              )..run(),
            ),
          ),
        ),
      ],
    ),
  ],
);
