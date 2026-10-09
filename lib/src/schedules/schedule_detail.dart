import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notifications/notification_settings.dart';
import 'job_form_controller.dart';
import 'job_form_screen.dart';
import 'schedule_actions.dart';
import 'schedule_models.dart';
import 'schedules_controller.dart';
import 'widgets/schedule_detail_view.dart';

/// Asks the chat to show the session of a run.
typedef OpenRun = void Function(CronRun run, CronJob job);

/// One job in full: how it is doing, what it does, and its runs.
class ScheduleDetail extends StatefulWidget {
  const ScheduleDetail({
    super.key,
    required this.controller,
    required this.job,
    required this.onOpenRun,
    this.showTitle = true,
  });

  final SchedulesController controller;
  final CronJob job;
  final OpenRun onOpenRun;

  /// Names the job above its sections; off where the bar already does.
  final bool showTitle;

  @override
  State<ScheduleDetail> createState() => _ScheduleDetailState();
}

class _ScheduleDetailState extends State<ScheduleDetail> {
  static const _pageSize = 20;
  static const _maxRuns = 100;

  List<CronRun>? _runs;
  bool _runsFailed = false;
  int _limit = _pageSize;
  int _load = 0;

  SchedulesController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(ScheduleDetail old) {
    super.didUpdateWidget(old);
    if (old.job.key != widget.job.key) {
      _runs = null;
      _runsFailed = false;
      _limit = _pageSize;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final job = widget.job;
    final load = ++_load;
    final fresh = await _controller.reload(job);
    if (!mounted || load != _load) return;
    if (fresh == null) {
      _say('This task no longer exists');
      return;
    }
    await _loadRuns(load);
  }

  Future<void> _loadRuns(int load) async {
    try {
      final runs = await _controller.loadRuns(widget.job, limit: _limit);
      if (!mounted || load != _load) return;
      setState(() {
        _runs = runs;
        _runsFailed = false;
      });
    } on Object {
      if (!mounted || load != _load) return;
      setState(() => _runsFailed = true);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runNow() async {
    final message = await _controller.runNow(widget.job);
    _say(message ?? 'Run requested');
    if (message == null) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) await _loadRuns(++_load);
    }
  }

  Future<void> _togglePaused() async {
    final message = await _controller.setPaused(
      widget.job,
      !widget.job.isPaused,
    );
    if (message != null) _say(message);
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<CronJob>(
      MaterialPageRoute(
        builder: (_) => JobFormScreen(
          controller: JobFormController(
            repository: _controller.repository,
            editing: widget.job,
          ),
        ),
      ),
    );
    if (saved != null && mounted) _controller.jobSaved(saved);
  }

  Future<void> _delete() => deleteScheduleJob(context, _controller, widget.job);

  bool get _canShowMore {
    final runs = _runs;
    return runs != null && runs.length >= _limit && _limit < _maxRuns;
  }

  void _showMore() {
    _limit = (_limit + _pageSize).clamp(0, _maxRuns);
    _loadRuns(++_load);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final now = _controller.now;
    NotificationSettings? notifications;
    try {
      notifications = context.watch<NotificationSettings>();
    } on ProviderNotFoundException {
      notifications = null;
    }
    return ScheduleDetailView(
      job: job,
      now: now,
      runs: _runs,
      runsFailed: _runsFailed,
      showTitle: widget.showTitle,
      muted: notifications?.isMuted(job.key),
      onMutedChanged: notifications == null
          ? null
          : (muted) => notifications!.setMuted(job.key, muted),
      onRunNow: _runNow,
      onEdit: _edit,
      onTogglePaused: _togglePaused,
      onDelete: _delete,
      onOpenRun: (run) => widget.onOpenRun(run, job),
      onRetryRuns: () => _loadRuns(++_load),
      onShowMoreRuns: _canShowMore ? _showMore : null,
    );
  }
}
