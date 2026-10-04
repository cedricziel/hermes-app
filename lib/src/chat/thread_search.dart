import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/safe_notifier.dart';
import 'chat_models.dart';

enum ThreadSearchStatus { idle, loading, done, failed }

/// Where a search looks: the active profile's chats, or every profile's.
enum ThreadSearchScope { profile, allProfiles }

const _recentKey = 'hermes.recent_searches';
const _recentLimit = 5;

/// The sidebar's session search: what was typed, and the chats found for it.
/// It searches once typing pauses for [debounce], and only the answer to the
/// latest query is kept.
///
/// With [searchAll] the search can also look through every profile. A Mac
/// window [begin]s a search from its toolbar and [end]s it, and shows the
/// queries it [remember]ed while the field is empty.
class ThreadSearch extends ChangeNotifier with SafeNotifier {
  ThreadSearch(
    this._search, {
    this.debounce = defaultDebounce,
    this._searchAll,
    this._recentStore,
  });

  static const defaultDebounce = Duration(milliseconds: 300);

  final Duration debounce;

  final Future<List<ThreadSearchHit>> Function(String query) _search;
  final Future<List<ThreadSearchHit>> Function(String query)? _searchAll;
  final SharedPreferencesAsync? _recentStore;

  String _query = '';
  String get query => _query;

  ThreadSearchStatus _status = ThreadSearchStatus.idle;
  ThreadSearchStatus get status => _status;

  List<ThreadSearchHit> _hits = const [];
  List<ThreadSearchHit> get hits => _hits;

  ThreadSearchScope _scope = ThreadSearchScope.profile;
  ThreadSearchScope get scope => _scope;

  bool get canSearchAllProfiles => _searchAll != null;

  bool _active = false;

  /// Whether a search is open, even before anything is typed.
  bool get active => _active;

  List<String> _recent = const [];

  /// The latest queries the user searched for, newest first.
  List<String> get recent => _recent;
  bool _recentTouched = false;
  bool _recentLoaded = false;

  Timer? _timer;
  int _generation = 0;

  void update(String query) {
    if (query == _query) return;
    final same = query.trim() == _query.trim();
    _query = query;
    if (same) return notifyListeners();
    _start(debounce);
  }

  void setScope(ThreadSearchScope scope) {
    if (scope == _scope || !canSearchAllProfiles) return;
    _scope = scope;
    _start(Duration.zero);
  }

  void _start(Duration delay) {
    _timer?.cancel();
    final generation = ++_generation;
    final query = _query;
    if (query.trim().isEmpty) {
      _hits = const [];
      _status = ThreadSearchStatus.idle;
    } else {
      _status = ThreadSearchStatus.loading;
      _timer = Timer(delay, () => _run(query, generation));
    }
    notifyListeners();
  }

  void clear() => update('');

  void begin() {
    if (_active) return;
    _active = true;
    if (!_recentLoaded) {
      _recentLoaded = true;
      _loadRecent();
    }
    notifyListeners();
  }

  /// Closes the search and forgets what was typed.
  void end() {
    _active = false;
    if (_query.isEmpty) return notifyListeners();
    clear();
  }

  /// Keeps [query] at the top of [recent].
  void remember(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _recentTouched = true;
    _recent = [
      trimmed,
      ..._recent.where((q) => q != trimmed),
    ].take(_recentLimit).toList();
    notifyListeners();
    _recentStore?.setStringList(_recentKey, _recent).ignore();
  }

  Future<void> _loadRecent() async {
    final store = _recentStore;
    if (store == null) return;
    try {
      final stored = await store.getStringList(_recentKey);
      if (stored == null || _recentTouched || disposed) return;
      _recent = stored.take(_recentLimit).toList();
      notifyListeners();
    } on Object {
      // No stored searches is the same as none.
    }
  }

  Future<void> _run(String query, int generation) async {
    try {
      final search = _scope == ThreadSearchScope.allProfiles
          ? _searchAll!
          : _search;
      final hits = await search(query);
      if (generation != _generation) return;
      _hits = hits;
      _status = ThreadSearchStatus.done;
    } on Object {
      if (generation != _generation) return;
      _hits = const [];
      _status = ThreadSearchStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
