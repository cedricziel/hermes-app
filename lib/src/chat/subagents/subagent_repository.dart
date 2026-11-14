import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../../telemetry/telemetry.dart';
import '../agent_work_transport.dart';
import 'agent_models.dart';
import 'agent_work_result.dart';

/// The `subagent.*` calls, parsed leniently. Never throws: every failure is a
/// result. A read never resumes a session; an action attaches it first and is
/// never sent twice.
class SubagentRepository {
  SubagentRepository(
    this._transport, {
    this.telemetry = const ConnectionTelemetry(),
    this.timeout = const Duration(seconds: 10),
  });

  final AgentWorkTransport _transport;
  final ConnectionTelemetry telemetry;

  /// How long one call may go unanswered before it counts as lost.
  final Duration timeout;

  Future<AgentWorkResult<AgentList>> list(String threadId, {String? profile}) =>
      _read(
        'list',
        'subagent.list',
        threadId,
        profile,
        {'profile': ?profile},
        parseAgentList,
        size: (list) => list.agents.length + list.delegations.length,
      );

  Future<AgentWorkResult<AgentTail>> tail(AgentKey key) => _read(
    'tail',
    'subagent.tail',
    key.threadId,
    key.profile,
    {'subagent_id': key.subagentId},
    parseAgentTail,
    size: (tail) => tail.text.length,
  );

  Future<AgentWorkResult<StopOutcome>> interrupt(AgentKey key) => _act(
    'interrupt',
    'subagent.interrupt',
    key,
    {'subagent_id': key.subagentId},
    parseStopOutcome,
  );

  /// Sends [text] trimmed. Blank or over [kMaxNoteLength] is refused here and
  /// nothing is sent.
  Future<AgentWorkResult<SteerOutcome>> steer(AgentKey key, String text) {
    final note = text.trim();
    if (note.isEmpty || note.runes.length > kMaxNoteLength) {
      return Future.value(const WorkFailed(WorkFailureKind.rejected));
    }
    return _act('steer', 'subagent.steer', key, {
      'subagent_id': key.subagentId,
      'text': note,
    }, parseSteerOutcome);
  }

  Future<AgentWorkResult<T>> _read<T>(
    String name,
    String method,
    String threadId,
    String? profile,
    Map<String, Object?> params,
    T? Function(Map<String, Object?>) parse, {
    required int Function(T) size,
  }) async {
    final span = _start(name);
    AgentWorkResult<T> result;
    try {
      final answer = await _transport.readAttached(
        threadId,
        profile: profile,
        method: method,
        params: params,
        timeout: timeout,
      );
      if (answer == null) {
        result = const WorkNotAttached();
      } else {
        final value = parse(answer);
        result = value == null
            ? const WorkFailed(WorkFailureKind.other)
            : WorkOk(value);
      }
    } on Object catch (error) {
      result = workResultOfError(error);
    }
    _finish(
      span,
      result,
      size: result is WorkOk<T> ? size(result.value) : null,
    );
    return result;
  }

  Future<AgentWorkResult<T>> _act<T>(
    String name,
    String method,
    AgentKey key,
    Map<String, Object?> params,
    T? Function(Map<String, Object?>) parse,
  ) async {
    final span = _start(name);
    AgentWorkResult<T> result;
    try {
      final answer = await _transport.act(
        key.threadId,
        profile: key.profile,
        method: method,
        params: params,
        timeout: timeout,
      );
      final value = parse(answer);
      result = value == null
          ? const WorkFailed(WorkFailureKind.other)
          : WorkOk(value);
    } on Object catch (error) {
      result = workResultOfError(error);
    }
    _finish(span, result);
    return result;
  }

  Span? _start(String method) {
    try {
      final span = telemetry.tracer?.startSpan(
        'subagent.rpc',
        attributes: telemetry.serverAttributes,
      );
      span?.setAttribute('method', method);
      return span;
    } on Object {
      return null;
    }
  }

  /// Ends [span] with the outcome and a size bucket: rows for a list, KiB of
  /// text for a tail. Telemetry never breaks a call.
  void _finish(Span? span, AgentWorkResult<Object?> result, {int? size}) {
    try {
      span?.setAttribute('outcome', _outcome(result));
      if (size != null && result is WorkOk) {
        final isTail = result.value is AgentTail;
        span?.setAttribute(
          isTail ? 'tail_kib' : 'rows',
          isTail ? _kibBucket(size) : _rowsBucket(size),
        );
      }
      span?.end();
    } on Object {
      return;
    }
  }

  static String _outcome(AgentWorkResult<Object?> result) => switch (result) {
    WorkOk() => 'ok',
    WorkNotAttached() => 'not_attached',
    WorkUnsupported() => 'unsupported',
    WorkLost() => 'lost',
    WorkFailed(:final kind) => switch (kind) {
      WorkFailureKind.rejected => 'rejected',
      WorkFailureKind.notOwned => 'not_owned',
      WorkFailureKind.server => 'server',
      WorkFailureKind.notSent => 'not_sent',
      WorkFailureKind.other => 'other',
    },
  };

  static String _kibBucket(int chars) => switch (chars) {
    0 => '0',
    <= 4096 => '1-4',
    _ => '5-16',
  };

  static String _rowsBucket(int rows) => switch (rows) {
    0 => '0',
    <= 4 => '1-4',
    _ => '5+',
  };
}
