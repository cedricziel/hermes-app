import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../telemetry/breadcrumbs.dart';

enum SideResultKind { background, btw }

class SideResult {
  const SideResult({
    required this.kind,
    required this.taskId,
    required this.text,
    this.question,
  });
  final SideResultKind kind;
  final String taskId, text;
  final String? question;
  static SideResult? decode(String event, Object? value) {
    final kind = switch (event) {
      'background.complete' => SideResultKind.background,
      'btw.complete' => SideResultKind.btw,
      _ => null,
    };
    if (kind == null ||
        value is! Map ||
        value['task_id'] is! String ||
        value['text'] is! String) {
      return null;
    }
    final id = value['task_id'] as String;
    if (id.isEmpty) return null;
    return SideResult(
      kind: kind,
      taskId: id,
      text: value['text'] as String,
      question: value['question'] is String
          ? value['question'] as String
          : null,
    );
  }
}

class SideResultScope {
  const SideResultScope({
    required this.connection,
    required this.sessionId,
    required this.profile,
  });
  final Object connection;
  final String sessionId;
  final String? profile;
  @override
  bool operator ==(Object other) =>
      other is SideResultScope &&
      identical(connection, other.connection) &&
      sessionId == other.sessionId &&
      profile == other.profile;
  @override
  int get hashCode =>
      Object.hash(identityHashCode(connection), sessionId, profile);
}

class SideResultState extends ChangeNotifier {
  SideResultState({
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
  });
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  SideResultScope? _scope;
  final Map<(SideResultKind, String), SideResult> _results = {};
  bool _disposed = false;
  bool hasScope(SideResultScope scope) => _scope == scope;
  List<SideResult> get results => List.unmodifiable(_results.values);
  void adopt(SideResultScope? scope) {
    if (_disposed || scope == _scope) return;
    _scope = scope;
    _results.clear();
    notifyListeners();
  }

  bool received(SideResultScope scope, SideResult result) {
    if (_disposed || scope != _scope) return false;
    _results[(result.kind, result.taskId)] = result;
    notifyListeners();
    try {
      events('gateway.visibility_outcome', {
        'feature': 'side_results',
        'outcome': 'applied',
        'count': 1,
      });
    } on Object {
      return true;
    }
    return true;
  }

  void detailsOpened() => breadcrumbs('chat.visibility_action', {
    'feature': 'side_results',
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
    _results.clear();
    if (_notificationDepth == 0) super.dispose();
  }
}
