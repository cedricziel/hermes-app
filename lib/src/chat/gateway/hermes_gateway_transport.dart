import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

import 'package:flutter_otel_instrumentation_messaging/flutter_otel_instrumentation_messaging.dart';

import '../chat_models.dart';
import '../chat_transport.dart';
import 'gateway_rpc_client.dart';

/// Opens the dashboard's `/api/ws` socket, credentials included.
typedef GatewayConnect = Future<StreamChannel<String>> Function();

/// The server-to-client request methods the app answers. The gateway sends
/// many more (vault prompts, desktop bridges); those are refused at once.
const _handledRequests = {'approval', 'clarify', 'sudo', 'secret'};

/// What `image.attach_bytes` answers for a file that is not an image type it
/// knows.
const _unsupportedImage = 4016;

/// An approval or clarify request the user still has to answer.
class _OpenRequest {
  const _OpenRequest({
    required this.sessionId,
    required this.serverRequest,
    required this.batch,
  });

  final String sessionId;

  /// It arrived as a server-to-client request, not as an event.
  final bool serverRequest;

  /// A clarify request with several questions, answered one lock at a time.
  final bool batch;
}

/// A chat event, and whether it came from a server-to-client request.
typedef _Incoming = (ChatEvent event, bool serverRequest);

/// [ChatTransport] over the dashboard's JSON-RPC gateway: `session.create` or
/// `session.resume`, then `prompt.submit`, whose reply arrives as events.
class HermesGatewayTransport implements ChatTransport {
  HermesGatewayTransport({required this._connect, this._telemetry});

  final GatewayConnect _connect;
  final MessagingConnectionTracer? _telemetry;
  GatewayRpcClient? _open;
  Future<GatewayRpcClient>? _opening;
  final _awaiting = <String, _OpenRequest>{};

  /// The runtime sessions a reply is in flight for, with how many.
  final _replying = <String, int>{};

  /// The runtime session a reply is in flight in, by the thread it belongs to.
  final _runtimeOf = <String, String>{};

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
  }) async* {
    final client = await _client();
    final scope = <String, Object?>{'profile': ?profile};
    final Map<String, Object?> session;
    try {
      session = threadId == null
          ? await client.request('session.create', scope)
          : await client.request('session.resume', {
              'session_id': threadId,
              ...scope,
            });
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayProfileUnavailable) {
        throw const ProfileUnavailableException();
      }
      rethrow;
    }
    final runtimeId = session['session_id'] as String;
    _replying.update(runtimeId, (count) => count + 1, ifAbsent: () => 1);
    final storedId = threadId ?? session['stored_session_id'] as String;
    _runtimeOf[storedId] = runtimeId;

    // Buffered from here on: events can arrive before the consumer asks for
    // the next one, and the broadcast stream would drop them.
    final inbox = StreamController<_Incoming>();
    final subscription = client.events
        .where((event) => event.sessionId == runtimeId)
        .map(_toChatEvent)
        .listen((event) {
          if (event != null) inbox.add((event, false));
        }, onDone: inbox.close);
    final requests = client.serverRequests
        .where(
          (request) =>
              request.sessionId == runtimeId &&
              _handledRequests.contains(request.method),
        )
        .map(_fromServerRequest)
        .listen((event) {
          if (event != null) inbox.add((event, true));
        });
    final mine = <String>{};
    try {
      if (threadId == null) {
        yield ThreadBound(session['stored_session_id'] as String);
      }
      // Images queue on the session and the next prompt takes them, so a send
      // that fails after queuing one must take them off again.
      final queued = <String>[];
      try {
        final references = await _attach(
          client,
          runtimeId,
          attachments,
          queued,
        );
        await client.request('prompt.submit', {
          'session_id': runtimeId,
          'text': [text, ...references].where((s) => s.isNotEmpty).join('\n'),
        });
      } on Object {
        await _detach(client, runtimeId, queued);
        rethrow;
      }
      await for (final (event, serverRequest) in inbox.stream) {
        _track(event, runtimeId, mine, serverRequest: serverRequest);
        yield event;
        if (event is ReplyCompleted) return;
      }
      throw const GatewayConnectionClosed();
    } finally {
      mine.forEach(_awaiting.remove);
      _replying.update(runtimeId, (count) => count - 1);
      if (_replying[runtimeId] == 0) _replying.remove(runtimeId);
      if (_runtimeOf[storedId] == runtimeId) _runtimeOf.remove(storedId);
      await subscription.cancel();
      await requests.cancel();
      unawaited(inbox.close());
    }
  }

  /// Makes [attachments] available to the agent: an image is queued on the
  /// session (its path goes to [queued]), any other file is staged and its
  /// `@file:` reference returned for the prompt text.
  Future<List<String>> _attach(
    GatewayRpcClient client,
    String sessionId,
    List<OutgoingAttachment> attachments,
    List<String> queued,
  ) async {
    final references = <String>[];
    for (final attachment in attachments) {
      final name = attachment.name;
      final Uint8List bytes;
      try {
        bytes = await attachment.read();
      } on Object {
        throw AttachmentException(
          attachmentFailedMessage(name, kAttachmentUnreadable),
        );
      }
      if (bytes.length > kMaxAttachmentBytes) {
        throw AttachmentException(attachmentTooLargeMessage(name));
      }
      final encoded = base64Encode(bytes);
      try {
        if (attachment.kind == AttachmentKind.image) {
          try {
            final result = await client.request('image.attach_bytes', {
              'session_id': sessionId,
              'content_base64': encoded,
              'filename': name,
            });
            if (result['path'] case final String path) queued.add(path);
            continue;
          } on GatewayRpcException catch (error) {
            // Not a format the model can see, but the agent can still open it.
            if (error.code != _unsupportedImage) rethrow;
          }
        }
        final result = await client.request('file.attach', {
          'session_id': sessionId,
          'name': name,
          'data_url':
              'data:${attachment.mimeType ?? 'application/octet-stream'}'
              ';base64,$encoded',
        });
        final reference = result['ref_text'];
        if (reference is! String || reference.isEmpty) {
          throw AttachmentException(
            attachmentFailedMessage(name, 'the server sent no reference.'),
          );
        }
        references.add(reference);
      } on GatewayRpcException catch (error) {
        throw AttachmentException(
          error.code == kGatewayMethodNotFound
              ? kAttachmentsUnsupportedMessage
              : attachmentFailedMessage(name, error.message),
        );
      }
    }
    return references;
  }

  Future<void> _detach(
    GatewayRpcClient client,
    String sessionId,
    List<String> queued,
  ) async {
    for (final path in queued) {
      try {
        await client.request('image.detach', {
          'session_id': sessionId,
          'path': path,
        });
      } on Object {
        // Best effort: the send already failed for another reason.
      }
    }
  }

  /// Remembers the requests this turn raised, so they can be answered until
  /// the turn ends, and forgets one that expired.
  void _track(
    ChatEvent event,
    String sessionId,
    Set<String> mine, {
    required bool serverRequest,
  }) {
    final (String, bool)? request = switch (event) {
      ApprovalRequested(:final request) => (request.requestId, false),
      ClarifyRequested(:final request) when serverRequest => (
        request.requestId,
        request.batch,
      ),
      UnsupportedRequested(:final request) => (request.requestId, false),
      _ => null,
    };
    if (request != null) {
      final (id, batch) = request;
      mine.add(id);
      _awaiting[id] = _OpenRequest(
        sessionId: sessionId,
        serverRequest: serverRequest,
        batch: batch,
      );
    } else if (event is InputRequestExpired) {
      _awaiting.remove(event.requestId);
    }
  }

  @override
  Future<bool> answerApproval(String requestId, String choice) async {
    final open = _awaiting[requestId];
    if (open == null) return false;
    if (open.serverRequest) return _respond(requestId, {'choice': choice});
    final client = await _client();
    final result = await client.request('approval.respond', {
      'session_id': open.sessionId,
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
    final answer = multiSelect
        ? jsonEncode(values)
        : (values.isEmpty ? '' : values.first);
    final open = _awaiting[requestId];
    if (open == null) {
      final client = await _client();
      final result = await client.request('clarify.respond', {
        'request_id': requestId,
        'answer': answer,
        'question_id': ?questionId,
      });
      return result['status'] != 'expired';
    }
    if (!open.batch) return _respond(requestId, {'answer': answer});
    // A batch skipped as a whole has no question to lock: an empty result
    // withdraws all of it.
    if (questionId == null) return _respond(requestId, const {});
    final result = await _connected()?.request('clarify.lock', {
      'request_id': requestId,
      'answer': answer,
      'question_id': questionId,
    });
    return result != null && result['status'] != 'expired';
  }

  @override
  Future<bool> stopReply(String threadId) async {
    final runtimeId = _runtimeOf[threadId];
    final client = _connected();
    if (runtimeId == null || client == null) return false;
    final result = await client.request('session.interrupt', {
      'session_id': runtimeId,
    });
    return result['status'] == 'interrupted';
  }

  @override
  Future<bool> skipUnsupported(String requestId, UnsupportedKind kind) async {
    final open = _awaiting[requestId];
    if (open == null) return false;
    if (open.serverRequest) return _respond(requestId, {'value': ''});
    final client = _connected();
    if (client == null) return false;
    final (method, key) = switch (kind) {
      UnsupportedKind.sudo => ('sudo.respond', 'password'),
      UnsupportedKind.secret => ('secret.respond', 'value'),
    };
    final result = await client.request(method, {
      'request_id': requestId,
      key: '',
    });
    return result['status'] != 'expired';
  }

  /// Answers a server-to-client request. The gateway does not say whether it
  /// was still waiting; a request that ended was already expired by
  /// `request.cancel`, and it drops an answer it no longer waits for.
  bool _respond(String requestId, Map<String, Object?> result) {
    final client = _connected();
    if (client == null) return false;
    client.respond(requestId, result);
    return true;
  }

  /// The open connection, or null: a server-to-client request belongs to the
  /// connection it arrived on and cannot be answered on a new one.
  GatewayRpcClient? _connected() {
    final open = _open;
    return open == null || open.isClosed ? null : open;
  }

  @override
  Future<void> close() async {
    final open = _open;
    _open = null;
    await open?.close();
  }

  Future<GatewayRpcClient> _client() async {
    final open = _connected();
    if (open != null) return open;
    return _opening ??= _openNew().whenComplete(() => _opening = null);
  }

  Future<GatewayRpcClient> _openNew() async {
    final client = GatewayRpcClient(await _connect(), telemetry: _telemetry);
    // Not awaited: a gateway that predates the call answers with an error and
    // carries on with events, and none of them may hold up the first send.
    unawaited(
      client
          .request('client.capabilities', {'server_requests': true})
          .then((_) {}, onError: (Object _) {}),
    );
    // Another client attached to a session may answer its requests, and the
    // first response settles one for all of them: only refuse those of a
    // session this app is replying in.
    client.serverRequests
        .where(
          (request) =>
              !_handledRequests.contains(request.method) &&
              _replying.containsKey(request.sessionId),
        )
        .listen(
          (request) =>
              client.respondError(request.id, -32601, 'Method not found'),
        );
    return _open = client;
  }

  ChatEvent? _toChatEvent(GatewayEvent event) {
    final payload = event.payload;
    String text(String key) => payload[key] as String? ?? '';
    return switch (event.type) {
      'message.start' => const ReplyStarted(),
      'message.delta' => ReplyDelta(text('text')),
      'reasoning.delta' => ReasoningUpdated(text('text')),
      'reasoning.available' => ReasoningUpdated(text('text'), replace: true),
      'tool.start' => ToolStarted(name: text('name'), summary: text('context')),
      'tool.complete' => ToolFinished(
        name: text('name'),
        failed: _toolFailed(payload['result']),
      ),
      'session.title' => ThreadTitled(text('title')),
      'message.complete' => ReplyCompleted(
        text('text'),
        failed: payload['status'] == 'error',
        stopped: payload['status'] == 'interrupted',
      ),
      'approval.request' => ApprovalRequested(
        _toApproval(text('request_id'), payload),
      ),
      'clarify.request' => ClarifyRequested(
        _toClarify(text('request_id'), payload),
      ),
      'secret.request' => _unsupported(
        text('request_id'),
        UnsupportedKind.secret,
      ),
      'sudo.request' => _unsupported(text('request_id'), UnsupportedKind.sudo),
      'approval.expire' ||
      'clarify.expire' ||
      'secret.expire' ||
      'sudo.expire' => InputRequestExpired(text('request_id')),
      'request.cancel' => InputRequestExpired(text('id')),
      _ => null,
    };
  }

  ChatEvent? _fromServerRequest(GatewayServerRequest request) {
    return switch (request.method) {
      'approval' => ApprovalRequested(_toApproval(request.id, request.params)),
      'clarify' => ClarifyRequested(_toClarify(request.id, request.params)),
      'sudo' => _unsupported(request.id, UnsupportedKind.sudo),
      'secret' => _unsupported(request.id, UnsupportedKind.secret),
      _ => null,
    };
  }

  ApprovalRequest _toApproval(String requestId, Map<String, Object?> fields) =>
      ApprovalRequest(
        requestId: requestId,
        command: fields['command'] as String? ?? '',
        description: fields['description'] as String? ?? '',
        choices: _strings(fields['choices']),
      );

  UnsupportedRequested _unsupported(String requestId, UnsupportedKind kind) =>
      UnsupportedRequested(
        UnsupportedRequest(requestId: requestId, kind: kind),
      );

  /// The gateway sends no failure flag; a tool that failed puts a message in
  /// the `error` field of its result.
  bool _toolFailed(Object? result) {
    if (result is! Map) return false;
    final error = result['error'];
    return error != null && error != '';
  }

  ClarifyRequest _toClarify(String requestId, Map<String, Object?> payload) {
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
