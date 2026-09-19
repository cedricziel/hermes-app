import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'chat_models.dart';
import 'hermes_chat_repository.dart';

/// Rename, pin, archive and delete for the sidebar's server-backed threads,
/// plus loading further pages of the list.
///
/// It edits the thread list [threads] returns in place and calls [changed]
/// after each edit. Renames and pins show at once and are undone if the
/// dashboard refuses; archiving and deleting take the thread out only once
/// the dashboard has, so a refusal leaves nothing to restore. Failures are
/// passed to [report] and never thrown.
class ThreadHousekeeping {
  ThreadHousekeeping({
    required this.repository,
    required this.threads,
    required this.profile,
    required this.changed,
    required this.report,
    required this.removed,
  });

  final HermesChatRepository repository;
  final List<ChatThread> Function() threads;

  /// The profile the threads were listed under, which the dashboard needs to
  /// find their sessions again.
  final String? Function() profile;
  final VoidCallback changed;
  final ValueChanged<String> report;

  /// A thread left the list because it was archived or deleted.
  final ValueChanged<ChatThread> removed;

  final _busy = <String>{};
  int _nextOffset = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _generation = 0;

  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  /// Starts over from [first]: returns its threads in sidebar order and
  /// forgets any earlier paging.
  List<ChatThread> begin(ThreadPage first) {
    _generation++;
    _busy.clear();
    _loadingMore = false;
    _nextOffset = first.nextOffset;
    _hasMore = first.hasMore;
    return _sidebarOrder(first.threads);
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    final generation = _generation;
    _loadingMore = true;
    changed();
    try {
      final page = await repository.loadThreadPage(
        offset: _nextOffset,
        profile: profile(),
      );
      if (generation != _generation) return;
      final list = threads();
      final known = {for (final thread in list) thread.id};
      _nextOffset = page.nextOffset;
      _hasMore = page.hasMore;
      list.replaceRange(
        0,
        list.length,
        _sidebarOrder([
          ...list,
          for (final thread in page.threads)
            if (known.add(thread.id)) thread,
        ]),
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      report(_failure('Could not load more chats', error));
    }
    _loadingMore = false;
    changed();
  }

  Future<void> rename(ChatThread thread, String title) =>
      _guarded(thread, (profile) async {
        final previous = thread.title;
        thread.title = title;
        changed();
        try {
          thread.title = await repository.renameThread(
            thread.id,
            title,
            profile: profile,
          );
        } on Object catch (error) {
          thread.title = previous;
          report(_failure('Could not rename this chat', error));
        }
      });

  Future<void> setPinned(ChatThread thread, bool pinned) =>
      _guarded(thread, (profile) async {
        thread.pinned = pinned;
        _sort();
        changed();
        try {
          await repository.setPinned(thread.id, pinned, profile: profile);
        } on Object catch (error) {
          thread.pinned = !pinned;
          _sort();
          report(
            _failure(
              pinned ? 'Could not pin this chat' : 'Could not unpin this chat',
              error,
            ),
          );
        }
      });

  Future<void> archive(ChatThread thread) => _remove(
    thread,
    (profile) => repository.archiveThread(thread.id, profile: profile),
    'Could not archive this chat',
  );

  Future<void> delete(ChatThread thread) => _remove(
    thread,
    (profile) => repository.deleteThread(thread.id, profile: profile),
    'Could not delete this chat',
  );

  Future<void> _remove(
    ChatThread thread,
    Future<void> Function(String? profile) call,
    String failure,
  ) => _guarded(thread, (profile) async {
    try {
      await call(profile);
    } on Object catch (error) {
      report(_failure(failure, error));
      return;
    }
    threads().remove(thread);
    // Everything after it moved up a place, so the next page starts sooner.
    if (_nextOffset > 0) _nextOffset--;
    removed(thread);
  });

  /// Runs one action per thread at a time, under the profile in force when it
  /// starts, then tells the screen.
  Future<void> _guarded(
    ChatThread thread,
    Future<void> Function(String? profile) action,
  ) async {
    final generation = _generation;
    if (!_busy.add(thread.id)) return;
    try {
      await action(profile());
    } finally {
      if (generation == _generation) _busy.remove(thread.id);
    }
    changed();
  }

  void _sort() {
    final list = threads();
    list.replaceRange(0, list.length, _sidebarOrder(list));
  }

  /// Local drafts stay on top, then pinned threads, then the rest. Server
  /// threads run most recently active first within their group.
  static List<ChatThread> _sidebarOrder(Iterable<ChatThread> threads) {
    int rank(ChatThread t) => !t.remote ? 0 : (t.pinned ? 1 : 2);
    final indexed = threads.toList().indexed.toList()
      ..sort((a, b) {
        final (i, x) = a;
        final (j, y) = b;
        final byRank = rank(x).compareTo(rank(y));
        if (byRank != 0) return byRank;
        final byRecency = rank(x) == 0 ? 0 : y.updatedAt.compareTo(x.updatedAt);
        return byRecency != 0 ? byRecency : i.compareTo(j);
      });
    return [for (final (_, thread) in indexed) thread];
  }

  /// A refusal the dashboard explains (a title already taken, say) carries
  /// that explanation along.
  static String _failure(String what, Object error) {
    if (error is DioException && error.response?.statusCode == 400) {
      if (error.response?.data case {'detail': final String detail}) {
        return '$what: $detail';
      }
    }
    return what;
  }
}
