import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../profiles/hermes_profiles_repository.dart';
import 'hermes_skills_repository.dart';

enum SkillsStatus { loading, ready, failed, unsupported }

enum SkillFilter { all, enabled, hub, bundled, agent }

class SkillGroup {
  const SkillGroup(this.category, this.skills);

  final String category;
  final List<HermesSkill> skills;
}

/// State of the Skills page: the skills of one profile, how they are
/// narrowed, and the writes made to them.
///
/// The profile is a parameter of every call. Picking one here never switches
/// the profile the chat uses.
class SkillsController extends ChangeNotifier {
  SkillsController({
    required this.repository,
    required String? chatProfile,
    this.profiles,
    this.events = noopAppEventLogger,
  }) : _profile = chatProfile;

  static const otherCategory = 'Other';

  final HermesSkillsRepository repository;
  final HermesProfilesRepository? profiles;
  final AppEventLogger events;

  SkillsStatus _status = SkillsStatus.loading;
  List<HermesSkill> _skills = const [];
  List<HermesProfile> _profiles = const [];
  String? _profile;
  String _query = '';
  SkillFilter _filter = SkillFilter.all;
  int _generation = 0;
  final _toggles = <String, Future<bool>>{};

  SkillsStatus get status => _status;
  String? get profile => _profile;
  String get query => _query;
  SkillFilter get filter => _filter;
  bool get hasSkills => _skills.isNotEmpty;
  bool get hasHubSkills => _skills.any((s) => s.source == SkillSource.hub);

  /// The profiles to pick from; empty when they could not be loaded.
  List<HermesProfile> get availableProfiles => _profiles;

  HermesSkill? skill(String name) {
    for (final s in _skills) {
      if (s.name == name) return s;
    }
    return null;
  }

  List<SkillGroup> get groups {
    final needle = _query.trim().toLowerCase();
    final byCategory = <String, List<HermesSkill>>{};
    for (final s in _skills) {
      if (!_matchesFilter(s)) continue;
      if (needle.isNotEmpty &&
          !s.name.toLowerCase().contains(needle) &&
          !s.description.toLowerCase().contains(needle) &&
          !s.category.toLowerCase().contains(needle)) {
        continue;
      }
      (byCategory[s.category.isEmpty ? otherCategory : s.category] ??= []).add(
        s,
      );
    }
    final names = byCategory.keys.toList()
      ..sort((a, b) {
        if (a == otherCategory) return 1;
        if (b == otherCategory) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return [
      for (final name in names)
        SkillGroup(
          name,
          byCategory[name]!..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
        ),
    ];
  }

  bool _matchesFilter(HermesSkill s) => switch (_filter) {
    SkillFilter.all => true,
    SkillFilter.enabled => s.enabled,
    SkillFilter.hub => s.source == SkillSource.hub,
    SkillFilter.bundled => s.source == SkillSource.bundled,
    SkillFilter.agent => s.source == SkillSource.agent,
  };

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setFilter(SkillFilter value) {
    _filter = value;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _filter = SkillFilter.all;
    notifyListeners();
  }

  /// Loads the skills of the selected profile. A reply that arrives after the
  /// profile changed is dropped. [quiet] keeps the list on screen meanwhile.
  Future<void> load({bool quiet = false}) async {
    final generation = ++_generation;
    if (!quiet) {
      _status = SkillsStatus.loading;
      notifyListeners();
    }
    try {
      final skills = await repository.list(profile: _profile);
      if (generation != _generation) return;
      _skills = skills;
      _status = SkillsStatus.ready;
    } on SkillsUnsupported {
      if (generation != _generation) return;
      _status = SkillsStatus.unsupported;
    } on Object {
      if (generation != _generation) return;
      if (quiet && _status == SkillsStatus.ready) return;
      _status = SkillsStatus.failed;
    }
    notifyListeners();
  }

  Future<void> loadProfiles() async {
    try {
      final overview = await profiles?.load();
      if (overview == null) return;
      _profiles = overview.profiles;
    } on Object {
      _profiles = const [];
    }
    notifyListeners();
  }

  Future<void> selectProfile(String name) {
    if (name == _profile) return Future.value();
    _profile = name;
    _skills = const [];
    return load();
  }

  /// Switches a skill at once and tells the server; goes back and returns
  /// false when that fails. Taps on one skill are sent in the order made.
  Future<bool> toggle(String name, bool enabled) {
    final previous = skill(name)?.enabled;
    if (previous == null) return Future.value(false);
    final generation = _generation;
    _set(name, enabled);
    final done = (_toggles[name] ?? Future<bool>.value(true)).then((_) async {
      try {
        await repository.setEnabled(name, enabled, profile: _profile);
        _log('toggle', 'ok');
        return true;
      } on Object {
        _log('toggle', 'error');
        if (generation == _generation) _set(name, previous);
        return false;
      }
    });
    _toggles[name] = done;
    return done;
  }

  void _set(String name, bool enabled) {
    _skills = [
      for (final s in _skills)
        s.name == name ? s.copyWith(enabled: enabled) : s,
    ];
    notifyListeners();
  }

  /// Returns null on success, else a message fit to show the user.
  Future<String?> save(String name, String content) =>
      _write('save', () => repository.save(name, content, profile: _profile));

  Future<String?> create(String name, String content, {String? category}) =>
      _write(
        'create',
        () => repository.create(
          name,
          content,
          category: category,
          profile: _profile,
        ),
      );

  Future<String?> _write(String op, Future<void> Function() call) async {
    try {
      await call();
    } on SkillsRejected catch (e) {
      _log(op, 'rejected');
      return e.message;
    } on Object {
      _log(op, 'error');
      return 'Could not reach the server';
    }
    _log(op, 'ok');
    await load(quiet: true);
    return null;
  }

  /// Never carries a skill name or its text, and never breaks the write.
  void _log(String op, String result) {
    try {
      events('skills.write', {'op': op, 'result': result});
    } on Object {
      // Telemetry must not affect the app.
    }
  }
}
