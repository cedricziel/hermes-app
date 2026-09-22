import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../profiles/hermes_profiles_repository.dart';
import 'hermes_cron_repository.dart';
import 'schedule_models.dart';

/// Owns the job list behind the Schedules destination: which profile it
/// shows, the filter, refreshing, and the changes a user can make.
///
/// The phone list and the wide detail read the same instance, so they cannot
/// disagree about a job.
class SchedulesController extends ChangeNotifier {
  SchedulesController({
    required this.repository,
    this.profiles,
    this.refreshEvery = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final HermesCronRepository repository;
  final HermesProfilesRepository? profiles;
  final Duration refreshEvery;
  final DateTime Function() _now;

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
  Timer? _timer;
  bool _disposed = false;

  /// Jobs the user changed and whose answer is still awaited, so a refresh
  /// landing meanwhile does not undo the switch.
  final _pending = <String, CronJobState>{};

  DateTime get now => _now();
  bool get loading => _loading;
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

  set allProfiles(bool value) {
    if (_allProfiles == value) return;
    _allProfiles = value;
    notifyListeners();
    refresh();
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
    if (_active && _foreground && !_disposed) {
      _timer = Timer.periodic(refreshEvery, (_) => refresh());
    }
  }

  /// The profile to ask for: every one, the sticky active one, or null when
  /// the server has no profiles to tell apart. A failure to read the active
  /// profile throws, so a list is never shown unscoped by accident.
  Future<String?> _scope() async {
    if (_allProfiles) return 'all';
    if (_activeKnown) return _activeProfile;
    try {
      _activeProfile = (await profiles?.loadActive())?.active;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
      _activeProfile = null;
    }
    _activeKnown = true;
    return _activeProfile;
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    if (!_loaded) {
      _loading = true;
      notifyListeners();
    }
    try {
      final scope = await _scope();
      final jobs = await repository.listJobs(profile: scope);
      if (_disposed || generation != _generation) return;
      _jobs = [for (final job in jobs) _withPending(job)];
      _loaded = true;
      _loading = false;
      _error = null;
      if (_selectedKey != null && selected == null) _selectedKey = null;
    } on Object catch (e) {
      if (_disposed || generation != _generation) return;
      _loading = false;
      _error = _describe(e);
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
  Future<String?> setPaused(CronJob job, bool paused) async {
    final state = paused ? CronJobState.paused : CronJobState.scheduled;
    final before = _jobs;
    _pending[job.key] = state;
    _replace(job.copyWith(state: state));
    try {
      if (paused) {
        await repository.pause(job.id, profile: job.profile);
      } else {
        await repository.resume(job.id, profile: job.profile);
      }
      _pending.remove(job.key);
      await refresh();
      return null;
    } on Object catch (e) {
      _pending.remove(job.key);
      if (_disposed) return null;
      _jobs = before;
      notifyListeners();
      if (e is CronException && e.isNotFound) {
        _remove(job);
        return 'This task no longer exists';
      }
      return paused
          ? 'Could not pause “${job.title}”'
          : 'Could not resume “${job.title}”';
    }
  }

  /// Asks for one run of [job]. The run is not awaited. Null on success.
  Future<String?> runNow(CronJob job) async {
    try {
      await repository.trigger(job.id, profile: job.profile);
      return null;
    } on Object catch (e) {
      if (e is CronException && e.isNotFound) {
        _remove(job);
        return 'This task no longer exists';
      }
      return 'Could not start “${job.title}”';
    }
  }

  /// Deletes [job]. A job the server no longer has counts as deleted.
  Future<String?> delete(CronJob job) async {
    try {
      await repository.delete(job.id, profile: job.profile);
    } on Object catch (e) {
      if (!(e is CronException && e.isNotFound)) {
        return 'Could not delete “${job.title}”';
      }
    }
    _remove(job);
    return null;
  }

  /// Reads [job] again. A job that is gone is dropped and null is returned.
  Future<CronJob?> reload(CronJob job) async {
    try {
      final fresh = await repository.getJob(job.id, profile: job.profile);
      if (_disposed) return fresh;
      _replace(_withPending(fresh));
      return fresh;
    } on CronException catch (e) {
      if (e.isNotFound) {
        _remove(job);
        return null;
      }
      return job;
    } on Object {
      return job;
    }
  }

  /// The names of the profiles a new job can go to. Empty when the server
  /// has none to tell apart or cannot say.
  Future<List<String>> profileNames() async {
    try {
      final overview = await profiles?.load();
      return [
        for (final p in overview?.profiles ?? const <HermesProfile>[]) p.name,
      ];
    } on Object {
      return const [];
    }
  }

  /// A job the user asked to see from outside the destination, such as by
  /// tapping its notification. The screen takes it and shows the job. An
  /// empty id only asks for the list.
  ({String id, String? profile})? _openRequest;

  void requestOpen(String id, {String? profile}) {
    _openRequest = (id: id, profile: profile);
    notifyListeners();
  }

  ({String id, String? profile})? takeOpenRequest() {
    final request = _openRequest;
    _openRequest = null;
    return request;
  }

  /// The job [id] of [profile], from the list or, when it is not on it, from
  /// the server. Null when the server no longer has it.
  Future<CronJob?> findJob(String id, {String? profile}) async {
    final known = _jobs
        .where((j) => j.id == id && (profile == null || j.profile == profile))
        .firstOrNull;
    if (known != null) return known;
    try {
      return await repository.getJob(id, profile: profile);
    } on CronException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Puts a job that was just created or changed on screen and selects it.
  /// A job in another profile than the one listed widens the list to every
  /// profile, or it would seem to have vanished.
  void jobSaved(CronJob job) {
    _selectedKey = job.key;
    if (_jobs.any((j) => j.key == job.key)) {
      _replace(job);
    } else {
      _jobs = [..._jobs, job];
      notifyListeners();
    }
    final elsewhere =
        !_allProfiles &&
        _activeProfile != null &&
        job.profile != null &&
        job.profile != _activeProfile;
    if (elsewhere) {
      allProfiles = true;
    } else {
      refresh();
    }
  }

  Future<List<CronRun>> loadRuns(CronJob job, {int limit = 20}) =>
      repository.listRuns(job.id, profile: job.profile, limit: limit);

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
    _generation++;
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
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
