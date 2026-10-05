import 'dart:async';

import 'bot_mode_roster_repository.dart';

/// Durable Bot Chat root and its current compression tip. REST and resume
/// calls use [storedId] with [profile]; gateway events use the resumed runtime.
class BotModeChat {
  const BotModeChat({
    required this.profile,
    required this.rootId,
    required this.storedId,
  });

  final String profile;
  final String rootId;
  final String storedId;
}

/// Resolves server-owned canonical conversations over the shared gateway.
/// No prompt is sent while materializing a title or adopting another creator.
class BotModeChatRepository {
  BotModeChatRepository(this._request);

  final BotModeRequest _request;
  final _owners = <String, Future<void>>{};
  final _drafts = <String, (String, String)>{};
  static const title = 'Bot Chat';

  Future<BotModeChat> open(BotModeBot bot) async {
    final previous = _owners[bot.identity] ?? Future<void>.value();
    final operation = previous.then((_) => _open(bot));
    final tail = operation.then<void>((_) {}, onError: (Object _) {});
    _owners[bot.identity] = tail;
    try {
      return await operation;
    } finally {
      if (identical(_owners[bot.identity], tail)) {
        unawaited(_owners.remove(bot.identity));
      }
    }
  }

  Future<BotModeChat?> _lookup(String profile) async {
    final result = await _request('session.list', {
      'profile': profile,
      'title': title,
      'include_hidden': true,
      'limit': 200,
    });
    final rows = result['sessions'];
    if (rows is! List) {
      throw StateError('The server did not confirm the Bot Chat registry.');
    }
    for (final row in rows) {
      if (row is! Map || row['title'] != title) continue;
      final id = row['id'];
      if (id is! String || id.isEmpty) {
        throw StateError('The canonical Bot Chat has no stored identity.');
      }
      final tip = row['resolved_id'];
      return BotModeChat(
        profile: profile,
        rootId: id,
        storedId: tip is String && tip.isNotEmpty ? tip : id,
      );
    }
    // An exact-title query returning unrelated rows cannot establish absence.
    if (rows.isNotEmpty) {
      throw StateError('The server did not confirm exact Bot Chat lookup.');
    }
    return null;
  }

  Future<BotModeChat> _open(BotModeBot bot) async {
    final existing = await _lookup(bot.name);
    if (existing != null) {
      _drafts.remove(bot.identity);
      return existing;
    }
    if (bot.canonicalSessionId != null) {
      throw StateError(
        'The roster identifies a Bot Chat that could not be '
        'resolved. Refresh the roster and retry.',
      );
    }
    try {
      var draft = _drafts[bot.identity];
      if (draft == null) {
        final created = await _request('session.create', {
          'profile': bot.name,
          'title': title,
          'hidden': true,
          'follow_profile_config': true,
        });
        final runtime = created['session_id'];
        final stored = created['stored_session_id'];
        if (runtime is! String ||
            runtime.isEmpty ||
            stored is! String ||
            stored.isEmpty) {
          throw StateError('The server did not confirm Bot Chat creation.');
        }
        _drafts[bot.identity] = draft = (runtime, stored);
      }
      final named = await _request('session.title', {
        'session_id': draft.$1,
        'title': title,
      });
      if (named['pending'] != true && named['title'] == title) {
        _drafts.remove(bot.identity);
        return BotModeChat(
          profile: bot.name,
          rootId: draft.$2,
          storedId: draft.$2,
        );
      }
    } on Object {
      final winner = await _lookup(bot.name);
      if (winner != null) {
        _drafts.remove(bot.identity);
        return winner;
      }
      rethrow;
    }
    final materialized = await _lookup(bot.name);
    if (materialized != null) {
      _drafts.remove(bot.identity);
      return materialized;
    }
    throw StateError(
      'The Bot Chat title is not persisted yet. Retry after '
      'the server supports title materialization.',
    );
  }
}
