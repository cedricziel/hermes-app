import 'dart:async';

import 'package:flutter/widgets.dart';

import '../notifications/attention_policy.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../shell/app_presence.dart';
import 'hermes_cron_repository.dart';
import 'schedule_baseline.dart';
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

/// Looks at the server's jobs while the app runs, and posts a notification
/// for a run the user has not seen. Hermes cannot push to the app, so this
/// only sees what happens while the app runs. On macOS that includes the time
/// after the last window closed ([AppPresence]).
class ScheduleWatcher with WidgetsBindingObserver {
  ScheduleWatcher({
    required this.repository,
    required this.service,
    required this.settings,
    this.profiles,
    ScheduleBaseline? baseline,
    String Function()? account,
    this.interval = const Duration(minutes: 1),
  }) : _baseline = baseline ?? ScheduleBaseline(),
       _account = account ?? _noAccount {
    _foreground = AppPresence.foreground(
      WidgetsBinding.instance.lifecycleState,
    );
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_settingsChanged);
    _wasEnabled = _enabled;
  }

  final HermesCronRepository repository;
  final NotificationService service;
  final NotificationSettings settings;
  final HermesProfilesRepository? profiles;
  final Duration interval;

  /// What the last look, here or in a background run, saw of each job. Read
  /// at every look: a background run may have moved it while the app was away.
  final ScheduleBaseline _baseline;

  /// The account (`accountKeyFor`) the baseline belongs to, asked at every
  /// look.
  final String Function() _account;

  static String _noAccount() => '';

  /// The removal of the baseline last asked for. A look waits for it, so that
  /// it never compares with a baseline that was about to go.
  Future<void> _forgetting = Future.value();

  bool _available = false;
  bool _inFront = false;
  bool _foreground = true;
  bool _wasEnabled = false;
  Future<void>? _inflight;
  bool _disposed = false;
  bool _paused = false;
  int _epoch = 0;
  Timer? _timer;

  bool get _enabled =>
      settings.loaded && settings.enabled && settings.scheduleAlerts;

  /// Suspends checks without forgetting the last-run comparison baseline.
  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    _invalidate();
    _sync();
  }

  /// Whether the server has the cron routes. Nothing is checked without.
  set available(bool value) {
    if (_available == value) return;
    _available = value;
    _invalidate();
    if (!value) _forgetBaseline();
    _sync();
  }

  /// Whether the Schedules destination is on screen. Its list shows a run,
  /// so it is not announced then.
  set schedulesInFront(bool value) => _inFront = value;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = AppPresence.foreground(state);
    // A step between two states that both run the app (macOS: resumed,
    // inactive, hidden) must not restart the timer and look again.
    if (foreground == _foreground) return;
    _foreground = foreground;
    _invalidate();
    _sync();
  }

  void _settingsChanged() {
    final enabled = _enabled;
    // Turning it on starts from a new baseline, so runs from the time it was
    // off are not announced.
    if (enabled != _wasEnabled) {
      _invalidate();
      _forgetBaseline();
    }
    _wasEnabled = enabled;
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _paused || !_available || !_foreground || !_enabled) {
      return;
    }
    _timer = Timer.periodic(interval, (_) => check());
    check();
  }

  /// One look at the jobs of every profile. A look asked for while another
  /// runs joins it.
  Future<void> check() {
    if (!_current(_epoch)) return Future.value();
    if (_inflight case final pending?) {
      return pending;
    }
    late final Future<void> pending;
    pending = _look(_epoch).whenComplete(() {
      if (identical(_inflight, pending)) _inflight = null;
    });
    return _inflight = pending;
  }

  bool _current(int epoch) =>
      !_disposed && !_paused && _available && _enabled && epoch == _epoch;

  void _invalidate() {
    _epoch++;
    _inflight = null;
  }

  Future<void> _look(int epoch) async {
    try {
      final jobs = await repository.listJobs(profile: 'all');
      if (!_current(epoch)) return;
      await _forgetting;
      if (!_current(epoch)) return;
      final account = _account();
      final baseline = await _baseline.read(account);
      if (!_current(epoch)) return;
      final pass = runsSince(baseline, jobs);
      final unmuted = [
        for (final job in pass.ran)
          if (!settings.isMuted(job.key)) job,
      ];
      final activeProfile = !_inFront && unmuted.isNotEmpty
          ? await _activeProfile()
          : null;
      if (!_current(epoch)) return;
      unawaited(settings.forgetMutes({for (final j in jobs) j.key}));
      if (!_current(epoch)) return;
      // Before the alerts, so that a baseline that cannot be saved announces
      // nothing now rather than once more at every look.
      await _baseline.write(account, pass.baseline);
      if (!_current(epoch) || _inFront) return;
      final alerts = alertsFor(unmuted, activeProfile: activeProfile);
      for (final alert in alerts) {
        if (!_current(epoch)) return;
        if (service is GuardedNotificationService) {
          await (service as GuardedNotificationService).showWhile(
            alert,
            () => _current(epoch),
          );
        } else {
          await service.show(alert);
        }
      }
    } on Object {
      // A look that failed is tried again on the next tick.
    }
  }

  void _forgetBaseline() {
    _forgetting = _forgetting.then((_) async {
      try {
        await _baseline.clear();
      } on Object {
        // The next look still compares with what is stored.
      }
    });
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
    _invalidate();
    _timer?.cancel();
    settings.removeListener(_settingsChanged);
    WidgetsBinding.instance.removeObserver(this);
  }
}
