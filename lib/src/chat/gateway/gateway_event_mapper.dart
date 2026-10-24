import 'dart:convert';

import '../chat_models.dart';
import '../chat_transport.dart';
import '../tool_result.dart';
import '../chat_warning_state.dart';
import '../chat_session_state.dart';
import '../todo_plan/todo_plan_state.dart';
import '../moa_progress_state.dart';
import '../session_usage/usage_snapshot.dart';
import '../side_results/side_result_state.dart';
import '../connector_operation_state.dart';
import '../billing_verification_controller.dart';
import '../process_output_state.dart';
import '../reactions/reaction_state.dart';
import 'gateway_rpc_client.dart';

/// The [ChatEvent] a gateway event frame means, or null for a frame the app
/// does not show. An unknown frame is dropped rather than failing the stream,
/// so a server that sends a new event type still works.
ChatEvent? mapGatewayEvent(GatewayEvent event, {Object? connection}) {
  final payload = event.payload;
  String text(String key) => _plainText(payload[key]);
  return switch (event.type) {
    'billing.step_up.verification' => switch (BillingVerificationDetails.decode(
      payload,
    )) {
      final details? when event.sessionId.isNotEmpty =>
        BillingVerificationReceived(
          details,
          runtimeId: event.sessionId,
          connection: connection,
        ),
      _ => null,
    },
    'moa.reference' || 'moa.progress' || 'moa.phase' || 'moa.aggregating' =>
      event.sessionId.isEmpty
          ? null
          : switch (MoaUpdate.decode(event.type, payload)) {
              final update? => MoaUpdated(
                update,
                runtimeId: event.sessionId,
                connection: connection,
                identity: event.seq == null
                    ? event
                    : (
                        connection is GatewayRpcClient
                            ? connection.epoch ?? connection
                            : connection,
                        event.sessionId,
                        event.seq,
                      ),
              ),
              _ => null,
            },
    'todo.updated' => switch (TodoSnapshot.decode(payload)) {
      final snapshot? => TodoUpdated(
        snapshot,
        runtimeId: event.sessionId,
        connection: connection,
      ),
      _ => null,
    },
    'message.reaction' => switch (MessageReactionSnapshot.decode(payload)) {
      final snapshot? when event.sessionId.isNotEmpty =>
        MessageReactionsUpdated(
          snapshot,
          runtimeId: event.sessionId,
          connection: connection,
        ),
      _ => null,
    },
    'reaction' => switch (SessionAcknowledgement.decode(payload)) {
      final acknowledgement? when event.sessionId.isNotEmpty =>
        SessionAcknowledgementReported(
          acknowledgement,
          runtimeId: event.sessionId,
          connection: connection,
        ),
      _ => null,
    },
    'message.start' => const ReplyStarted(),
    'message.delta' => ReplyDelta(text('text')),
    'message.interim' => ReplyCheckpoint(
      text('text'),
      alreadyStreamed: payload['already_streamed'] != false,
    ),
    'reasoning.delta' => ReasoningUpdated(text('text')),
    'reasoning.available' => ReasoningUpdated(text('text'), fallback: true),
    'tool.generating' => ToolPreparing(text('name')),
    'tool.start' => ToolStarted(
      labels: ToolLabel.decodeList(payload['labels']),
      runtimeId: event.sessionId,
      id: text('tool_id'),
      name: text('name'),
      summary: text('context'),
      args: _args(payload['args']),
    ),
    'tool.complete' => _toolFinished(payload, text),
    'background.complete' || 'btw.complete' => switch (SideResult.decode(
      event.type,
      payload,
    )) {
      final result? when event.sessionId.isNotEmpty => SideResultReceived(
        result,
        runtimeId: event.sessionId,
        connection: connection,
      ),
      _ => null,
    },
    'agent.terminal.output' || 'terminal.close' =>
      switch (ProcessOutputUpdate.decode(event.type, payload)) {
        final update? when event.sessionId.isNotEmpty => ProcessOutputReceived(
          update,
          runtimeId: event.sessionId,
          connection: connection,
        ),
        _ => null,
      },
    'connection.request' => switch (ConnectorOperationSnapshot.fromRequest(
      payload,
      runtimeId: event.sessionId,
    )) {
      final operation? => ConnectorOperationReceived(
        operation,
        runtimeId: event.sessionId,
        connection: connection,
      ),
      _ => null,
    },
    'connection.update' => switch (ConnectorOperationSnapshot.fromUpdate(
      payload,
    )) {
      final operation?
          when operation.owner.type == 'session' &&
                  operation.owner.sessionId == event.sessionId ||
              operation.owner.type == 'account' && event.sessionId.isEmpty =>
        ConnectorOperationReceived(
          operation,
          runtimeId: event.sessionId,
          connection: connection,
        ),
      _ => null,
    },
    'session.usage' =>
      event.sessionId.isEmpty
          ? null
          : SessionUsageUpdated(
              UsageSnapshot.decode(payload['usage']),
              runtimeId: event.sessionId,
              connection: connection,
            ),
    'session.title' => ThreadTitled(text('title')),
    'review.summary' => _reviewSummary(text('text')),
    'tool.output_risk' => switch (payload) {
      {
        'tool_id': final String id,
        'risk': final String risk,
        'findings': final List findings,
        'redacted': final bool redacted,
      }
          when id.isNotEmpty =>
        ToolRiskFlagged(
          id,
          ToolOutputRisk(
            risk: risk,
            findings: findings.whereType<String>().toList(),
            redacted: redacted,
          ),
          runtimeId: event.sessionId,
        ),
      _ => null,
    },
    'notice' =>
      payload['message'] is String && text('message').isNotEmpty
          ? NoticeShown(
              AgentNotice(text: text('message')),
              runtimeId: event.sessionId,
            )
          : null,
    'notification.show' =>
      payload['text'] is String && text('text').isNotEmpty
          ? NoticeShown(
              AgentNotice(
                text: text('text'),
                level: text('level'),
                kind: text('kind'),
                key: payload['key'] is String ? text('key') : null,
                ttlMs: payload['ttl_ms'] is int
                    ? payload['ttl_ms'] as int
                    : null,
              ),
              runtimeId: event.sessionId,
            )
          : null,
    'notification.clear' =>
      payload['key'] is String && text('key').isNotEmpty
          ? NoticeCleared(text('key'), runtimeId: event.sessionId)
          : null,
    'message.complete' => ReplyCompleted(
      text('text'),
      failed: payload['status'] == 'error',
      stopped: payload['status'] == 'interrupted',
      previewed: payload['response_previewed'] == true,
      reused: payload['response_reused'] == true,
      transformed: payload['response_transformed'] == true,
      partial: payload['partial'] == true,
      error: _nonEmpty(text('error')),
      usage: UsageSnapshot.decode(payload['usage']),
      usageMalformed:
          payload['usage'] != null &&
          UsageSnapshot.decode(payload['usage']) == null,
      usageRuntimeId: event.sessionId,
      usageConnection: connection,
    ),
    'error' => ReplyErrored(text('message')),
    'session.info' => SessionInfo(
      running: switch (payload['running']) {
        final bool running => running,
        _ => null,
      },
      storedSessionId: _nonEmpty(text('stored_session_id')),
    ),
    'status.update' => switch (payload) {
      {'kind': final String kind, 'text': final String value} =>
        kind == 'compacting'
            ? ReplyStatus(value.isEmpty ? '' : 'Compacting the conversation…')
            : SessionWaitUpdated(kind, value, runtimeId: event.sessionId),
      _ => null,
    },
    'session.control.update' => switch (SessionControlSnapshot.decode(
      payload['control'],
    )) {
      final control? => SessionControlUpdated(
        control,
        runtimeId: event.sessionId,
      ),
      _ => null,
    },
    'session.reclaimed' => switch (payload) {
      {
        'session_id': final String runtime,
        'stored_session_id': final String stored,
        'reason': final String reason,
      }
          when runtime.isNotEmpty && stored.isNotEmpty =>
        SessionReclaimed(runtime, stored, reason),
      _ => null,
    },
    'session.resume_progress' => switch (payload) {
      {'phase': final String phase, 'status': final String status} =>
        SessionResumeProgress(
          ResumeProgress(
            phase,
            status,
            message: payload['message'] is String ? text('message') : null,
          ),
          runtimeId: event.sessionId,
        ),
      _ => null,
    },
    'thinking.delta' => ReplyStatus(_providerWait(text('text'))),
    'approval.cancelled' => InputRequestsCancelled(
      _strings(payload['request_ids']),
    ),
    'approval.request' => ApprovalRequested(
      toApproval(text('request_id'), payload),
      raisedAsEvent: true,
    ),
    'clarify.request' => ClarifyRequested(
      toClarify(text('request_id'), payload),
      raisedAsEvent: true,
    ),
    'secret.request' => unsupportedRequest(
      text('request_id'),
      UnsupportedKind.secret,
    ),
    'sudo.request' => unsupportedRequest(
      text('request_id'),
      UnsupportedKind.sudo,
    ),
    'approval.expire' ||
    'clarify.expire' ||
    'secret.expire' ||
    'sudo.expire' => InputRequestExpired(text('request_id')),
    'request.cancel' => InputRequestExpired(text('id')),
    'subagent.spawn_requested' ||
    'subagent.start' ||
    'subagent.progress' ||
    'subagent.tool' ||
    'subagent.thinking' ||
    'subagent.complete' => _subagentEvent(event.type, payload),
    _ => null,
  };
}

/// One `subagent.*` frame as a [SubagentUpdated], or null when the frame
/// names no child. Identity fields arrived later in the protocol's life and
/// remain optional, so a frame without an id cannot be shown.
ChatEvent? _subagentEvent(String type, Map<String, Object?> payload) {
  String? field(String camel, String snake) {
    final value = payload[camel] ?? payload[snake];
    return value == null ? null : '$value';
  }

  final id = field('subagentId', 'subagent_id');
  final goal = _plainText(payload['goal']);
  if (id == null || id.isEmpty || goal.isEmpty) return null;
  final parentId = field('parentId', 'parent_id');
  final running = switch (type) {
    'subagent.complete' => false,
    _ => true,
  };
  return SubagentUpdated(
    Subagent(
      id: id,
      goal: goal,
      parentId: parentId == null || parentId.isEmpty ? null : parentId,
      depth: int.tryParse(field('depth', 'depth') ?? '') ?? 0,
      index: int.tryParse(field('taskIndex', 'task_index') ?? '') ?? 0,
      count: int.tryParse(field('taskCount', 'task_count') ?? '') ?? 1,
      status: switch (type) {
        'subagent.complete' => switch (field('status', 'status')) {
          'interrupted' => SubagentStatus.interrupted,
          'queued' || 'running' || null => SubagentStatus.running,
          'completed' => SubagentStatus.completed,
          _ => SubagentStatus.failed,
        },
        _ => SubagentStatus.running,
      },
      toolCount: int.tryParse(field('toolCount', 'tool_count') ?? ''),
      lastTool: running ? field('toolName', 'tool_name') : null,
      lastToolPreview: running
          ? _plainText(
              payload['toolPreview'] ??
                  payload['tool_preview'] ??
                  payload['preview'],
            ).trim()
          : null,
      summary: _plainText(payload['summary']),
      duration: _seconds(
        payload['durationSeconds'] ?? payload['duration_seconds'],
      ),
      model: field('model', 'model'),
      childSessionId: field('childSessionId', 'child_session_id'),
      startedAt: type == 'subagent.start' ? DateTime.now() : null,
    ),
  );
}

/// Hermes writes the review's changes as one line under a translated label,
/// "💾 Self-improvement review: Memory updated · Skill 'x' patched". The
/// glyph and the label go; the row draws its own icon.
ChatEvent? _reviewSummary(String text) {
  var body = text.trim().replaceFirst(_leadingSymbols, '');
  final colon = body.indexOf(': ');
  if (colon > 0 && !body.substring(0, colon).contains(' · ')) {
    body = body.substring(colon + 2);
  }
  final items = {
    for (final item in body.split(' · '))
      if (item.trim().isNotEmpty) item.trim(),
  }.toList();
  return items.isEmpty ? null : ReviewSummarized(items);
}

final _leadingSymbols = RegExp(r'^[^\p{L}\p{N}]+', unicode: true);

/// Hermes writes a provider wait as a status line in its thinking text, such
/// as "⏳ waiting on local-model". Anything else is spinner noise and yields
/// the empty string, which clears the status.
final _providerWaitPattern = RegExp(
  r'^(?:⏳|⚠|↻|⚙)\s*(?:(?:still\s+)?waiting on|loading|processing prompt|no (?:output|response)|model returned|rate limited|provider (?:overloaded|temporarily unavailable))',
  caseSensitive: false,
);

String _providerWait(String text) {
  final trimmed = text.trim();
  return _providerWaitPattern.hasMatch(trimmed) ? trimmed : '';
}

String? _nonEmpty(String value) => value.isEmpty ? null : value;

/// Hermes may send text as content parts rather than a string.
String _plainText(Object? value) => switch (value) {
  null => '',
  String() => value,
  List() => value.map(_partText).join(),
  Map() => _partText(value),
  _ => '$value',
};

String _partText(Object? part) => switch (part) {
  String() => part,
  {'text': final String text} => text,
  {'output_text': final String text} => text,
  _ => '',
};

ApprovalRequest toApproval(String requestId, Map<String, Object?> fields) =>
    ApprovalRequest(
      requestId: requestId,
      command: fields['command'] as String? ?? '',
      description: fields['description'] as String? ?? '',
      choices: _strings(fields['choices']),
      toolName: fields['tool_name'] as String? ?? '',
    );

ToolFinished _toolFinished(
  Map<String, Object?> payload,
  String Function(String key) text,
) {
  final name = text('name');
  final status = toolResultStatus(payload['result'], name: name);
  return ToolFinished(
    labels: ToolLabel.decodeList(payload['labels']),
    id: text('tool_id'),
    name: name,
    failed: status == ToolCallStatus.error,
    warning: status == ToolCallStatus.warning,
    interrupted: status == ToolCallStatus.cancelled,
    result: _toolResult(payload['result']),
    resultData: payload['result'],
    diff: text('inline_diff'),
    duration: _seconds(payload['duration_s']),
  );
}

Map<String, Object?>? _args(Object? value) =>
    value is Map && value.isNotEmpty ? value.cast<String, Object?>() : null;

Duration? _seconds(Object? value) => value is num && value >= 0
    ? Duration(microseconds: (value * 1e6).round())
    : null;

UnsupportedRequested unsupportedRequest(
  String requestId,
  UnsupportedKind kind,
) => UnsupportedRequested(UnsupportedRequest(requestId: requestId, kind: kind));

/// A result is a string or a JSON object; an object with an `output` shows
/// that, since the rest is bookkeeping such as the exit code.
String _toolResult(Object? result) {
  if (result == null) return '';
  if (result is String) return result;
  if (result is Map && result['output'] is String) {
    return result['output'] as String;
  }
  try {
    return const JsonEncoder.withIndent('  ').convert(result);
  } on Object {
    return result.toString();
  }
}

ClarifyRequest toClarify(String requestId, Map<String, Object?> payload) {
  final batch = payload['questions'];
  if (batch is List) {
    return ClarifyRequest(
      requestId: requestId,
      batch: true,
      questions: [
        for (final q in batch.whereType<Map<String, Object?>>()) _toQuestion(q),
      ],
    );
  }
  return ClarifyRequest(
    requestId: requestId,
    questions: [_toQuestion(payload)],
  );
}

ClarifyQuestion _toQuestion(Map<String, Object?> q) => ClarifyQuestion(
  qid: q['qid'] as String? ?? '',
  question: q['question'] as String? ?? '',
  choices: _strings(q['choices']),
  multiSelect: q['multi_select'] == true,
);

List<String> _strings(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String) item,
      ]
    : const [];
