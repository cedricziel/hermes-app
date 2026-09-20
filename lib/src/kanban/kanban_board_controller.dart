import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';

import 'kanban_models.dart';
import 'kanban_repository.dart';

/// Opens the plugin's event stream for [board], resuming after event [since].
typedef KanbanEventsConnect = Future<StreamChannel<String>> Function({
  required int since,
  String? board,
});

/// The state of the Kanban board screen: the loaded board, its filters, and
/// the live event stream that keeps it current.
///
/// An event only says that the board changed, so each burst of events causes
/// one refetch. The stream resumes after the newest event the snapshot
/// includes, so nothing is missed across a reconnect.
class KanbanBoardController extends ChangeNotifier {
  KanbanBoardController({
    required this.repository,
    required this.connect,
    this.debounce = const Duration(milliseconds: 300),
    this.reconnectDelay = _defaultReconnectDelay,
  });

  final KanbanRepository repository;
  final KanbanEventsConnect connect;
  final Duration debounce;
  final Duration Function(int attempt) reconnectDelay;

  static Duration _defaultReconnectDelay(int attempt) =>
      Duration(seconds: math.min(30, 1 << math.min(attempt, 5)));

  KanbanBoard? _board;
  List<KanbanBoardInfo> _boards = const [];
  Object? _error;
  bool _loading = false;
  bool _live = false;
  bool _disposed = false;

  String? _boardSlug;
  String? _tenant;
  String? _assignee;
  String _query = '';
  bool _includeArchived = false;

  final _selected = <String>{};

  int _generation = 0;
  int _cursor = 0;
  StreamSubscription<String>? _events;
  Timer? _refreshTimer;
  Timer? _reconnectTimer;

  KanbanBoard? get board => _board;
  List<KanbanBoardInfo> get boards => _boards;
  Object? get error => _error;
  bool get loading => _loading;

  /// Whether the event stream is connected.
  bool get live => _live;

  String? get boardSlug => _boardSlug;
  String? get tenant => _tenant;
  String? get assignee => _assignee;
  String get query => _query;
  bool get includeArchived => _includeArchived;

  /// The plugin answered 404: it was switched off after the app saw it on.
  bool get unavailable =>
      _error is DioException &&
      (_error as DioException).response?.statusCode == 404;

  /// The board's columns after the search and assignee filter.
  List<KanbanColumn> get columns {
    final board = _board;
    if (board == null) return const [];
    final needle = _query.trim().toLowerCase();
    bool keep(KanbanTask t) =>
        (_assignee == null || t.assignee == _assignee) &&
        (needle.isEmpty ||
            t.title.toLowerCase().contains(needle) ||
            t.id.toLowerCase().contains(needle) ||
            (t.body?.toLowerCase().contains(needle) ?? false));
    return [
      for (final c in board.columns)
        KanbanColumn(name: c.name, tasks: c.tasks.where(keep).toList()),
    ];
  }

  /// Ids picked for a bulk change; empty outside selection mode.
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get selecting => _selecting;
  bool _selecting = false;

  void startSelecting([String? first]) {
    _selecting = true;
    if (first != null) _selected.add(first);
    notifyListeners();
  }

  void toggleSelected(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void stopSelecting() {
    _selecting = false;
    _selected.clear();
    notifyListeners();
  }

  Future<void> start() async {
    await Future.wait([_loadBoards(), refresh()]);
  }

  Future<void> _loadBoards() async {
    try {
      final boards = await repository.listBoards();
      if (_disposed) return;
      _boards = boards;
      _boardSlug ??= boards.where((b) => b.isCurrent).firstOrNull?.slug;
      notifyListeners();
    } catch (_) {
      // The switcher is optional; the board still loads without it.
    }
  }

  /// Fetches the board now and (re)starts the event stream from it.
  Future<void> refresh() async {
    final generation = _generation;
    _loading = _board == null;
    notifyListeners();
    try {
      final board = await repository.loadBoard(
        board: _boardSlug,
        tenant: _tenant,
        includeArchived: _includeArchived,
      );
      if (_disposed || generation != _generation) return;
      _board = board;
      _error = null;
      final ids = {
        for (final c in board.columns)
          for (final t in c.tasks) t.id,
      };
      _selected.retainAll(ids);
      _cursor = math.max(_cursor, board.latestEventId);
      if (_events == null) _listen();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _error = e;
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(debounce, refresh);
  }

  Future<void> _listen({int attempt = 0}) async {
    final generation = _generation;
    _reconnectTimer?.cancel();
    void retry() {
      if (_disposed || generation != _generation) return;
      _events = null;
      _setLive(false);
      _reconnectTimer = Timer(reconnectDelay(attempt), () {
        if (!_disposed && generation == _generation) {
          _listen(attempt: attempt + 1);
        }
      });
    }

    try {
      final channel = await connect(since: _cursor, board: _boardSlug);
      if (_disposed || generation != _generation) {
        unawaited(channel.sink.close());
        return;
      }
      _setLive(true);
      _events = channel.stream.listen(
        (frame) {
          attempt = 0;
          if (_absorb(frame)) _scheduleRefresh();
        },
        onError: (_) => retry(),
        onDone: retry,
        cancelOnError: true,
      );
    } catch (_) {
      retry();
    }
  }

  /// Advances the cursor; whether the frame carried any events.
  bool _absorb(String frame) {
    try {
      final data = jsonDecode(frame);
      if (data is! Map) return false;
      final cursor = data['cursor'];
      if (cursor is num) _cursor = math.max(_cursor, cursor.toInt());
      final events = data['events'];
      return events is List && events.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _setLive(bool live) {
    if (_live == live || _disposed) return;
    _live = live;
    notifyListeners();
  }

  Future<void> _restart() async {
    _generation++;
    _refreshTimer?.cancel();
    _reconnectTimer?.cancel();
    await _events?.cancel();
    _events = null;
    _live = false;
    _cursor = 0;
    _selected.clear();
    _selecting = false;
    _board = null;
    _error = null;
    await refresh();
  }

  Future<void> selectBoard(String slug) {
    _boardSlug = slug;
    return _restart();
  }

  Future<void> setTenant(String? tenant) {
    _tenant = tenant;
    return _restart();
  }

  Future<void> setIncludeArchived(bool value) {
    _includeArchived = value;
    return _restart();
  }

  void setAssignee(String? assignee) {
    _assignee = assignee;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _events?.cancel();
    super.dispose();
  }
}
