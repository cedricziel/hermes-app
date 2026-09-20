import 'dart:async';

import 'package:flutter/widgets.dart';

import '../notifications/attention_policy.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../profiles/hermes_profiles_repository.dart';
import 'hermes_cron_repository.dart';
import 'schedule_models.dart';

const kJobFinishedBody = 'Finished';
const kJobFailedBody = 'Failed';
const kJobDeliveryFailedBody = 'Result could not be delivered';

/// More runs than this in one look are announced as one notification.
const kSummaryAbove = 5;

/// The id of a job that has no run yet: older than any run.
final _never = DateTime.fromMillisecondsSinceEpoch(0);

/// The jobs that ran since the last look, and what to compare with next time.
typedef RunPass = ({List<CronJob> ran, Map<String, DateTime> baseline});

/// Compares [current] with [previous], the `last_run_at` of each job at the
/// last look, by job key. A job that is not in [previous] is seen for the
/// first time and sets its baseline without being reported, and so is every
/// job when there is no [previous] at all, so that opening the app does not
/// announce runs from before. A run time that moves backwards is not a run.
RunPass runsSince(Map<String, DateTime>? previous, Iterable<CronJob> current) {
  final baseline = <String, DateTime>{};
  final ran = <CronJob>[];
  for (final job in current) {
    final last = job.lastRunAt ?? _never;
    baseline[job.key] = last;
    final before = previous?[job.key];
    if (before != null && last.isAfter(before)) ran.add(job);
  }
  return (ran: ran, baseline: baseline);
}

/// The notifications [ran] deserve. Nothing names the prompt, the output or
/// the server's error: the lock screen only learns that a job finished.
/// [activeProfile] is the profile the user is on; a job of another one says
/// which. More than [kSummaryAbove] runs become one notification.
List<AttentionNotification> alertsFor(
  List<CronJob> ran, {
  String? activeProfile,
}) {
  if (ran.isEmpty) return const [];
  if (ran.length > kSummaryAbove) {
    final failed = ran.where((j) => j.outcome != CronOutcome.ok).length;
    return [
      AttentionNotification.job(
        jobId: '',
        title: 'Scheduled tasks',
        body: failed == 0
            ? '${ran.length} scheduled tasks ran'
            : '${ran.length} scheduled tasks ran, $failed failed',
      ),
    ];
  }
  return [
    for (final job in ran)
      AttentionNotification.job(
        jobId: job.id,
        profile: job.profile,
        title:
            activeProfile != null &&
                job.profile != null &&
                job.profile != activeProfile
            ? '${job.title} (${job.profile})'
            : job.title,
        body: switch (job.outcome) {
          CronOutcome.deliveryFailed => kJobDeliveryFailedBody,
          CronOutcome.failed => kJobFailedBody,
          _ => kJobFinishedBody,
        },
      ),
  ];
}

/// Looks at the server's jobs while the app is in front, and posts a
/// notification for a run the user has not seen. Hermes cannot push to the
/// app, so this only sees what happens while the app runs.
class ScheduleWatcher with WidgetsBindingObserver {
  ScheduleWatcher({
    required this.repository,
    required this.service,
    required this.settings,
    this.profiles,
    this.interval = const Duration(minutes: 1),
  }) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_settingsChanged);
    _wasEnabled = _enabled;
  }

  final HermesCronRepository repository;
  final NotificationService service;
  final NotificationSettings settings;
  final HermesProfilesRepository? profiles;
  final Duration interval;

  bool _available = false;
  bool _inFront = false;
  bool _foreground = true;
  bool _wasEnabled = false;
  Future<void>? _inflight;
  bool _disposed = false;
  Map<String, DateTime>? _baseline;
  Timer? _timer;

  bool get _enabled =>
      settings.loaded && settings.enabled && settings.scheduleAlerts;

  /// Whether the server has the cron routes. Nothing is checked without.
  set available(bool value) {
    if (_available == value) return;
    _available = value;
    if (!value) _baseline = null;
    _sync();
  }

  /// Whether the Schedules destination is on screen. Its list shows a run,
  /// so it is not announced then.
  set schedulesInFront(bool value) => _inFront = value;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _settingsChanged() {
    final enabled = _enabled;
    // Turning it on starts from a new baseline, so runs from the time it was
    // off are not announced.
    if (enabled != _wasEnabled) _baseline = null;
    _wasEnabled = enabled;
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !_available || !_foreground || !_enabled) return;
    _timer = Timer.periodic(interval, (_) => check());
    check();
  }

  /// One look at the jobs of every profile. A look asked for while another
  /// runs joins it.
  Future<void> check() =>
      _inflight ??= _look().whenComplete(() => _inflight = null);

  Future<void> _look() async {
    if (_disposed || !_available || !_enabled) return;
    try {
      final jobs = await repository.listJobs(profile: 'all');
      if (_disposed || !_enabled) return;
      unawaited(settings.forgetMutes({for (final j in jobs) j.key}));
      final pass = runsSince(_baseline, jobs);
      _baseline = pass.baseline;
      if (_inFront) return;
      final unmuted = [
        for (final job in pass.ran)
          if (!settings.isMuted(job.key)) job,
      ];
      if (unmuted.isEmpty) return;
      final alerts = alertsFor(unmuted, activeProfile: await _activeProfile());
      for (final alert in alerts) {
        unawaited(service.show(alert));
      }
    } on Object {
      // A look that failed is tried again on the next tick.
    }
  }

  Future<String?> _activeProfile() async {
    try {
      return (await profiles?.loadActive())?.active;
    } on Object {
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    settings.removeListener(_settingsChanged);
    WidgetsBinding.instance.removeObserver(this);
  }
}
