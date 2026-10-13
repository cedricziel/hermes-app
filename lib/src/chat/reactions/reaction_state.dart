import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../telemetry/breadcrumbs.dart';

enum SessionAcknowledgement {
  vibe;

  static SessionAcknowledgement? decode(Object? value) =>
      value is Map && value['kind'] == 'vibe' ? vibe : null;
}

class ReportedReaction {
  const ReportedReaction({
    required this.emoji,
    required this.author,
    this.at,
    this.seen,
  });
  final String emoji, author;
  final num? at;
  final bool? seen;
  static ReportedReaction? decode(Object? value) {
    if (value is! Map ||
        value['emoji'] is! String ||
        value['author'] is! String) {
      return null;
    }
    final emoji = value['emoji'] as String, author = value['author'] as String;
    if (emoji.isEmpty || author.isEmpty) return null;
    final at = value['at'];
    return ReportedReaction(
      emoji: emoji,
      author: author,
      at: at is num && at.isFinite ? at : null,
      seen: value['seen'] is bool ? value['seen'] as bool : null,
    );
  }
}

List<ReportedReaction>? _reactions(Object? value) {
  if (value is! List) return null;
  final result = <ReportedReaction>[];
  for (final item in value) {
    final reaction = ReportedReaction.decode(item);
    if (reaction == null) return null;
    result.add(reaction);
  }
  return List.unmodifiable(result);
}

class MessageReactionSnapshot {
  const MessageReactionSnapshot({
    required this.rowId,
    required this.role,
    required this.reactions,
  });
  final int rowId;
  final String role;
  final List<ReportedReaction> reactions;
  static MessageReactionSnapshot? decode(Object? value) {
    if (value is! Map || value['row_id'] is! int || value['role'] is! String) {
      return null;
    }
    final id = value['row_id'] as int, role = value['role'] as String;
    final reactions = _reactions(value['reactions']);
    if (id <= 0 ||
        !(role == 'user' || role == 'assistant') ||
        reactions == null) {
      return null;
    }
    return MessageReactionSnapshot(rowId: id, role: role, reactions: reactions);
  }
}

class DurableReactionRow {
  const DurableReactionRow({
    required this.rowId,
    required this.role,
    this.reactions,
  });
  final int rowId;
  final String role;
  final List<ReportedReaction>? reactions;
  static DurableReactionRow? decode(Object? value) {
    if (value is! Map || value['row_id'] is! int || value['role'] is! String) {
      return null;
    }
    final id = value['row_id'] as int, role = value['role'] as String;
    if (id <= 0 || !(role == 'user' || role == 'assistant')) return null;
    Object? metadata = value['display_metadata'];
    if (metadata is String) {
      try {
        metadata = jsonDecode(metadata);
      } on FormatException {
        metadata = null;
      }
    }
    return DurableReactionRow(
      rowId: id,
      role: role,
      reactions: metadata is Map ? _reactions(metadata['reactions']) : null,
    );
  }
}

class ReactionScope {
  const ReactionScope({
    required this.connection,
    required this.lineage,
    required this.profile,
    this.runtimeId,
  });
  final Object connection, lineage;
  final String? runtimeId;
  final String? profile;
  @override
  bool operator ==(Object other) =>
      other is ReactionScope &&
      identical(connection, other.connection) &&
      identical(lineage, other.lineage) &&
      profile == other.profile &&
      runtimeId == other.runtimeId;
  @override
  int get hashCode => Object.hash(
    identityHashCode(connection),
    identityHashCode(lineage),
    profile,
    runtimeId,
  );
}

class ReactionState extends ChangeNotifier {
  ReactionState({
    this.maxPending = 128,
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
  }) : assert(maxPending >= 0);
  final int maxPending;
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  ReactionScope? _scope;
  final Map<int, String> _roles = {};
  final Map<int, List<ReportedReaction>> _matched = {};
  final Map<int, MessageReactionSnapshot> _pending = {};
  final Set<int> _live = {};
  SessionAcknowledgement? acknowledgement;
  bool _disposed = false;
  int get pendingCount => _pending.length;
  bool hasScope(ReactionScope scope) => !_disposed && _scope == scope;
  void adopt(ReactionScope? scope) {
    if (_disposed || scope == _scope) return;
    _scope = scope;
    _roles.clear();
    _matched.clear();
    _pending.clear();
    _live.clear();
    acknowledgement = null;
    notifyListeners();
  }

  bool received(ReactionScope scope, MessageReactionSnapshot snapshot) {
    if (_disposed || scope != _scope) return false;
    final role = _roles[snapshot.rowId];
    if (role != null && role != snapshot.role) return false;
    if (role != null) {
      _matched[snapshot.rowId] = List.unmodifiable(snapshot.reactions);
      _live.add(snapshot.rowId);
    } else {
      _pending.remove(snapshot.rowId);
      _pending[snapshot.rowId] = snapshot;
      while (_pending.length > maxPending) {
        _pending.remove(_pending.keys.first);
      }
    }
    notifyListeners();
    try {
      events('gateway.visibility_outcome', {
        'feature': 'reactions',
        'outcome': 'applied',
        'count': 1,
      });
    } on Object {
      return true;
    }
    return true;
  }

  void historyLoaded(ReactionScope scope, Iterable<DurableReactionRow> rows) {
    if (_disposed || scope != _scope) return;
    for (final row in rows) {
      final knownRole = _roles[row.rowId];
      if (knownRole != null && knownRole != row.role) continue;
      _roles[row.rowId] = row.role;
      final pending = _pending.remove(row.rowId);
      if (pending != null && pending.role == row.role) {
        _matched[row.rowId] = List.unmodifiable(pending.reactions);
        _live.add(row.rowId);
      } else if (!_live.contains(row.rowId)) {
        _matched[row.rowId] = row.reactions ?? const [];
      }
    }
    notifyListeners();
  }

  List<ReportedReaction>? reactionsFor(
    ReactionScope scope,
    int rowId, {
    String? role,
  }) => !_disposed && scope == _scope && (role == null || _roles[rowId] == role)
      ? _matched[rowId]
      : null;
  void signal(ReactionScope scope, SessionAcknowledgement value) {
    if (_disposed || scope != _scope || acknowledgement == value) return;
    acknowledgement = value;
    notifyListeners();
  }

  void detailsOpened() => breadcrumbs('chat.visibility_action', {
    'feature': 'reactions',
    'action': 'details',
  });
  int _notificationDepth = 0;

  @override
  void notifyListeners() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      super.notifyListeners();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scope = null;
    _roles.clear();
    _matched.clear();
    _pending.clear();
    _live.clear();
    acknowledgement = null;
    if (_notificationDepth == 0) super.dispose();
  }
}
