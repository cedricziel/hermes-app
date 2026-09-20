import 'package:flutter/foundation.dart';

import 'hermes_skills_hub_repository.dart';
import 'hermes_skills_repository.dart';

enum JobState { starting, running, succeeded, failed, unknown }

/// A background job the server runs for the user (install, uninstall,
/// update), followed to its end.
///
/// The exit code decides the outcome. A job the server no longer knows, or
/// whose state cannot be read repeatedly, ends as [JobState.unknown]: it is
/// never reported as a success.
class SkillJob extends ChangeNotifier {
  SkillJob({
    required this.title,
    required this.start,
    required this.status,
    this.wait = _defaultWait,
    this.interval = const Duration(milliseconds: 1500),
    this.maxPolls = 400,
    this.maxReadFailures = 3,
  });

  final String title;
  final Future<StartedJob> Function() start;
  final Future<JobStatus?> Function(String name) status;
  final Future<void> Function(Duration) wait;
  final Duration interval;
  final int maxPolls;
  final int maxReadFailures;

  JobState _state = JobState.starting;
  List<String> _lines = const [];
  String? _error;

  JobState get state => _state;
  List<String> get lines => _lines;
  String? get error => _error;
  bool get running => _state == JobState.starting || _state == JobState.running;

  static Future<void> _defaultWait(Duration d) => Future.delayed(d);

  Future<void> run() async {
    final StartedJob started;
    try {
      started = await start();
    } on SkillsRejected catch (e) {
      _finish(JobState.failed, error: e.message);
      return;
    } on Object {
      _finish(JobState.failed, error: 'Could not start the job');
      return;
    }
    _set(JobState.running);

    var failures = 0;
    for (var poll = 0; poll < maxPolls; poll++) {
      final JobStatus? current;
      try {
        current = await status(started.name);
      } on Object {
        if (++failures >= maxReadFailures) break;
        await wait(interval);
        continue;
      }
      failures = 0;
      if (current == null) break;
      final sameJob =
          current.pid == null ||
          started.pid == null ||
          current.pid == started.pid;
      if (sameJob) {
        _lines = current.lines;
        if (!current.running) {
          _finish(switch (current.exitCode) {
            0 => JobState.succeeded,
            null => JobState.unknown,
            _ => JobState.failed,
          }, lines: current.lines);
          return;
        }
        notifyListeners();
      }
      await wait(interval);
    }
    _finish(JobState.unknown);
  }

  void _set(JobState state) {
    _state = state;
    notifyListeners();
  }

  void _finish(JobState state, {List<String>? lines, String? error}) {
    _state = state;
    if (lines != null) _lines = lines;
    _error = error;
    notifyListeners();
  }
}
