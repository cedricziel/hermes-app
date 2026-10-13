import 'browser_verification_url.dart';

class ConnectorOwner {
  const ConnectorOwner.session(this.sessionId) : type = 'session';
  const ConnectorOwner.account() : type = 'account', sessionId = null;
  final String type;
  final String? sessionId;
  Map<String, Object?> toWire() => {
    'type': type,
    if (sessionId != null) 'session_id': sessionId,
  };
  static ConnectorOwner? decode(Object? raw) {
    if (raw is! Map) return null;
    if (raw['type'] == 'account') return const ConnectorOwner.account();
    final sid = raw['session_id'];
    return raw['type'] == 'session' && sid is String && sid.isNotEmpty
        ? ConnectorOwner.session(sid)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is ConnectorOwner &&
      type == other.type &&
      sessionId == other.sessionId;
  @override
  int get hashCode => Object.hash(type, sessionId);
}

typedef ConnectorOperationKey = (ConnectorOwner, String);

class ConnectorOperationTarget {
  const ConnectorOperationTarget({
    required this.name,
    required this.kind,
    required this.action,
    required this.state,
    this.resolved,
    this.detail,
    this.instructions,
    this.connectUrl,
    this.needsCredentials = false,
  });
  final String name, kind, action, state;
  final String? detail, instructions, connectUrl;
  final bool? resolved;
  final bool needsCredentials;
  bool get knownKind =>
      const {'connector', 'mcp', 'plugin', 'skill'}.contains(kind);
  bool get canCompleteHere =>
      const {'connector', 'mcp'}.contains(kind) &&
      const {'authorize', 'connect', 'enable', 'reconnect'}.contains(action) &&
      !needsCredentials;
  bool get supportsSkip =>
      knownKind &&
      resolved != true &&
      (const {'pending', 'initiated'}.contains(state) ||
          (const {'connector', 'mcp'}.contains(kind) &&
              const {'failed', 'expired'}.contains(state)));
  Uri? get browserUri =>
      canCompleteHere && const {'pending', 'initiated'}.contains(state)
      ? browserVerificationUrl(connectUrl)
      : null;
  ConnectorOperationTarget withoutBrowserLink() => ConnectorOperationTarget(
    name: name,
    kind: kind,
    action: action,
    state: state,
    resolved: resolved,
    detail: detail,
    instructions: instructions,
    needsCredentials: needsCredentials,
  );
  static ConnectorOperationTarget? decode(Object? raw) {
    if (raw is! Map ||
        raw['name'] is! String ||
        (raw['name'] as String).isEmpty ||
        raw['kind'] is! String ||
        raw['action'] is! String ||
        raw['state'] is! String) {
      return null;
    }
    String? text(String key) => raw[key] is String ? raw[key] as String : null;
    return ConnectorOperationTarget(
      name: raw['name'] as String,
      kind: raw['kind'] as String,
      action: raw['action'] as String,
      state: raw['state'] as String,
      resolved: raw['resolved'] is bool ? raw['resolved'] as bool : null,
      detail: text('detail'),
      instructions: text('instructions'),
      connectUrl: text('connect_url'),
      needsCredentials:
          raw['required_env'] != null &&
          (raw['required_env'] is! List ||
              (raw['required_env'] as List).isNotEmpty),
    );
  }
}

class ConnectorOperationSnapshot {
  const ConnectorOperationSnapshot({
    required this.owner,
    required this.opId,
    required this.seq,
    required this.deadlineAt,
    required this.targets,
    this.settled = false,
    this.settledBy,
    this.timeoutSeconds,
    this.toolCallId,
  });
  final ConnectorOwner owner;
  final String opId;
  final int seq;
  final DateTime deadlineAt;
  final List<ConnectorOperationTarget> targets;
  final bool settled;
  final String? settledBy, toolCallId;
  final double? timeoutSeconds;
  ConnectorOperationKey get key => (owner, opId);
  ConnectorOperationSnapshot copyWith({
    bool? settled,
    String? settledBy,
    double? timeoutSeconds,
    String? toolCallId,
    List<ConnectorOperationTarget>? targets,
  }) => ConnectorOperationSnapshot(
    owner: owner,
    opId: opId,
    seq: seq,
    deadlineAt: deadlineAt,
    targets: targets ?? this.targets,
    settled: settled ?? this.settled,
    settledBy: settledBy ?? this.settledBy,
    timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    toolCallId: toolCallId ?? this.toolCallId,
  );

  static ConnectorOperationSnapshot? fromPending(
    Object? raw, {
    required String runtimeId,
  }) => fromRequest(raw, runtimeId: runtimeId);
  static ConnectorOperationSnapshot? fromRequest(
    Object? raw, {
    required String runtimeId,
  }) {
    if (runtimeId.isEmpty) return null;
    return _decode(
      raw,
      owner: ConnectorOwner.session(runtimeId),
      request: true,
    );
  }

  static ConnectorOperationSnapshot? fromUpdate(Object? raw) => _decode(raw);
  static ConnectorOperationSnapshot? _decode(
    Object? raw, {
    ConnectorOwner? owner,
    bool request = false,
  }) {
    if (raw is! Map) return null;
    owner ??= ConnectorOwner.decode(raw['owner']);
    final id = raw['op_id'],
        seq = raw['seq'],
        deadline = raw['deadline_at'],
        rows = raw['targets'];
    final timeout = raw['timeout_seconds'];
    if (owner == null ||
        id is! String ||
        id.isEmpty ||
        seq is! int ||
        seq < 0 ||
        deadline is! num ||
        !deadline.isFinite ||
        deadline.abs() > 8640000000000 ||
        rows is! List ||
        (!request && raw['settled'] is! bool) ||
        (request && (timeout is! num || !timeout.isFinite || timeout < 0))) {
      return null;
    }
    final targets = <ConnectorOperationTarget>[], names = <String>{};
    for (final row in rows) {
      final target = ConnectorOperationTarget.decode(row);
      if (target == null || !names.add(target.name)) return null;
      targets.add(target);
    }
    return ConnectorOperationSnapshot(
      owner: owner,
      opId: id,
      seq: seq,
      deadlineAt: DateTime.fromMillisecondsSinceEpoch(
        (deadline * 1000).round(),
        isUtc: true,
      ),
      targets: List.unmodifiable(targets),
      settled: !request && raw['settled'] == true,
      settledBy: raw['settled_by'] is String
          ? raw['settled_by'] as String
          : null,
      timeoutSeconds: request ? (timeout as num).toDouble() : null,
      toolCallId: request && raw['tool_call_id'] is String
          ? raw['tool_call_id'] as String
          : null,
    );
  }
}

enum ConnectorSnapshotOutcome { applied, older, stale }

class ConnectorOperationsState {
  final _operations = <ConnectorOperationKey, ConnectorOperationSnapshot>{};
  Object? _attachment;
  List<ConnectorOperationSnapshot> get operations =>
      List.unmodifiable(_operations.values);
  ConnectorOperationSnapshot? find(ConnectorOperationKey key) =>
      _operations[key];
  void adopt(Object attachment) {
    if (_attachment == attachment) return;
    clear();
    _attachment = attachment;
  }

  ConnectorSnapshotOutcome apply(
    ConnectorOperationSnapshot snapshot, {
    required Object attachment,
  }) {
    if (_attachment != attachment) return ConnectorSnapshotOutcome.stale;
    final old = _operations[snapshot.key];
    if (old != null && snapshot.seq <= old.seq) {
      return ConnectorSnapshotOutcome.older;
    }
    _operations[snapshot.key] = old == null
        ? snapshot
        : snapshot.copyWith(
            settled: old.settled || snapshot.settled,
            settledBy: snapshot.settledBy ?? old.settledBy,
            timeoutSeconds: old.timeoutSeconds,
            toolCallId: old.toolCallId,
          );
    return ConnectorSnapshotOutcome.applied;
  }

  void markSettled(ConnectorOperationKey key) {
    final old = _operations[key];
    if (old != null) _operations[key] = old.copyWith(settled: true);
  }

  void clear() {
    _operations.clear();
    _attachment = null;
  }
}
