import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

import '../chat_models.dart';
import '../chat_transport.dart';
import 'gateway_rpc_client.dart';

/// Opens the dashboard's `/api/ws` socket, credentials included.
typedef GatewayConnect = Future<StreamChannel<String>> Function();

/// [ChatTransport] over the dashboard's JSON-RPC gateway: `session.create` or
/// `session.resume`, then `prompt.submit`, whose reply arrives as events.
class HermesGatewayTransport implements ChatTransport {
  HermesGatewayTransport({required this._connect});

  final GatewayConnect _connect;
  GatewayRpcClient? _open;
  Future<GatewayRpcClient>? _opening;
  final _requestSessions = <String, String>{};

  @override
  Stream<ChatEvent> send({String? threadId, required String text}) async* {
    final client = await _client();
    final session = threadId == null
        ? await client.request('session.create')
        : await client.request('session.resume', {'session_id': threadId});
    final runtimeId = session['session_id'] as String;

    // Buffered from here on: events can arrive before the consumer asks for
    // the next one, and the broadcast stream would drop them.
    final inbox = StreamController<GatewayEvent>();
    final subscription = client.events
        .where((event) => event.sessionId == runtimeId)
        .listen(inbox.add, onDone: inbox.close);
    try {
      if (threadId == null) {
        yield ThreadBound(session['stored_session_id'] as String);
      }
      await client.request('prompt.submit', {
        'session_id': runtimeId,
        'text': text,
      });
      await for (final event in inbox.stream) {
        final mapped = _toChatEvent(event);
        if (mapped == null) continue;
        if (mapped is ApprovalRequested) {
          _requestSessions[mapped.request.requestId] = runtimeId;
        }
        yield mapped;
        if (mapped is ReplyCompleted) return;
      }
      throw const GatewayConnectionClosed();
    } finally {
      _requestSessions.removeWhere((_, sid) => sid == runtimeId);
      await subscription.cancel();
      unawaited(inbox.close());
    }
  }

  @override
  Future<bool> answerApproval(String requestId, String choice) async {
    final sessionId = _requestSessions[requestId];
    if (sessionId == null) return false;
    final client = await _client();
    final result = await client.request('approval.respond', {
      'session_id': sessionId,
      'request_id': requestId,
      'choice': choice,
    });
    return ((result['resolved'] as num?) ?? 0) > 0;
  }

  @override
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  }) async {
    final client = await _client();
    final result = await client.request('clarify.respond', {
      'request_id': requestId,
      'answer': multiSelect
          ? jsonEncode(values)
          : (values.isEmpty ? '' : values.first),
      'question_id': ?questionId,
    });
    return result['status'] != 'expired';
  }

  @override
  Future<void> close() async {
    final open = _open;
    _open = null;
    await open?.close();
  }

  Future<GatewayRpcClient> _client() async {
    final open = _open;
    if (open != null && !open.isClosed) return open;
    return _opening ??= _openNew().whenComplete(() => _opening = null);
  }

  Future<GatewayRpcClient> _openNew() async {
    final client = GatewayRpcClient(await _connect());
    return _open = client;
  }

  ChatEvent? _toChatEvent(GatewayEvent event) {
    final payload = event.payload;
    String text(String key) => payload[key] as String? ?? '';
    return switch (event.type) {
      'message.start' => const ReplyStarted(),
      'message.delta' => ReplyDelta(text('text')),
      'tool.start' => ToolStarted(name: text('name'), summary: text('context')),
      'tool.complete' => ToolFinished(
        name: text('name'),
        failed: _toolFailed(payload['result']),
      ),
      'session.title' => ThreadTitled(text('title')),
      'message.complete' => ReplyCompleted(
        text('text'),
        failed: payload['status'] == 'error',
      ),
      'approval.request' => ApprovalRequested(
        ApprovalRequest(
          requestId: text('request_id'),
          command: text('command'),
          description: text('description'),
          choices: _strings(payload['choices']),
        ),
      ),
      'clarify.request' => ClarifyRequested(_toClarify(payload)),
      'approval.expire' ||
      'clarify.expire' => InputRequestExpired(text('request_id')),
      _ => null,
    };
  }

  /// The gateway sends no failure flag; a tool that failed puts a message in
  /// the `error` field of its result.
  bool _toolFailed(Object? result) {
    if (result is! Map) return false;
    final error = result['error'];
    return error != null && error != '';
  }

  ClarifyRequest _toClarify(Map<String, Object?> payload) {
    final requestId = payload['request_id'] as String? ?? '';
    final batch = payload['questions'];
    if (batch is List) {
      return ClarifyRequest(
        requestId: requestId,
        batch: true,
        questions: [
          for (final q in batch.whereType<Map<String, Object?>>())
            _toQuestion(q),
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
}
