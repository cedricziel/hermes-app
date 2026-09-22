import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../core/safe_notifier.dart';
import 'hermes_skills_hub_repository.dart';
import 'hermes_skills_repository.dart';
import 'skill_job.dart';
import 'skills_controller.dart';

enum HubStatus { loading, ready, failed, unsupported }

/// Discovering skills on the hub, and running the jobs that change what is
/// installed. Works on the profile [skills] has selected.
///
/// Install is held here, not in a widget: it goes ahead only with a scan of
/// that very skill whose policy allows it, so no screen can skip the check.
class SkillsHubController extends ChangeNotifier with SafeNotifier {
  SkillsHubController({
    required this.repository,
    required this.skills,
    this.events = noopAppEventLogger,
    this.debounce = const Duration(milliseconds: 400),
    this.newJob = _defaultJob,
  });

  static const allSources = 'all';

  final HermesSkillsHubRepository repository;
  final SkillsController skills;
  final AppEventLogger events;
  final Duration debounce;
  final SkillJob Function(
    String title,
    Future<StartedJob> Function() start,
    Future<JobStatus?> Function(String) status,
  )
  newJob;

  HubStatus _status = HubStatus.loading;
  HubOverview _overview = const HubOverview();
  HubSearchResult? _results;
  bool _searching = false;
  bool _searchFailed = false;
  String _query = '';
  String _source = allSources;
  int _generation = 0;
  Timer? _timer;
  SkillJob? _job;

  /// Whether a job sheet is on screen, which says the outcome itself.
  bool sheetOpen = false;

  static SkillJob _defaultJob(
    String title,
    Future<StartedJob> Function() start,
    Future<JobStatus?> Function(String) status,
  ) => SkillJob(title: title, start: start, status: status);

  HubStatus get status => _status;
  List<HubSource> get sources => _overview.sources;
  String get query => _query;
  String get source => _source;
  bool get searching => _searching;
  bool get searchFailed => _searchFailed;
  List<String> get timedOut => _results?.timedOut ?? const [];
  SkillJob? get job => _job;
  bool get busy => _job?.running ?? false;

  bool get isSearch => _query.trim().isNotEmpty;

  List<HubSkill> get featured =>
      isSearch ? const [] : _filtered(_overview.featured);

  List<HubSkill> get official {
    if (isSearch) return const [];
    final shown = {for (final s in featured) s.identifier};
    return _filtered(_overview.official)
        .where((s) => !shown.contains(s.identifier))
        .toList();
  }

  List<HubSkill> get results => _results?.results ?? const [];

  List<HubSkill> _filtered(List<HubSkill> all) => _source == allSources
      ? all
      : all.where((s) => s.source == _source).toList();

  Future<void> load({bool quiet = false}) async {
    final generation = ++_generation;
    if (!quiet) {
      _status = HubStatus.loading;
      notifyListeners();
    }
    try {
      final overview = await repository.overview(profile: skills.profile);
      if (generation != _generation) return;
      _overview = overview;
      _status = HubStatus.ready;
      if (isSearch) unawaited(_search());
    } on SkillsUnsupported {
      if (generation != _generation) return;
      _status = HubStatus.unsupported;
    } on Object {
      if (generation != _generation) return;
      if (quiet && _status == HubStatus.ready) return;
      _status = HubStatus.failed;
    }
    notifyListeners();
  }

  /// The profile changed: what was shown belongs to the other one.
  Future<void> reset() {
    _results = null;
    _overview = const HubOverview();
    return load();
  }

  void setQuery(String value) {
    _query = value;
    _timer?.cancel();
    if (!isSearch) {
      _generation++;
      _results = null;
      _searching = false;
      _searchFailed = false;
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    _timer = Timer(debounce, _search);
  }

  void setSource(String id) {
    _source = id;
    notifyListeners();
    if (isSearch) {
      _timer?.cancel();
      unawaited(_search());
    }
  }

  Future<void> retrySearch() => _search();

  Future<void> _search() async {
    final generation = ++_generation;
    final text = _query.trim();
    if (text.isEmpty) return;
    _searching = true;
    _searchFailed = false;
    notifyListeners();
    try {
      final found = await repository.search(
        text,
        source: _source == allSources ? null : _source,
        profile: skills.profile,
      );
      if (generation != _generation) return;
      _results = found;
    } on Object {
      if (generation != _generation) return;
      _results = null;
      _searchFailed = true;
    }
    _searching = false;
    notifyListeners();
  }

  bool isInstalled(HubSkill skill) =>
      skill.installed ||
      _overview.installed.contains(skill.identifier) ||
      (_results?.installed.contains(skill.identifier) ?? false);

  /// The scan permits [scan]'s skill to be installed, given whether the user
  /// has confirmed a skill the server wants confirmation for.
  static bool permits(
    HubScan? scan,
    String identifier, {
    bool confirmed = false,
  }) {
    if (scan == null || scan.identifier != identifier) return false;
    return switch (scan.policy) {
      InstallPolicy.allow => true,
      InstallPolicy.ask => confirmed,
      InstallPolicy.block => false,
    };
  }

  /// Starts installing [skill]; null, and nothing sent, unless the scan
  /// permits it and no other job is running.
  SkillJob? install(HubSkill skill, HubScan? scan, {bool confirmed = false}) {
    if (busy || !permits(scan, skill.identifier, confirmed: confirmed)) {
      return null;
    }
    return _run(
      'Installing ${skill.name}',
      'install',
      () => repository.install(skill.identifier, profile: skills.profile),
      {
        'source': skill.source,
        'trust_level': skill.trustLevel,
        'policy': scan!.policy.name,
      },
    );
  }

  SkillJob? uninstall(String name) {
    if (busy) return null;
    return _run(
      'Uninstalling $name',
      'uninstall',
      () => repository.uninstall(name, profile: skills.profile),
    );
  }

  SkillJob? update() {
    if (busy) return null;
    return _run(
      'Updating hub skills',
      'update',
      () => repository.update(profile: skills.profile),
    );
  }

  SkillJob _run(
    String title,
    String op,
    Future<StartedJob> Function() start, [
    Map<String, Object> extra = const {},
  ]) {
    final job = newJob(title, start, repository.status);
    _job = job;
    notifyListeners();
    unawaited(_follow(job, op, extra));
    return job;
  }

  Future<void> _follow(
    SkillJob job,
    String op,
    Map<String, Object> extra,
  ) async {
    await job.run();
    if (disposed) return;
    _log({
      'op': op,
      ...extra,
      'result': switch (job.state) {
        JobState.succeeded => 'ok',
        JobState.failed => 'failed',
        _ => 'unknown',
      },
    });
    if (skills.disposed) return;
    await Future.wait([skills.load(quiet: true), load(quiet: true)]);
    notifyListeners();
  }

  /// Forgets a finished job once its result has been shown.
  void dismissJob() {
    if (_job == null || _job!.running) return;
    _job = null;
    notifyListeners();
  }

  /// Never carries an identifier, a name, search text or a log line, and never
  /// breaks the job.
  void _log(Map<String, Object> attributes) {
    try {
      events('skills.job', attributes);
    } on Object {
      // Telemetry must not affect the app.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _job?.dispose();
    super.dispose();
  }
}
