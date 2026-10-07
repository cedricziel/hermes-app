import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../models/model_provider_option.dart';
import '../chat_models.dart';
import '../chat_transport.dart';
import '../slash_command.dart';
import 'gateway_event_mapper.dart';
import 'gateway_replay.dart';
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

/// The `session.active_list` statuses of a session that still runs a turn.
const _liveStatuses = {'working', 'waiting', 'starting'};

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

/// What one runtime session sends, buffered until the transport reads it. A
/// null entry is a frame of the session that shows nothing. It still resets
/// the silence probe, since the session is alive.
class _Watch {
  _Watch(this.runtimeId, this._inbox) : events = StreamIterator(_inbox.stream);

  final String runtimeId;
  final StreamController<_Incoming?> _inbox;
  late List<StreamSubscription<Object?>> _sources;
  final StreamIterator<_Incoming?> events;

  /// Cancels the sources without awaiting them: a subscription to a broadcast
  /// stream answers its cancel future only once its own cancel callback does,
  /// so awaiting it can hang the reply that is closing its watch.
  Future<void> close() async {
    for (final source in _sources) {
      unawaited(source.cancel());
    }
    unawaited(_inbox.close());
  }
}

/// Listens to a connection from before its runtime session is known, so the
/// frames the gateway pushes ahead of the resume answer are kept rather than
/// dropped by a broadcast stream that has no listener yet.
class _Tap {
  _Tap(this._client) {
    _sources = [
      _client.events.listen(_frames.add),
      _client.serverRequests.listen(_frames.add),
    ];
  }

  final GatewayRpcClient _client;
  final _frames = <Object>[];
  late final List<StreamSubscription<Object?>> _sources;

  /// Stops listening and hands over the frames that arrived so far, for the
  /// watch of their session. Nothing is dropped in between: both steps are
  /// synchronous.
  List<Object> release() {
    final buffered = List.of(_frames);
    close();
    return buffered;
  }

  /// Stops listening. Frames not yet released are dropped.
  void close() {
    for (final source in _sources) {
      unawaited(source.cancel());
    }
    _frames.clear();
  }
}

/// Keeps the frames of a turn that was already running out of the reply of a
/// prompt the server queued behind it. The queued prompt's reply begins at the
/// first sign of a turn after the running one ended; the running turn's text,
/// tools and completion belong to whoever follows that turn, so they are
/// dropped here, and a [ThreadNeedsRefetch] asks for the thread to be read
/// again so its reply is not lost. What the user must answer, and the thread's
/// own news, pass through.
class _QueuedGate {
  _QueuedGate(this._submittedAt);

  final DateTime _submittedAt;

  /// The running turn has ended, so the next turn is the queued prompt's.
  var _ended = false;

  /// The running turn has been seen at work, so a report that the session is
  /// idle describes its end and not an older state.
  var _sawRunning = false;

  var _ours = false;

  List<ChatEvent> admit(ChatEvent event, DateTime now) {
    if (_ours) return [event];
    switch (event) {
      case SessionInfo(:final running, :final storedSessionId):
        final end =
            running == false &&
            !_ended &&
            settles(started: _sawRunning, submittedAt: _submittedAt, now: now);
        return [
          if (end && _endRunning()) const ThreadNeedsRefetch(),
          if (storedSessionId != null)
            SessionInfo(storedSessionId: storedSessionId),
        ];
      case ReplyCompleted():
        return _endRunning() ? const [ThreadNeedsRefetch()] : const [];
      case ApprovalRequested() ||
          ClarifyRequested() ||
          VaultRequested() ||
          UnsupportedRequested() ||
          InputRequestExpired() ||
          InputRequestsCancelled() ||
          ThreadTitled() ||
          ThreadNeedsRefetch():
        return [event];
      default:
        if (!beginsTurn(event)) return const [];
        // The running turn started before this prompt was sent, so a start can
        // only be the queued turn's.
        if (event is ReplyStarted || _ended) {
          _ours = true;
          return [event];
        }
        _sawRunning = true;
        return const [];
    }
  }

  /// Marks the running turn over. False if it already was.
  bool _endRunning() {
    if (_ended) return false;
    _ended = true;
    return true;
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
    this.connectTimeout = const Duration(seconds: 15),
    this.silenceProbe = const Duration(seconds: 45),
  });

  /// How long opening a session or submitting a prompt may go unanswered
  /// before the connection is given up on.
  final Duration requestTimeout;

  /// How long a connection may take to answer [checkConnection].
  final Duration probeTimeout;

  /// How long opening the socket may take before it is given up on, so a
  /// server that never answers the upgrade does not outlast the OS connect
  /// timeout for every send waiting on it.
  final Duration connectTimeout;

  /// How long a reply in flight may go without a frame of its session before
  /// `session.active_list` is asked whether the turn still runs.
  final Duration silenceProbe;

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
    // Listening starts before the resume is sent, so a frame the gateway pushes
    // ahead of its answer is kept for this session.
    final tap = _Tap(client);
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
      tap.close();
      if (error.code == kGatewayProfileUnavailable) {
        throw const ProfileUnavailableException();
      }
      rethrow;
    } on Object {
      tap.close();
      rethrow;
    }
    var runtimeId = '';
    var storedId = '';
    var owner = (profile, '');
    late _Watch watch;
    var released = false;
    try {
      runtimeId = session['session_id'] as String;
      storedId = threadId ?? session['stored_session_id'] as String;
      owner = (profile, storedId);
      await _idle.remove(owner)?.close();
      if (model != null) {
        if (threadId != null) {
          await _switchModel(client, runtimeId, _modelOf[owner], model);
        }
        _modelOf[owner] = model;
      }
      _beginReply(runtimeId, owner);
      watch = _watch(client, runtimeId, tap.release());
      released = true;
    } finally {
      if (!released) tap.close();
    }
    final mine = <String>{};
    var parked = false;
    // Whether the turn has begun. A report that the session is idle only ends
    // the reply once it has, or once the grace has passed (see [settles]).
    var started = false;
    var submittedAt = clock.now();
    // Set when the server queued the prompt behind a turn that was running.
    _QueuedGate? gate;
    try {
      if (threadId == null) {
        yield ThreadBound(storedId);
      }
      // Images queue on the session and the next prompt takes them, so a send
      // that fails after queuing one must take them off again.
      final queuedImages = <String>[];
      final Map<String, Object?> submit;
      try {
        final references = await _attach(
          client,
          runtimeId,
          attachments,
          queuedImages,
        );
        submittedAt = clock.now();
        submit = await _call(client, 'prompt.submit', {
          'session_id': runtimeId,
          'text': [text, ...references].where((s) => s.isNotEmpty).join('\n'),
          if (queued) 'queued': true,
        });
      } on Object {
        await _detach(client, runtimeId, queuedImages);
        rethrow;
      }
      if (const {'redirected', 'steered'}.contains(submit['status'])) {
        // The server folded the prompt into the turn already running, whose
        // reply streams on in its own send. This one has nothing to wait for,
        // but the running turn's frames go on arriving: the watch is parked
        // for the follow-ups, which carry them.
        final displaced = _idle.remove(owner);
        _idle[owner] = watch;
        parked = true;
        await displaced?.close();
        yield const PromptFolded();
        return;
      }
      if (submit['status'] == 'queued') gate = _QueuedGate(submittedAt);
      for (var attempt = 0; ; attempt++) {
        var pending = watch.events.moveNext();
        var window = silenceProbe;
        while (true) {
          final bool more;
          try {
            more = await pending.timeout(window);
          } on TimeoutException {
            // Silent for a whole probe. Only the server can say whether the
            // turn still runs, so the reply ends only when it no longer does.
            if (await _stillRunning(client, storedId)) {
              window = silenceProbe;
              continue;
            }
            throw const GatewayConnectionClosed();
          }
          if (!more) break;
          final incoming = watch.events.current;
          if (incoming != null) {
            final (event, serverRequest) = incoming;
            _track(event, runtimeId, mine, serverRequest: serverRequest);
            if (event is SessionInfo) {
              final rotated = event.storedSessionId;
              if (rotated != null &&
                  rotated.isNotEmpty &&
                  rotated != storedId) {
                // Compression moved the thread to a new stored session.
                final next = (profile, rotated);
                _rekey(owner, next);
                owner = next;
                storedId = rotated;
              }
            }
            for (final admitted
                in gate == null ? [event] : gate.admit(event, clock.now())) {
              started = started || beginsTurn(admitted);
              final idle = admitted is SessionInfo && admitted.running == false;
              final settled =
                  idle &&
                  settles(
                    started: started,
                    submittedAt: submittedAt,
                    now: clock.now(),
                  );
              // A report that does not settle the reply may still carry the
              // thread's new stored id, which the controller follows.
              final ChatEvent? shown;
              if (idle && !settled) {
                final stored = admitted.storedSessionId;
                shown = stored == null
                    ? null
                    : SessionInfo(storedSessionId: stored);
              } else {
                shown = admitted;
              }
              if (shown != null) yield shown;
              if (shown is ReplyCompleted || settled) {
                // The session goes on listening: Hermes may chain another turn.
                final displaced = _idle.remove(owner);
                _idle[owner] = watch;
                parked = true;
                await displaced?.close();
                return;
              }
            }
          }
          pending = watch.events.moveNext();
          window = silenceProbe;
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
        // The server reported the resumed session running, so its turn began.
        started = true;
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

  /// Moves what is kept for the thread [from] to [to], after compression gave
  /// the thread a new stored id: the runtime session of its reply, its model,
  /// and the watch parked for its follow-ups.
  void _rekey(_ThreadOwner from, _ThreadOwner to) {
    if (from == to) return;
    if (_runtimeOf.remove(from) case final runtimeId?) {
      _runtimeOf[to] = runtimeId;
    }
    if (_modelOf.remove(from) case final model?) _modelOf[to] = model;
    if (_idle.remove(from) case final watch?) {
      final displaced = _idle[to];
      _idle[to] = watch;
      if (displaced != null) unawaited(displaced.close());
    }
  }

  /// Whether the server still lists [storedId] as running. An answer that
  /// cannot be read counts as running: a refused `session.active_list` says
  /// nothing about the turn, and a dead socket ends its watch on its own, which
  /// sends the reply down the reconnect path.
  Future<bool> _stillRunning(GatewayRpcClient client, String storedId) async {
    try {
      final statuses = _statusesOf(
        await _call(client, 'session.active_list', {}),
      );
      final status = statuses[storedId];
      return status != null && _liveStatuses.contains(status);
    } on GatewayRpcException {
      return true;
    } on GatewayConnectionClosed {
      return true;
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
        _idle.removeWhere((_, parked) => parked == watch);
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
    return _statusesOf(result);
  }

  /// The status of each session in a `session.active_list` answer, by key.
  static Map<String, String> _statusesOf(Map<String, Object?> result) {
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
    var key = owner;
    var runtimeId = watch.runtimeId;
    var replying = initiallyReplying;
    if (replying) _beginReply(runtimeId, key);
    final mine = <String>{};
    try {
      for (var attempt = 0; ; attempt++) {
        while (await watch.events.moveNext()) {
          final incoming = watch.events.current;
          if (incoming == null) continue;
          final (event, serverRequest) = incoming;
          if (event is SessionInfo) {
            final rotated = event.storedSessionId;
            if (rotated != null && rotated.isNotEmpty && rotated != key.$2) {
              final next = (key.$1, rotated);
              _rekey(key, next);
              key = next;
            }
          }
          if (event is ReplyStarted && replying) {
            // A resumed running turn can replay its start. Forwarding that
            // would create a second pending bubble with no completion.
            continue;
          }
          if (!replying && beginsTurn(event)) {
            replying = true;
            _beginReply(runtimeId, key);
          }
          _track(event, runtimeId, mine, serverRequest: serverRequest);
          if (out.isClosed) return;
          out.add(event);
          // A turn that settles without a completion is over all the same: the
          // next turn's start must not be taken for a replay of this one.
          if (replying &&
              (event is ReplyCompleted ||
                  event is SessionInfo && event.running == false)) {
            replying = false;
            _forgetRequests(mine);
            _endReply(runtimeId, key);
          }
        }
        // Idle between turns: nothing is running to pick back up, so the
        // connection dropping just ends the stream quietly.
        if (!replying) return;
        final (next, ended) = attempt < _maxReattempts
            ? await _reattach(key)
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
        _endReply(runtimeId, key);
        runtimeId = next.runtimeId;
        _beginReply(runtimeId, key);
        watch = next;
      }
    } finally {
      _forgetRequests(mine);
      if (replying) _endReply(runtimeId, key);
      if (!out.isClosed) unawaited(out.close());
      await watch.close();
    }
  }

  /// Starts listening to the events and requests of [runtimeId]. The
  /// [buffered] frames of any session come first, filtered to it.
  _Watch _watch(
    GatewayRpcClient client,
    String runtimeId, [
    List<Object> buffered = const [],
  ]) {
    final inbox = StreamController<_Incoming?>();
    final watch = _Watch(runtimeId, inbox);
    void deliver(Object frame) {
      final _Incoming? incoming;
      switch (frame) {
        case GatewayEvent event when event.sessionId == runtimeId:
          final shown = mapGatewayEvent(event);
          incoming = shown == null ? null : (shown, false);
        case GatewayServerRequest request when request.sessionId == runtimeId:
          final shown = _handledRequests.contains(request.method)
              ? _fromServerRequest(request)
              : null;
          incoming = shown == null ? null : (shown, true);
        default:
          return;
      }
      inbox.add(incoming);
    }

    buffered.forEach(deliver);
    watch._sources = [
      client.events.listen(deliver, onDone: inbox.close),
      client.serverRequests.listen(deliver),
    ];
    return watch;
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

  Future<StreamChannel<String>> _connectBounded() {
    final pending = _connect();
    return pending.timeout(
      connectTimeout,
      onTimeout: () {
        // A channel that opens after the deadline would otherwise leak.
        unawaited(
          pending.then(
            (channel) => channel.sink.close(),
            onError: (Object _) {},
          ),
        );
        throw const GatewayConnectionClosed();
      },
    );
  }

  Future<GatewayRpcClient> _openNew() async {
    // With the heartbeat, a socket the OS dropped while the app slept closes
    // itself once it goes quiet, and the reply in flight reconnects.
    final client = GatewayRpcClient(
      await _connectBounded(),
      telemetry: _telemetry,
      heartbeat: true,
    );
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
