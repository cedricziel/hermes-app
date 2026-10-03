import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import 'chat_models.dart';

enum ThreadSearchStatus { idle, loading, done, failed }

/// The sidebar's session search: what was typed, and the chats found for it.
/// It searches once typing pauses for [debounce], and only the answer to the
/// latest query is kept.
class ThreadSearch extends ChangeNotifier with SafeNotifier {
  ThreadSearch(this._search, {this.debounce = defaultDebounce});

  static const defaultDebounce = Duration(milliseconds: 300);

  final Duration debounce;

  final Future<List<ThreadSearchHit>> Function(String query) _search;

  String _query = '';
  String get query => _query;

  ThreadSearchStatus _status = ThreadSearchStatus.idle;
  ThreadSearchStatus get status => _status;

  List<ThreadSearchHit> _hits = const [];
  List<ThreadSearchHit> get hits => _hits;

  Timer? _timer;
  int _generation = 0;

  void update(String query) {
    if (query == _query) return;
    final same = query.trim() == _query.trim();
    _query = query;
    if (same) return notifyListeners();
    _timer?.cancel();
    final generation = ++_generation;
    if (query.trim().isEmpty) {
      _hits = const [];
      _status = ThreadSearchStatus.idle;
    } else {
      _status = ThreadSearchStatus.loading;
      _timer = Timer(debounce, () => _run(query, generation));
    }
    notifyListeners();
  }

  void clear() => update('');

  Future<void> _run(String query, int generation) async {
    try {
      final hits = await _search(query);
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
