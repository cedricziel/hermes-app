import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_otel/flutter_otel.dart';

import '../auth/auth_controller.dart';
import '../chat/gateway_connection_transport.dart';
import '../chat/invalidation/change_invalidation_binding.dart';
import '../chat/invalidation/change_signal.dart';

import '../network/poll_backoff.dart';
import '../profiles/hermes_profiles_repository.dart';
import 'hermes_cron_repository.dart';
import 'schedule_models.dart';

const _allProfilesKey = 'hermes.schedules_all_profiles';

/// A protected page action belongs to a suspended or retired activity period.
class SchedulesActivitySuspended extends StateError {
  SchedulesActivitySuspended() : super('Schedules activity suspended');
}

/// Owns the job list behind the Schedules destination: which profile it
/// shows, the filter, refreshing, and the changes a user can make.
///
/// The phone list and the wide detail read the same instance, so they cannot
/// disagree about a job.
class SchedulesController extends ChangeNotifier {
  SchedulesController({
    required this.repository,
    this.profiles,
    this.prefs,
    this.refreshEvery = const Duration(minutes: 1),
    this.activity,
    GatewayConnectionTransport? changeSource,
    AuthController? auth,
    AppEventLogger events = noopAppEventLogger,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    activity?.addListener(_activityChanged);
    if (changeSource != null && auth != null) {
      final changes = _changes = ChangeInvalidationBinding(
        source: changeSource,
        auth: auth,
        resource: InvalidationResource.schedules,
        profile: () => invalidationProfile,
        events: events,
      );
      var requestedGeneration = _generation;
      String? requestedProfile;
      changes.controller
          .register<({int generation, String profile, List<CronJob> jobs})>(
            InvalidationResource.schedules,
            readSnapshot: (scope) async {
              final generation = requestedGeneration = _generation;
              final profile = requestedProfile = scope.profile!;
              final jobs = await repository.listJobs(profile: profile);
              return (generation: generation, profile: profile, jobs: jobs);
            },
            snapshotIsCurrent: (snapshot) =>
                _canWork &&
                snapshot.generation == _generation &&
                snapshot.profile == invalidationProfile &&
                !invalidationBlocked,
            applySnapshot: (snapshot) => applyInvalidatedJobs(
              snapshot.jobs,
              profile: snapshot.profile,
              generation: snapshot.generation,
            ),
            onFailure: (error) {
              final profile = requestedProfile;
              if (profile != null) {
                invalidationFailed(
                  error,
                  profile: profile,
                  generation: requestedGeneration,
                );
              }
            },
          );
      changes.controller.addListener(_invalidationStateChanged);
      addListener(_syncInvalidation);
      _syncInvalidation();
    }
  }

  /// Whether protected page work may run; omission allows activity.
  final ValueListenable<bool>? activity;

  final HermesCronRepository repository;
  final HermesProfilesRepository? profiles;
  final Duration refreshEvery;
  final DateTime Function() _now;

  /// Where the scope the user picked is kept across launches; null keeps it
  /// for this run only.
  final SharedPreferencesAsync? prefs;
  Future<void>? _restored;
  bool _scopeRestored = false;

  /// Whether the user picked a scope, which a late read of the kept one must
  /// not overwrite.
  bool _picked = false;

  List<CronJob> _jobs = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  ScheduleFilter _filter = ScheduleFilter.all;
  bool _allProfiles = false;
  String? _activeProfile;
  bool _activeKnown = false;
  String? _selectedKey;
  int _generation = 0;
  bool _active = false;
  bool _foreground = true;
  bool _invalidationVisible = true;
  Timer? _timer;

  /// Skips timed refreshes while they keep failing.
  final _backoff = PollBackoff();
  bool _disposed = false;
  bool _started = false;
  bool _refreshing = false;
  int _mutations = 0;
  ChangeInvalidationBinding? _changes;
  int _activityEpoch = 0;

  bool get _canWork => !_disposed && (activity?.value ?? true);
  bool _currentActivity(int epoch) => _canWork && epoch == _activityEpoch;

  void _requireCurrent(int epoch) {
    if (!_currentActivity(epoch)) {
      throw SchedulesActivitySuspended();
    }
  }

  /// Captures the current activity period, rejecting while suspended.
  int captureActivity() {
    _requireCurrent(_activityEpoch);
    return _activityEpoch;
  }

  /// Rejects with [SchedulesActivitySuspended] if [epoch] has retired.
  void requireActivity(int epoch) => _requireCurrent(epoch);

  void _activityChanged() {
    if (_disposed) return;
    // Nested delivery can hide the false value; every notification retires work.
    final epoch = ++_activityEpoch;
    _generation++;
    _loading = false;
    _refreshing = false;
    _mutations = 0;
    _pending.clear();
    _openRequest = null;
    _restored = null;
    _activeKnown = false;
    _syncTimer();
    notifyListeners();
    if (_started && _currentActivity(epoch)) {
      unawaited(
        Future<void>.microtask(() {
          if (_currentActivity(epoch)) return refresh();
        }),
      );
    }
  }

  int get invalidationGeneration => _generation;
  String? get invalidationProfile =>
      _allProfiles ? 'all' : (_activeKnown ? _activeProfile : null);
  bool get invalidationActive =>
      _active && _foreground && _invalidationVisible && _canWork;
  set invalidationVisible(bool value) {
    if (_invalidationVisible == value) return;
    _invalidationVisible = value;
    _syncInvalidation();
  }

  bool get invalidationBlocked =>
      _refreshing || _pending.isNotEmpty || _mutations > 0;
  void _syncInvalidation() =>
      _changes?.sync(active: invalidationActive, blocked: invalidationBlocked);
  void _invalidationStateChanged() => notifyListeners();

  Future<T> _mutating<T>(Future<T> Function() body) async {
    final epoch = captureActivity();
    _mutations++;
    _syncInvalidation();
    try {
      return await body();
    } finally {
      if (epoch == _activityEpoch) {
        _mutations--;
        _syncInvalidation();
      }
    }
  }

  bool applyInvalidatedJobs(
    List<CronJob> jobs, {
    required String profile,
    required int generation,
  }) {
    if (!_canWork ||
        generation != _generation ||
        profile != invalidationProfile ||
        invalidationBlocked) {
      return false;
    }
    _jobs = [for (final job in jobs) _withPending(job)];
    _loaded = true;
    _error = null;
    notifyListeners();
    return true;
  }

  void invalidationFailed(
    Object error, {
    required String profile,
    required int generation,
  }) {
    if (!_canWork ||
        generation != _generation ||
        profile != invalidationProfile) {
      return;
    }
    _error = _describe(error);
    notifyListeners();
  }

  /// Jobs the user changed and whose answer is still awaited, so a refresh
  /// landing meanwhile does not undo the switch.
  final _pending = <String, CronJobState>{};

  DateTime get now => _now();
  bool get loading =>
      _loading ||
      (_changes?.controller.loading(InvalidationResource.schedules) ?? false);
  bool get loaded => _loaded;
  String? get error => _error;
  ScheduleFilter get filter => _filter;
  bool get allProfiles => _allProfiles;
  String? get activeProfile => _activeProfile;
  List<CronJob> get jobs => _jobs;

  List<CronJob> get visibleJobs => sortJobs(filterJobs(_jobs, _filter));

  int get failingCount => _jobs.where((j) => j.isFailing).length;

  CronJob? get selected =>
      _jobs.where((j) => j.key == _selectedKey).firstOrNull;

  /// Whether rows should name their profile.
  bool get showProfiles => _allProfiles;

  set filter(ScheduleFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// The user's pick between the active profile and every profile. It is
  /// kept for the next launch.
  set allProfiles(bool value) {
    _picked = true;
    if (_allProfiles == value) return;
    prefs?.setBool(_allProfilesKey, value);
    _setScope(value);
  }

  void _setScope(bool all) {
    if (_allProfiles == all) return;
    final epoch = _activityEpoch;
    _allProfiles = all;
    notifyListeners();
    if (_currentActivity(epoch)) refresh();
  }

  Future<void> _restore(int epoch) async {
    if (_scopeRestored) return;
    try {
      final all = await prefs?.getBool(_allProfilesKey);
      _requireCurrent(epoch);
      if (all != null && !_picked) _allProfiles = all;
      _scopeRestored = true;
    } on Object {
      // An unreadable setting leaves the default scope.
    }
  }

  void select(CronJob? job) {
    _selectedKey = job?.key;
    notifyListeners();
  }

  /// Whether the destination is in front. The list refreshes on the minute
  /// only while it is, and once when it comes to the front.
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    _syncTimer();
    if (value) refresh();
  }

  /// Whether the app is in the foreground. No timed refresh runs behind it.
  set foreground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _syncTimer();
    if (value && _active) refresh();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    _backoff.reset();
    if (_active && _foreground && _canWork) {
      _timer = Timer.periodic(refreshEvery, (_) {
        if (_backoff.tick()) refresh();
      });
    }
  }

  /// The profile to ask for: every one, the sticky active one, or null when
  /// the server has no profiles to tell apart. A failure to read the active
  /// profile throws, so a list is never shown unscoped by accident.
  Future<String?> _scope(int epoch) async {
    await (_restored ??= _restore(epoch));
    _requireCurrent(epoch);
    if (_allProfiles) return 'all';
    if (_activeKnown) return _activeProfile;
    try {
      final active = (await profiles?.loadActive())?.active;
      _requireCurrent(epoch);
      _activeProfile = active;
    } on DioException catch (e) {
      _requireCurrent(epoch);
      if (e.response?.statusCode != 404) rethrow;
      _activeProfile = null;
    }
    _activeKnown = true;
    return _activeProfile;
  }

  Future<void> refresh() async {
    if (!_canWork) return;
    _started = true;
    final epoch = _activityEpoch;
    final generation = ++_generation;
    _refreshing = true;
    if (!_loaded) _loading = true;
    notifyListeners();
    if (!_currentActivity(epoch)) return;
    try {
      final scope = await _scope(epoch);
      if (!_currentActivity(epoch) || generation != _generation) return;
      final jobs = await repository.listJobs(profile: scope);
      if (!_currentActivity(epoch) || generation != _generation) return;
      _backoff.succeeded();
      _jobs = [for (final job in jobs) _withPending(job)];
      _loaded = true;
      _loading = false;
      _error = null;
      if (_selectedKey != null && selected == null) _selectedKey = null;
    } on Object catch (e) {
      if (!_currentActivity(epoch) || generation != _generation) return;
      _backoff.failed();
      _loading = false;
      _error = _describe(e);
    } finally {
      if (_currentActivity(epoch) && generation == _generation) {
        _refreshing = false;
      }
    }
    notifyListeners();
  }

  CronJob _withPending(CronJob job) {
    final wanted = _pending[job.key];
    return wanted == null ? job : job.copyWith(state: wanted);
  }

  String _describe(Object e) => switch (e) {
    CronException(:final message) => message,
    DioException(:final response) when response?.statusCode != null =>
      'The server answered ${response!.statusCode}',
    _ => 'Could not reach the server',
  };

  /// Pauses or resumes [job]. The switch moves at once; the returned message
  /// is set when the server refused and it moved back.
  /// Rejects with [StateError] when activity is suspended or retired.
  Future<String?> setPaused(CronJob job, bool paused) => _mutating(() async {
    final epoch = _activityEpoch;
    _requireCurrent(epoch);
    final state = paused ? CronJobState.paused : CronJobState.scheduled;
    final before = _jobs;
    _pending[job.key] = state;
    _replace(job.copyWith(state: state));
    try {
      _requireCurrent(epoch);
      if (paused) {
        await repository.pause(job.id, profile: job.profile);
      } else {
        await repository.resume(job.id, profile: job.profile);
      }
      _requireCurrent(epoch);
      _pending.remove(job.key);
      await refresh();
      _requireCurrent(epoch);
      return null;
    } on Object catch (e) {
      _requireCurrent(epoch);
      _pending.remove(job.key);
      _jobs = before;
      notifyListeners();
      _requireCurrent(epoch);
      if (e is CronException && e.isNotFound) {
        _remove(job);
        _requireCurrent(epoch);
        return 'This task no longer exists';
      }
      return paused
          ? 'Could not pause “${job.title}”'
          : 'Could not resume “${job.title}”';
    }
  });

  /// Asks for one run of [job]. The run is not awaited. Null on success.
  /// Rejects with [StateError] when activity is suspended or retired.
  Future<String?> runNow(CronJob job) => _mutating(() async {
    final epoch = _activityEpoch;
    _requireCurrent(epoch);
    try {
      await repository.trigger(job.id, profile: job.profile);
      _requireCurrent(epoch);
      return null;
    } on Object catch (e) {
      _requireCurrent(epoch);
      if (e is CronException && e.isNotFound) {
        _remove(job);
        _requireCurrent(epoch);
        return 'This task no longer exists';
      }
      return 'Could not start “${job.title}”';
    }
  });

  /// Deletes [job]. A job the server no longer has counts as deleted.
  /// Rejects with [StateError] when activity is suspended or retired.
  Future<String?> delete(CronJob job) => _mutating(() async {
    final epoch = _activityEpoch;
    _requireCurrent(epoch);
    try {
      await repository.delete(job.id, profile: job.profile);
    } on Object catch (e) {
      _requireCurrent(epoch);
      if (!(e is CronException && e.isNotFound)) {
        return 'Could not delete “${job.title}”';
      }
    }
    _requireCurrent(epoch);
    _remove(job);
    _requireCurrent(epoch);
    return null;
  });

  /// Reads [job] again. A job that is gone is dropped and null is returned.
  /// Rejects with [StateError] when activity is suspended or retired.
  Future<CronJob?> reload(CronJob job) async {
    final epoch = _activityEpoch;
    _requireCurrent(epoch);
    try {
      final fresh = await repository.getJob(job.id, profile: job.profile);
      _requireCurrent(epoch);
      _replace(_withPending(fresh));
      _requireCurrent(epoch);
      return fresh;
    } on CronException catch (e) {
      _requireCurrent(epoch);
      if (e.isNotFound) {
        _remove(job);
        _requireCurrent(epoch);
        return null;
      }
      return job;
    } on Object {
      _requireCurrent(epoch);
      return job;
    }
  }

  /// The names of the profiles a new job can go to. Empty when the server
  /// has none to tell apart or cannot say.
  /// Rejects with [StateError] when activity is suspended or retired.
  Future<List<String>> profileNames() async {
    final epoch = _activityEpoch;
    _requireCurrent(epoch);
    try {
      final overview = await profiles?.load();
      _requireCurrent(epoch);
      return [
        for (final p in overview?.profiles ?? const <HermesProfile>[]) p.name,
      ];
    } on Object {
      _requireCurrent(epoch);
      return const [];
    }
  }

  /// A job the user asked to see from outside the destination, such as by
  /// tapping its notification. The screen takes it and shows the job. An
  /// empty id only asks for the list.
  ({String id, String? profile})? _openRequest;

  void requestOpen(String id, {String? profile}) {
    if (!_canWork) return;
    _openRequest = (id: id, profile: profile);
    notifyListeners();
  }

  ({String id, String? profile})? takeOpenRequest() {
    if (!_canWork) return null;
    final request = _openRequest;
    _openRequest = null;
    return request;
  }

  /// The job [id] of [profile], from the list or, when it is not on it, from
  /// the server. Null when the server no longer has it.
  /// Rejects with [StateError] when activity is suspended or retired.
  Future<CronJob?> findJob(String id, {String? profile}) async {
    final epoch = _activityEpoch;
    _requireCurrent(epoch);
    final known = _jobs
        .where((j) => j.id == id && (profile == null || j.profile == profile))
        .firstOrNull;
    if (known != null) return known;
    try {
      final job = await repository.getJob(id, profile: profile);
      _requireCurrent(epoch);
      return job;
    } on CronException catch (e) {
      _requireCurrent(epoch);
      if (e.isNotFound) return null;
      rethrow;
    } on Object {
      _requireCurrent(epoch);
      rethrow;
    }
  }

  /// Puts a job that was just created or changed on screen and selects it.
  /// A job in another profile than the one listed widens the list to every
  /// profile, or it would seem to have vanished.
  void jobSaved(CronJob job) {
    final epoch = _activityEpoch;
    if (!_currentActivity(epoch)) return;
    _selectedKey = job.key;
    if (_jobs.any((j) => j.key == job.key)) {
      _replace(job);
    } else {
      _jobs = [..._jobs, job];
      notifyListeners();
    }
    if (!_currentActivity(epoch)) return;
    final elsewhere =
        !_allProfiles &&
        _activeProfile != null &&
        job.profile != null &&
        job.profile != _activeProfile;
    if (elsewhere) {
      _setScope(true);
    } else {
      refresh();
    }
  }

  /// Reads [job]'s run history, rejecting with [StateError] while suspended
  /// or when activity retires the result.
  Future<List<CronRun>> loadRuns(CronJob job, {int limit = 20}) async {
    final epoch = _activityEpoch;
    _requireCurrent(epoch);
    try {
      final runs = await repository.listRuns(
        job.id,
        profile: job.profile,
        limit: limit,
      );
      _requireCurrent(epoch);
      return runs;
    } on Object {
      _requireCurrent(epoch);
      rethrow;
    }
  }

  void _replace(CronJob job) {
    _jobs = [for (final j in _jobs) j.key == job.key ? job : j];
    notifyListeners();
  }

  void _remove(CronJob job) {
    _jobs = [
      for (final j in _jobs)
        if (j.key != job.key) j,
    ];
    if (_selectedKey == job.key) _selectedKey = null;
    notifyListeners();
  }

  /// Forgets what was loaded, for when the destination goes away.
  void reset() {
    _activityEpoch++;
    _generation++;
    _started = false;
    _jobs = const [];
    _loaded = false;
    _loading = false;
    _error = null;
    _selectedKey = null;
    _pending.clear();
    notifyListeners();
  }

  /// A call the user made can answer after the destination went away and
  /// the controller was disposed; it must not notify then.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    removeListener(_syncInvalidation);
    _changes?.controller.removeListener(_invalidationStateChanged);
    _changes?.dispose();
    _disposed = true;
    _activityEpoch++;
    activity?.removeListener(_activityChanged);
    _timer?.cancel();
    super.dispose();
  }
}
