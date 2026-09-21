import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notifications/notification_settings.dart';
import 'job_form_controller.dart';
import 'job_form_screen.dart';
import 'schedule_models.dart';
import 'schedule_widgets.dart';
import 'schedules_controller.dart';

/// Asks the chat to show the session of a run.
typedef OpenRun = void Function(CronRun run, CronJob job);

/// One job in full: how it is doing, what it does, and its runs.
class ScheduleDetail extends StatefulWidget {
  const ScheduleDetail({
    super.key,
    required this.controller,
    required this.job,
    required this.onOpenRun,
  });

  final SchedulesController controller;
  final CronJob job;
  final OpenRun onOpenRun;

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
      if (mounted) _loadRuns(++_load);
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

  Future<void> _delete() async {
    final job = widget.job;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: Text(
          '“${job.title}” will no longer run. Its past runs stay as chats.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final message = await _controller.delete(job);
    if (message != null) _say(message);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = _controller.now;
    final color = outcomeColor(context, job);
    final next = nextRunText(job, now);
    NotificationSettings? notifications;
    try {
      notifications = context.watch<NotificationSettings>();
    } on ProviderNotFoundException {
      notifications = null;
    }
    final settings = <(String, String)>[
      if (job.skills.isNotEmpty) ('Skills', job.skills.join(', ')),
      if (job.model != null) ('Model', job.model!),
      if (job.provider != null) ('Provider', job.provider!),
      if (job.script != null) ('Script', job.script!),
      if (job.workdir != null) ('Working directory', job.workdir!),
      if (job.contextFrom.isNotEmpty)
        ('Takes context from', job.contextFrom.join(', ')),
      ('Deliver to', deliveryLabel(job.deliver)),
      if (job.profile != null) ('Profile', job.profile!),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(job.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(
                spacing: 8,
                children: [
                  StatusDot(color: color),
                  Expanded(
                    child: Text(
                      statusText(job, now),
                      style: theme.textTheme.titleSmall?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              if (job.outcome == CronOutcome.failed &&
                  failureReason(job) != null)
                Text(
                  failureReason(job)!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontFamily: 'monospace',
                  ),
                ),
              if (job.lastDeliveryError != null &&
                  job.outcome != CronOutcome.deliveryFailed)
                Text('Delivery failed: ${job.lastDeliveryError}'),
              if (job.outcome == CronOutcome.deliveryFailed &&
                  job.lastDeliveryError != null)
                Text(
                  job.lastDeliveryError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              if (next != null)
                Text(
                  next,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _runNow,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run now'),
            ),
            OutlinedButton.icon(
              onPressed: job.state == CronJobState.completed
                  ? null
                  : _togglePaused,
              icon: Icon(
                job.isPaused ? Icons.play_circle_outline : Icons.pause,
              ),
              label: Text(job.isPaused ? 'Resume' : 'Pause'),
            ),
            OutlinedButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ],
        ),
        if (notifications != null)
          SwitchListTile(
            key: const Key('job-mute'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Mute notifications'),
            subtitle: const Text('No alert when this task runs'),
            value: notifications.isMuted(job.key),
            onChanged: (muted) => notifications!.setMuted(job.key, muted),
          ),
        const SizedBox(height: 20),
        _Heading('Schedule'),
        Text(
          job.scheduleWords.isEmpty ? 'Unknown' : job.scheduleWords,
          style: theme.textTheme.bodyLarge,
        ),
        if (job.scheduleKind == 'cron' && job.scheduleExpr != null) ...[
          const SizedBox(height: 6),
          InfoChip(job.scheduleExpr!),
        ],
        if (job.prompt.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Heading('Task'),
          _Section(child: SelectableText(job.prompt)),
        ],
        const SizedBox(height: 20),
        _Heading('Settings'),
        for (final (label, value) in settings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Text(value)),
              ],
            ),
          ),
        const SizedBox(height: 20),
        _Heading('Run history'),
        ..._history(context),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete task'),
          ),
        ),
      ],
    );
  }

  List<Widget> _history(BuildContext context) {
    final runs = _runs;
    if (runs == null) {
      return [
        if (_runsFailed)
          Row(
            children: [
              const Expanded(child: Text('Could not load the runs')),
              TextButton(
                onPressed: () => _loadRuns(++_load),
                child: const Text('Retry'),
              ),
            ],
          )
        else
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ];
    }
    if (runs.isEmpty) return const [Text('No runs yet')];
    final scheme = Theme.of(context).colorScheme;
    return [
      for (final run in runs)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: run.isActive
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: scheme.outline,
                ),
          title: Text(formatTime(context, run.startedAt)),
          subtitle: Text(
            run.isActive
                ? 'Running'
                : run.duration == null
                ? 'Unfinished'
                : formatDuration(run.duration!),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => widget.onOpenRun(run, widget.job),
        ),
      if (runs.length >= _limit && _limit < _maxRuns)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              _limit = (_limit + _pageSize).clamp(0, _maxRuns);
              _loadRuns(++_load);
            },
            child: const Text('Show more'),
          ),
        ),
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}
