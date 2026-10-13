import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../telemetry/breadcrumbs.dart';

enum TodoStatus { pending, inProgress, completed, cancelled }

class TodoEntry {
  const TodoEntry({
    required this.id,
    required this.content,
    required this.status,
    this.parent,
  });
  final String id, content;
  final TodoStatus status;
  final String? parent;

  static TodoEntry? decode(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['content'] is! String) {
      return null;
    }
    final id = value['id'] as String, content = value['content'] as String;
    final status = switch (value['status']) {
      'pending' => TodoStatus.pending,
      'in_progress' => TodoStatus.inProgress,
      'completed' => TodoStatus.completed,
      'cancelled' => TodoStatus.cancelled,
      _ => null,
    };
    if (id.isEmpty || content.trim().isEmpty || status == null) return null;
    final parent = value['parent'];
    return TodoEntry(
      id: id,
      content: content,
      status: status,
      parent: parent is String && parent.isNotEmpty && parent != id
          ? parent
          : null,
    );
  }
}

class TodoSnapshot {
  const TodoSnapshot(this.revision, this.entries);
  final int revision;
  final List<TodoEntry?> entries;
  int get unsupportedCount => entries.where((entry) => entry == null).length;
  int? get completedCount => unsupportedCount == 0
      ? entries.where((entry) => entry?.status == TodoStatus.completed).length
      : null;

  /// Decodes the pinned TodoStore fields without substituting guessed item shapes.
  static TodoSnapshot? decode(Object? value) {
    if (value is! Map || value['revision'] is! int || value['todos'] is! List) {
      return null;
    }
    final revision = value['revision'] as int;
    if (revision < 0) return null;
    return TodoSnapshot(
      revision,
      List.unmodifiable((value['todos'] as List).map(TodoEntry.decode)),
    );
  }
}

class TodoScope {
  const TodoScope({
    required this.connection,
    required this.runtimeId,
    required this.profile,
  });

  /// Physical connection token, retained across watch/send takeover on that socket.
  final Object connection;
  final String runtimeId;
  final String? profile;
  @override
  bool operator ==(Object other) =>
      other is TodoScope &&
      identical(connection, other.connection) &&
      runtimeId == other.runtimeId &&
      profile == other.profile;
  @override
  int get hashCode =>
      Object.hash(identityHashCode(connection), runtimeId, profile);
}

class TodoPlanState extends ChangeNotifier {
  TodoPlanState({
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
  });
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  TodoScope? _scope;
  TodoSnapshot? snapshot;
  bool _disposed = false;
  bool get attached => _scope != null;
  bool hasScope(TodoScope scope) => attached && _scope == scope;
  bool get unavailable => attached && snapshot == null;

  /// A fresh runtime generation resets revision comparison, even when IDs repeat.
  void adopt(TodoScope? scope) {
    if (_disposed || scope == _scope) return;
    _scope = scope;
    snapshot = null;
    notifyListeners();
  }

  bool updated(TodoScope scope, Object? payload) {
    if (_disposed || scope != _scope) return false;
    final decoded = payload is TodoSnapshot
        ? payload
        : TodoSnapshot.decode(payload);
    if (decoded == null) {
      _outcome('malformed');
      return false;
    }
    if (snapshot != null && decoded.revision <= snapshot!.revision) {
      _outcome('stale');
      return false;
    }
    snapshot = decoded;
    notifyListeners();
    _outcome('applied', count: decoded.entries.length);
    return true;
  }

  void resumed(TodoScope scope, Object? result) {
    if (_disposed || scope != _scope) return;
    final payload = result is TodoSnapshot
        ? result
        : result is Map
        ? result['todo_state']
        : null;
    if (payload != null) {
      updated(scope, payload);
      return;
    }
    if (snapshot == null) {
      notifyListeners();
      _outcome('unavailable');
    }
  }

  void detailsOpened() => breadcrumbs('chat.visibility_action', {
    'feature': 'todo_state',
    'action': 'details',
  });

  void _outcome(String outcome, {int? count}) {
    try {
      events('gateway.visibility_outcome', {
        'feature': 'todo_state',
        'outcome': outcome,
        'count': ?count,
      });
    } on Object {
      return;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scope = null;
    snapshot = null;
    super.dispose();
  }
}
