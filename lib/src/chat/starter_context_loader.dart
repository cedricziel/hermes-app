import 'dart:async';

import '../api/hermes_repositories.dart';
import '../schedules/schedule_models.dart';
import 'starter_prompts.dart';

/// Reads what the welcome view's starter prompts are built from: a failed
/// scheduled job, a stuck Kanban task and a skill the user relies on. Each
/// source that fails or takes longer than [timeout] is left out.
class StarterContextLoader {
  StarterContextLoader(
    this._repositories, {
    this.timeout = const Duration(seconds: 5),
  });

  final HermesRepositories _repositories;
  final Duration timeout;

  Future<StarterContext> load(String? profile) async {
    final (failedJob, kanbanTask, skill) = await (
      _settle(_failedJob(profile)),
      _settle(_kanbanTask()),
      _settle(_skill(profile)),
    ).wait;
    return StarterContext(
      failedJob: failedJob,
      kanbanTask: kanbanTask,
      skill: skill,
    );
  }

  Future<T?> _settle<T>(Future<T?> source) =>
      source.timeout(timeout).then<T?>((v) => v, onError: (_) => null);

  Future<String?> _failedJob(String? profile) async {
    final failed =
        (await _repositories.cron.listJobs(profile: profile))
            .where((j) => j.outcome == CronOutcome.failed)
            .toList()
          ..sort(
            (a, b) => (b.lastRunAt ?? DateTime(0)).compareTo(
              a.lastRunAt ?? DateTime(0),
            ),
          );
    return failed.firstOrNull?.name;
  }

  Future<StarterTask?> _kanbanTask() async {
    if (!await _repositories.plugins.isKanbanEnabled()) return null;
    final columns = (await _repositories.kanban.loadBoard()).columns;
    for (final (status, blocked) in [('blocked', true), ('review', false)]) {
      final task = columns
          .where((c) => c.name == status)
          .expand((c) => c.tasks)
          .firstOrNull;
      if (task != null) return StarterTask(task.title, blocked: blocked);
    }
    return null;
  }

  Future<String?> _skill(String? profile) async {
    final used =
        (await _repositories.skills.list(profile: profile))
            .where((s) => s.enabled && s.usage > 0)
            .toList()
          ..sort((a, b) => b.usage.compareTo(a.usage));
    return used.firstOrNull?.name;
  }
}
