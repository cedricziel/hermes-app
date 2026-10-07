import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../models/model_provider_option.dart';
import '../chat_models.dart';
import '../chat_transport.dart';
import '../slash_command.dart';
import 'gateway_event_mapper.dart';
import 'gateway_rpc_client.dart';

/// Opens the dashboard's `/api/ws` socket, credentials included.
typedef GatewayConnect = Future<StreamChannel<String>> Function();

/// The server-to-client request methods the app answers. The gateway sends
/// many more (vault prompts, desktop bridges); those are refused at once.
const _handledRequests = {
  'approval',
  'clarify',
  'sudo',
  'secret',
  'vault.save_login',
  'vault.unlock_prompt',
  'vault.code',
};

/// What `image.attach_bytes` answers for a file that is not an image type it
/// knows.
const _unsupportedImage = 4016;

/// How many times a reply tries to reattach after its connection drops
/// before it gives up, so a socket that keeps flapping does not retry
/// forever.
const _maxReattempts = 5;

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

/// A stored session ID qualified by its explicit owning profile.
typedef _ThreadOwner = (String?, String);

/// A chat event, and whether it came from a server-to-client request.
typedef _Incoming = (ChatEvent event, bool serverRequest);

/// What one runtime session sends, buffered until the transport reads it.
class _Watch {
  _Watch(this.runtimeId, this._inbox, this._sources)
    : events = StreamIterator(_inbox.stream);

  final String runtimeId;
  final StreamController<_Incoming> _inbox;
  final List<StreamSubscription<Object?>> _sources;
  final StreamIterator<_Incoming> events;

  Future<void> close() async {
    for (final source in _sources) {
      await source.cancel();
    }
    unawaited(_inbox.close());
  }
}

/// [ChatTransport] over the dashboard's JSON-RPC gateway: `session.create` or
/// `session.resume`, then `prompt.submit`, whose reply arrives as events.
class HermesGatewayTransport implements ChatTransport {
  HermesGatewayTransport({
    required this._connect,
    this._telemetry,
    this.requestTimeout = const Duration(seconds: 30),
    this.probeTimeout = const Duration(seconds: 10),
  });

  /// How long opening a session or submitting a prompt may go unanswered
  /// before the connection is given up on.
  final Duration requestTimeout;

  /// How long a connection may take to answer [checkConnection].
  final Duration probeTimeout;

  final GatewayConnect _connect;
  final MessagingConnectionTracer? _telemetry;
  GatewayRpcClient? _open;
  Future<GatewayRpcClient>? _opening;
  final _awaiting = <String, _OpenRequest>{};

  /// The sessions still listened to after their reply ended, by thread.
  final _idle = <_ThreadOwner, _Watch>{};

  /// The runtime sessions a reply is in flight for, with how many.
  final _replying = <String, int>{};

  /// The runtime session a reply is in flight in, by the thread it belongs to.
  final _runtimeOf = <_ThreadOwner, String>{};

  /// The model each thread was last set to from here, by thread.
  final _modelOf = <_ThreadOwner, ModelChoice>{};

  /// Shared authenticated RPC for profile and Bot Mode repositories.
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) async => _call(await _client(), method, params);

  @override
  Future<List<SlashCommand>> slashCommands({
    String? threadId,
    String? profile,
  }) async {
    final client = await _client();
    final runtimeId = threadId == null
        ? null
        : await _commandRuntime(client, threadId, profile);
    final result = await _call(client, 'commands.catalog', {
      'session_id': ?runtimeId,
      'profile': ?profile,
    });
    final pairs = result['pairs'];
    if (pairs is! List) return const [];
    final metadata = result['commands'];
    return [
      for (final pair in pairs)
        if (pair is List &&
            pair.length >= 2 &&
            pair[0] is String &&
            pair[1] is String &&
            (pair[0] as String).startsWith('/') &&
            !{'terminal', 'hidden'}.contains(
              metadata is Map && metadata[pair[0]] is Map
                  ? (metadata[pair[0]] as Map)['desktop']
                  : null,
            ))
          SlashCommand(pair[0] as String, pair[1] as String),
    ];
  }

  @override
  Future<SlashCommandResult> runSlashCommand({
    String? threadId,
    String? profile,
    required String command,
  }) async {
    final client = await _client();
    final session = threadId == null
        ? await _call(client, 'session.create', {'profile': ?profile})
        : null;
    final runtimeId = threadId == null
        ? session!['session_id'] as String
        : await _commandRuntime(client, threadId, profile);
    final storedId = threadId ?? session!['stored_session_id'] as String;
    var current = command.trim().replaceFirst(RegExp(r'^/'), '');
    for (var depth = 0; depth < 5; depth++) {
      Map<String, Object?> result;
      try {
        result = await _call(client, 'slash.exec', {
          'session_id': runtimeId,
          'command': current,
        });
      } on GatewayRpcException catch (error) {
        if (error.code != 4018) rethrow;
        final parts = current.split(RegExp(r'\s+'));
        result = await _call(client, 'command.dispatch', {
          'session_id': runtimeId,
          'name': parts.first,
          'arg': current.substring(parts.first.length).trimLeft(),
        });
      }
      final type = result['type'];
      if (type == 'alias') {
        final target = result['target'];
        if (target is! String || target.trim().isEmpty) break;
        final targetCommand = target.trim().replaceFirst(RegExp(r'^/'), '');
        final name = current.split(RegExp(r'\s+')).first;
        final args = current.substring(name.length).trimLeft();
        current = args.isEmpty ? targetCommand : '$targetCommand $args';
        continue;
      }
      final prompt = (type == 'send' || type == 'skill')
          ? result['message'] as String?
          : null;
      return SlashCommandResult(
        threadId: storedId,
        output:
            result['output'] as String? ?? result['notice'] as String? ?? '',
        prompt: prompt,
        display: result['display'] as String?,
        prefill: type == 'prefill' ? result['message'] as String? : null,
      );
    }
    throw StateError('Could not resolve slash command');
  }

  Future<String> _commandRuntime(
    GatewayRpcClient client,
    String storedId,
    String? profile,
  ) async {
    final owner = (profile, storedId);
    final active = _runtimeOf[owner] ?? _idle[owner]?.runtimeId;
    if (active != null) return active;
    final session = await _call(client, 'session.resume', {
      'session_id': storedId,
      'profile': ?profile,
    });
    return session['session_id'] as String;
  }

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
  }) async* {
    final client = await _client();
    final scope = <String, Object?>{'profile': ?profile};
    final Map<String, Object?> session;
    try {
      session = threadId == null
          ? await _call(client, 'session.create', {
              ...scope,
              if (model != null) ...{
                'model': model.modelId,
                'provider': model.providerId,
                'reasoning_effort': ?model.effort,
              },
            })
          : await _call(client, 'session.resume', {
              'session_id': threadId,
              ...scope,
            });
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayProfileUnavailable) {
        throw const ProfileUnavailableException();
      }
      rethrow;
    }
    var runtimeId = session['session_id'] as String;
    final storedId = threadId ?? session['stored_session_id'] as String;
    final owner = (profile, storedId);
    await _idle.remove(owner)?.close();
    if (model != null) {
      if (threadId != null) {
        await _switchModel(client, runtimeId, _modelOf[owner], model);
      }
      _modelOf[owner] = model;
    }
    _beginReply(runtimeId, owner);
    // Buffered from here on: events can arrive before the consumer asks for
    // the next one, and the broadcast stream would drop them.
    var watch = _watch(client, runtimeId);
    final mine = <String>{};
    var parked = false;
    try {
      if (threadId == null) {
        yield ThreadBound(session['stored_session_id'] as String);
      }
      // Images queue on the session and the next prompt takes them, so a send
      // that fails after queuing one must take them off again.
      final queuedImages = <String>[];
      try {
        final references = await _attach(
          client,
          runtimeId,
          attachments,
          queuedImages,
        );
        await _call(client, 'prompt.submit', {
          'session_id': runtimeId,
          'text': [text, ...references].where((s) => s.isNotEmpty).join('\n'),
          if (queued) 'queued': true,
        });
      } on Object {
        await _detach(client, runtimeId, queuedImages);
        rethrow;
      }
      for (var attempt = 0; ; attempt++) {
        while (await watch.events.moveNext()) {
          final (event, serverRequest) = watch.events.current;
          _track(event, runtimeId, mine, serverRequest: serverRequest);
          yield event;
          if (event is ReplyCompleted) {
            // The session goes on listening: Hermes may chain another turn.
            final displaced = _idle.remove(owner);
            _idle[owner] = watch;
            parked = true;
            await displaced?.close();
            return;
          }
        }
        // The connection died before the turn finished. Hermes keeps running
        // it, so pick it back up on a fresh connection rather than failing a
        // reply that is still on its way.
        final (next, ended) = attempt < _maxReattempts
            ? await _reattach(owner)
            : (null, null);
        if (ended != null) {
          yield ended;
          return;
        }
        if (next == null) throw const GatewayConnectionClosed();
        await watch.close();
        _endReply(runtimeId, owner);
        runtimeId = next.runtimeId;
        _beginReply(runtimeId, owner);
        watch = next;
      }
    } finally {
      _forgetRequests(mine);
      _endReply(runtimeId, owner);
      if (!parked) await watch.close();
    }
  }

  /// Moves the session [runtimeId] from [previous] to [next], sending only
  /// what changed. Both are scoped to the session, never written to the
  /// profile's config: `--session` says so for the model, and without it
  /// Hermes refuses the unnamed `custom` provider. The user picked [next]
  /// themselves, so a model Hermes would ask to confirm as expensive is
  /// confirmed.
  Future<void> _switchModel(
    GatewayRpcClient client,
    String runtimeId,
    ModelChoice? previous,
    ModelChoice next,
  ) async {
    if (previous == null || !previous.sameModel(next)) {
      await _call(client, 'config.set', {
        'session_id': runtimeId,
        'key': 'model',
        'value': '${next.modelId} --provider ${next.providerId} --session',
        'confirm_expensive_model': true,
      });
    }
    final effort = next.effort;
    if (effort != null && effort != previous?.effort) {
      await _call(client, 'config.set', {
        'session_id': runtimeId,
        'key': 'reasoning',
        'value': effort,
      });
    }
  }

  /// Reopens the socket and resumes [owner]'s runtime session, so a turn
  /// still running there can be watched again. The same live agent process
  /// keeps the same runtime id, so nothing needs remapping beyond that id.
  /// When the server finished the turn while disconnected, the reply it
  /// stored comes back as the turn's end instead. Returns neither when there
  /// is nothing left to pick up: the turn failed or left no reply, the
  /// session is gone, or the reconnect itself failed.
  Future<(_Watch?, ReplyCompleted?)> _reattach(_ThreadOwner owner) async {
    final GatewayRpcClient client;
    final Map<String, Object?> result;
    try {
      client = await _client();
      result = await _call(client, 'session.resume', {
        'session_id': owner.$2,
        'profile': ?owner.$1,
      });
    } on Object {
      return (null, null);
    }
    if (result['running'] != true) return (null, _storedReply(result));
    final runtimeId = result['session_id'] as String? ?? owner.$2;
    return (_watch(client, runtimeId), null);
  }

  /// The reply a finished turn left as the session's last message, if any.
  ReplyCompleted? _storedReply(Map<String, Object?> resumed) {
    if (resumed['messages']
        case [..., {'role': 'assistant', 'text': final String text}]
        when text.isNotEmpty) {
      return ReplyCompleted(text);
    }
    return null;
  }

  /// Sends [method] and gives up on a gateway that does not answer: the
  /// connection is dropped, so the next send opens a new one.
  Future<Map<String, Object?>> _call(
    GatewayRpcClient client,
    String method,
    Map<String, Object?> params,
  ) async {
    try {
      return await client.request(method, params).timeout(requestTimeout);
    } on TimeoutException {
      await _drop(client);
      throw const GatewayConnectionClosed();
    }
  }

  Future<void> _drop(GatewayRpcClient client) async {
    if (_open == client) _open = null;
    await client.close();
  }

  @override
  Future<void> checkConnection() async {
    final open = _connected();
    if (open == null || await open.isResponsive(probeTimeout)) return;
    await _drop(open);
  }

  @override
  Stream<ChatEvent> followUps(String threadId, {String? profile}) {
    final owner = (profile, threadId);
    final watch = _idle[owner];
    if (watch != null) {
      final out = StreamController<ChatEvent>();
      out.onListen = () => unawaited(_relay(watch, owner, out));
      out.onCancel = () {
        if (_idle[owner] == watch) _idle.remove(owner);
        return watch.close();
      };
      return out.stream;
    }
    // A turn may have started in another client without a local watcher.
    final out = StreamController<ChatEvent>();
    out.onListen = () => unawaited(_pickUp(owner, out));
    return out.stream;
  }

  Future<void> _pickUp(
    _ThreadOwner owner,
    StreamController<ChatEvent> out,
  ) async {
    var canceled = false;
    out.onCancel = () => canceled = true;
    final (watch, ended) = await _reattach(owner);
    if (canceled || out.isClosed) {
      await watch?.close();
      return;
    }
    if (watch == null) {
      if (ended != null) out.add(ended);
      await out.close();
      return;
    }
    if (_idle.remove(owner) case final previous?) {
      await previous.close();
    }
    _idle[owner] = watch;
    out.onCancel = () {
      if (_idle[owner] == watch) _idle.remove(owner);
      return watch.close();
    };
    out.add(const ReplyStarted());
    await _relay(watch, owner, out, initiallyReplying: true);
  }

  @override
  Future<Map<String, String>> activeStatuses() async {
    final GatewayRpcClient client;
    final Map<String, Object?> result;
    try {
      client = await _client();
      result = await _call(client, 'session.active_list', {});
    } on Object {
      return const {};
    }
    final statuses = <String, String>{};
    if (result['sessions'] case final List<Object?> rows) {
      for (final row in rows) {
        if (row
            case {
              'session_key': final String key,
              'status': final String status,
            }
            when key.isNotEmpty) {
          statuses[key] = status;
        }
      }
    }
    return statuses;
  }

  Future<void> _relay(
    _Watch initial,
    _ThreadOwner owner,
    StreamController<ChatEvent> out, {
    bool initiallyReplying = false,
  }) async {
    var watch = initial;
    var runtimeId = watch.runtimeId;
    var replying = initiallyReplying;
    if (replying) _beginReply(runtimeId, owner);
    final mine = <String>{};
    try {
      for (var attempt = 0; ; attempt++) {
        while (await watch.events.moveNext()) {
          final (event, serverRequest) = watch.events.current;
          if (event is ReplyStarted) {
            // A resumed running turn can replay its start. Forwarding that
            // would create a second pending bubble with no completion.
            if (replying) continue;
            replying = true;
            _beginReply(runtimeId, owner);
          }
          _track(event, runtimeId, mine, serverRequest: serverRequest);
          if (out.isClosed) return;
          out.add(event);
          if (event is ReplyCompleted && replying) {
            replying = false;
            _forgetRequests(mine);
            _endReply(runtimeId, owner);
          }
        }
        // Idle between turns: nothing is running to pick back up, so the
        // connection dropping just ends the stream quietly.
        if (!replying) return;
        final (next, ended) = attempt < _maxReattempts
            ? await _reattach(owner)
            : (null, null);
        if (ended != null) {
          if (!out.isClosed) out.add(ended);
          return;
        }
        if (next == null) {
          if (!out.isClosed) out.addError(const GatewayConnectionClosed());
          return;
        }
        await watch.close();
        _endReply(runtimeId, owner);
        runtimeId = next.runtimeId;
        _beginReply(runtimeId, owner);
        watch = next;
      }
    } finally {
      _forgetRequests(mine);
      if (replying) _endReply(runtimeId, owner);
      if (!out.isClosed) unawaited(out.close());
      await watch.close();
    }
  }

  /// Starts listening to the events and requests of [runtimeId].
  _Watch _watch(GatewayRpcClient client, String runtimeId) {
    final inbox = StreamController<_Incoming>();
    final sources = [
      client.events
          .where((event) => event.sessionId == runtimeId)
          .map(mapGatewayEvent)
          .listen((event) {
            if (event != null) inbox.add((event, false));
          }, onDone: inbox.close),
      client.serverRequests
          .where(
            (request) =>
                request.sessionId == runtimeId &&
                _handledRequests.contains(request.method),
          )
          .map(_fromServerRequest)
          .listen((event) {
            if (event != null) inbox.add((event, true));
          }),
    ];
    return _Watch(runtimeId, inbox, sources);
  }

  void _beginReply(String runtimeId, _ThreadOwner owner) {
    _replying.update(runtimeId, (count) => count + 1, ifAbsent: () => 1);
    _runtimeOf[owner] = runtimeId;
  }

  void _endReply(String runtimeId, _ThreadOwner owner) {
    _replying.update(runtimeId, (count) => count - 1);
    if (_replying[runtimeId] == 0) {
      _replying.remove(runtimeId);
      if (_runtimeOf[owner] == runtimeId) _runtimeOf.remove(owner);
    }
  }

  void _forgetRequests(Set<String> mine) {
    mine.forEach(_awaiting.remove);
    mine.clear();
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
      VaultRequested(:final request) => (request.requestId, false),
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
  Future<bool> answerVault(
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  }) async {
    final open = _awaiting[requestId];
    // A vault prompt is always a server-to-client request: the gateway has
    // no `*.respond` method for it.
    if (open == null || !open.serverRequest) return false;
    final value = switch (kind) {
      VaultKind.saveLogin => {'identifier': identifier, 'password': password},
      VaultKind.unlock => password,
      VaultKind.code => code,
    };
    return _respond(requestId, {'value': value});
  }

  @override
  Future<bool> stopReply(String threadId, {String? profile}) async {
    var owner = (profile, threadId);
    var runtimeId = _runtimeOf[owner];
    if (runtimeId == null && profile == null) {
      final matches = _runtimeOf.entries
          .where((entry) => entry.key.$2 == threadId)
          .toList();
      if (matches.length == 1) {
        owner = matches.single.key;
        runtimeId = matches.single.value;
      }
    }
    if (runtimeId == null) return false;
    var client = _connected();
    if (client == null) {
      // The listener may still be reconnecting after a dropped socket. Ask
      // the server which runtime session owns this stored thread before
      // concluding that the reply has already ended.
      client = await _client();
      final resumed = await _call(client, 'session.resume', {
        'session_id': threadId,
        'profile': ?owner.$1,
      });
      if (resumed['running'] != true) return false;
      runtimeId = resumed['session_id'] as String? ?? threadId;
    }
    final result = await _call(client, 'session.interrupt', {
      'session_id': runtimeId,
    });
    return result['status'] == 'interrupted';
  }

  @override
  Future<int?> undoLastTurn(
    String threadId, {
    String? profile,
    bool retry = false,
  }) async {
    final client = await _client();
    final runtimeId = await _commandRuntime(client, threadId, profile);
    try {
      final result = await _call(client, 'session.undo', {
        'session_id': runtimeId,
        'intent': retry ? 'retry' : 'undo',
      });
      return (result['removed'] as num?)?.toInt() ?? 0;
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayMethodNotFound) return null;
      rethrow;
    }
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
    final idle = _idle.values.toList();
    _idle.clear();
    for (final watch in idle) {
      await watch.close();
    }
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

  ChatEvent? _fromServerRequest(GatewayServerRequest request) {
    return switch (request.method) {
      'approval' => ApprovalRequested(toApproval(request.id, request.params)),
      'clarify' => ClarifyRequested(toClarify(request.id, request.params)),
      'vault.save_login' => _vault(
        request.id,
        VaultKind.saveLogin,
        request.params,
      ),
      'vault.unlock_prompt' => _vault(
        request.id,
        VaultKind.unlock,
        request.params,
      ),
      'vault.code' => _vault(request.id, VaultKind.code, request.params),
      'sudo' => unsupportedRequest(request.id, UnsupportedKind.sudo),
      'secret' => unsupportedRequest(request.id, UnsupportedKind.secret),
      _ => null,
    };
  }

  /// A masked vault prompt: the login to save for a site, an external
  /// password manager's master password, or a one-time code.
  VaultRequested _vault(
    String requestId,
    VaultKind kind,
    Map<String, Object?> fields,
  ) => VaultRequested(
    VaultRequest(
      requestId: requestId,
      kind: kind,
      origin: fields['origin'] as String? ?? '',
      site: fields['site'] as String? ?? '',
      backend: fields['backend'] as String? ?? '',
      displayName: fields['display_name'] as String? ?? '',
      hint: fields['hint'] as String? ?? '',
    ),
  );
}
