import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:stream_channel/stream_channel.dart';

import '../../models/model_provider_option.dart';
import '../chat_models.dart';
import '../chat_transport.dart';
import '../slash_command.dart';
import 'cancel_aware_stream.dart';
import 'gateway_event_mapper.dart';
import 'gateway_replay.dart';
import 'gateway_rpc_client.dart';
import 'unmapped_events.dart';

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

/// How many reconnect attempts follow a drop before the reply gives up.
const _maxReconnectAttempts = 5;

/// How long one reconnect may take, from the drop, before the reply gives up.
const _reconnectBudget = Duration(seconds: 60);

/// How many times one reply may reconnect in all. Each drop gets its own
/// attempts and budget, so a socket that keeps dropping right after it
/// resumes would otherwise never run out.
const _maxReplyReconnects = 5;

Future<void> _delay(Duration delay) => Future<void>.delayed(delay);

/// The fewest characters (whitespace trimmed) of parked deltas that a resume
/// snapshot's text must end with for the deltas to be taken as held by it.
const _minHeldRun = 8;

/// What a send shows while Hermes finishes the turn it began before the app
/// came back, ahead of the prompt the user sent.
const _finishingInterruptedTurn = 'Hermes is finishing the interrupted turn…';

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

  /// The same request on the runtime session [sessionId] after a reconnect
  /// moved the reply there.
  _OpenRequest movedTo(String sessionId) => _OpenRequest(
    sessionId: sessionId,
    serverRequest: serverRequest,
    batch: batch,
  );

  /// It arrived as a server-to-client request, not as an event.
  final bool serverRequest;

  /// A clarify request with several questions, answered one lock at a time.
  final bool batch;
}

/// A stored session ID qualified by its explicit owning profile.
typedef _ThreadOwner = (String?, String);

/// A chat event, and whether it came from a server-to-client request.
typedef _Incoming = (ChatEvent event, bool serverRequest);

/// How a reconnect ended. Either the turn still runs and [watch] carries it
/// on, with the events the reconnect worked out already queued ahead of the
/// live frames; or the turn ended while disconnected, and [ended] holds the
/// events that finish the reply.
final class _Resumed {
  const _Resumed({
    required this.runtimeId,
    this.watch,
    this.idle,
    this.ended = const [],
    this.giveUp = false,
    this.outcome = 'replayed',
    this.replayedCount = 0,
    this.truncated = false,
    this.epochChanged = false,
  });

  /// The runtime session the reply is on now.
  final String runtimeId;

  /// Null when the turn ended while disconnected.
  final _Watch? watch;

  /// For a turn that ended while disconnected: the watch that goes on
  /// listening to its session, in case Hermes chains another turn.
  final _Watch? idle;

  /// The events of a turn that ended while disconnected, in order.
  final List<_Incoming> ended;

  /// Set when the reply cannot end cleanly: no connection could be made, or the
  /// turn ended without a reply to show, so the reply fails after [ended].
  final bool giveUp;

  /// How the reconnect went, for telemetry: `replayed` when the gap was filled
  /// from the server's ring, `rest_refetch` when the reply had to be rebuilt
  /// from the resume snapshot or the stored thread, `ended` when the turn was
  /// over by the time the app was back, `failed` when [giveUp].
  final String outcome;

  /// How many events the replay handed over.
  final int replayedCount;

  /// The server reported its ring did not reach back far enough.
  final bool truncated;

  /// The server restarted since the app last heard from it.
  final bool epochChanged;

  /// Closes the watches, for a reconnect nobody is waiting for any more.
  void discard() {
    unawaited(watch?.close());
    unawaited(idle?.close());
  }
}

/// A [StreamIterator] that counts the frames it handed out.
class _CountedEvents implements StreamIterator<_Incoming?> {
  _CountedEvents(this._inner);

  final StreamIterator<_Incoming?> _inner;

  /// How many frames were read.
  int read = 0;

  @override
  _Incoming? get current => _inner.current;

  @override
  Future<bool> moveNext() async {
    final more = await _inner.moveNext();
    if (more) read++;
    return more;
  }

  @override
  Future<void> cancel() => _inner.cancel();
}

/// What one runtime session sends, buffered until the transport reads it. A
/// null entry is a frame of the session that shows nothing. It still resets
/// the silence probe, since the session is alive.
///
/// A watch holds its connection's heartbeat while a reply or a follow-up
/// stream reads it, from creation until [release] (when it is parked with no
/// reader) or [close]. A reader takes the hold again with [hold].
class _Watch {
  _Watch(this.runtimeId, this.client, this._inbox, {bool record = false})
    : events = _CountedEvents(StreamIterator(_inbox.stream)),
      _arrivals = record ? [] : null,
      _release = client.hold();

  void Function()? _release;

  /// Takes the connection's heartbeat hold, unless already held or closed.
  void hold() {
    if (!closedByUs) _release ??= client.hold();
  }

  /// Gives the hold back, for a watch parked with nobody reading it.
  void release() {
    _release?.call();
    _release = null;
  }

  final String runtimeId;

  /// The connection this watch listens on.
  final GatewayRpcClient client;
  final StreamController<_Incoming?> _inbox;
  late List<StreamSubscription<Object?>> _sources;
  final _CountedEvents events;
  var _pushed = 0;

  /// Everything pushed so far, while a send still has to tell the turns that
  /// came before its prompt from its own. Null once that is settled.
  List<_Incoming?>? _arrivals;

  /// What a turn the send set aside leaves for the follow-ups, which read it
  /// ahead of the live frames.
  List<_Incoming> _backlog = const [];

  /// Adds a frame of the session for the reader.
  void push(_Incoming? incoming) {
    _arrivals?.add(incoming);
    _pushed++;
    _inbox.add(incoming);
  }

  /// Stops keeping the frames and hands over those pushed so far.
  List<_Incoming?> stopRecording() {
    final arrived = _arrivals ?? const <_Incoming?>[];
    _arrivals = null;
    return arrived;
  }

  /// Leaves [events] for the follow-ups to read first.
  void leaveBacklog(List<_Incoming> events) => _backlog = events;

  /// The events left for the follow-ups, which are read once.
  List<_Incoming> takeBacklog() {
    final taken = _backlog;
    _backlog = const [];
    return taken;
  }

  /// Cancels the sources without awaiting them: a subscription to a broadcast
  /// stream answers its cancel future only once its own cancel callback does,
  /// so awaiting it can hang the reply that is closing its watch.
  Future<void> close() async {
    closedByUs = true;
    release();
    for (final source in _sources) {
      unawaited(source.cancel());
    }
    unawaited(_inbox.close());
  }

  /// Whether nothing more will arrive and nothing is left to read: the watch
  /// was closed, or the socket under it closed (the client may close before
  /// the inbox does) after everything it pushed was read and no backlog is
  /// waiting. A closed watch that still holds frames is not dead yet; the
  /// reader gets them first.
  bool get isDead =>
      closedByUs ||
      (_inbox.isClosed || client.isClosed) &&
          events.read == _pushed &&
          _backlog.isEmpty;

  /// Set when the transport closed this watch itself, as opposed to the
  /// socket under it dropping. A reader that finds the watch ended has nothing
  /// to reconnect to then.
  bool closedByUs = false;
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

  /// How many frames have arrived so far. Frames are only appended, so a
  /// count taken at one moment splits [release]'s list at that point.
  int get count => _frames.length;

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

/// How long frames must have flowed on a reconnected socket before the next
/// drop counts as a fresh one rather than another in a row.
const _stableStreaming = Duration(seconds: 30);

/// How many times one reply reconnected, forgetting the ones before a stretch
/// of steady streaming: a long turn on a flaky network may drop more than
/// [_maxReplyReconnects] times in all, and only a socket that drops again at
/// once, with nothing flowing in between, is given up on.
class _Reconnects {
  int _count = 0;
  DateTime? _reconnectedAt;
  DateTime? _lastFrameAt;

  /// Frames have flowed on the current socket as of [now].
  void frame(DateTime now) => _lastFrameAt = now;

  /// The socket dropped. Returns how many reconnects came before this one,
  /// after forgetting them when the socket that dropped had streamed for
  /// [_stableStreaming].
  int dropped() {
    final since = _reconnectedAt;
    final last = _lastFrameAt;
    if (since != null &&
        last != null &&
        last.difference(since) >= _stableStreaming) {
      _count = 0;
    }
    return _count;
  }

  /// A reconnect is about to be attempted.
  void attempt() => _count++;

  /// The reply is back on a live socket as of [now].
  void reconnected(DateTime now) {
    _reconnectedAt = now;
    _lastFrameAt = null;
  }

  /// A turn ended: the next one starts afresh.
  void reset() {
    _count = 0;
    _reconnectedAt = null;
    _lastFrameAt = null;
  }
}

/// The watch a follow-up stream reads, which a reconnect replaces. Keeping it
/// in one place lets the stream's cancel close the watch that is current then,
/// not the one it started with.
class _Follow {
  _Follow(this._watch);

  _Watch _watch;
  _Watch get watch => _watch;

  /// The follow reads [next] from now on, so it holds its connection.
  set watch(_Watch next) {
    next.hold();
    _watch = next;
  }

  bool cancelled = false;
}

/// Keeps the frames of a turn that was already running out of the reply of a
/// prompt the server queued behind it. Until that turn is seen to end (its
/// completion, or the session reporting idle) its text, tools and completion
/// are dropped, and a [ThreadNeedsRefetch] asks for the thread to be read
/// again so its reply is not lost. From then on everything is the queued
/// prompt's and passes unchanged, with or without a `message.start`. What the
/// user must answer, and the thread's own news, pass through at any time.
class _QueuedGate {
  /// The running turn has ended, so the rest is the queued prompt's.
  var _ended = false;

  bool get ended => _ended;

  /// The running turn has been seen at work, so a `message.start` is one of
  /// its own (a goal continuation's second start, or a replayed one), not the
  /// queued prompt's.
  var _sawRunning = false;

  List<ChatEvent> admit(ChatEvent event) {
    if (_ended) return [event];
    switch (event) {
      case SessionInfo(:final running, :final storedSessionId):
        // Idle after the submit: the running turn is over, or already was.
        final over = running == false;
        if (over) _ended = true;
        return [
          if (over && _sawRunning) const ThreadNeedsRefetch(),
          if (storedSessionId != null)
            SessionInfo(storedSessionId: storedSessionId),
        ];
      case ReplyCompleted():
        _ended = true;
        return const [ThreadNeedsRefetch()];
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
        // A turn that began before this prompt was sent has been seen at work
        // by now; without that, a start can only be the queued turn's.
        if (event is ReplyStarted && !_sawRunning) {
          _ended = true;
          return [event];
        }
        _sawRunning = true;
        return const [];
    }
  }
}

/// Sets aside the turn Hermes ran on its own after a resume that reported
/// `auto_continue`, so the prompt sent behind it gets a reply of its own. The
/// turn goes to the follow-ups, where any turn nobody here submitted is shown.
///
/// Everything up to the turn's end is its, and so are the idle reports that
/// trail it; the next frame that opens a turn is the prompt's. What the user
/// must answer is not held back: [isInputRequest] frames go on to the send,
/// where the request can be answered while the turn runs.
class _Unsolicited {
  _Unsolicited({this.live = true});

  /// Whether the turn may still be running when the send first sees it. False
  /// for one the submit's answer found over: the send shows nothing of it.
  final bool live;

  var _began = false;
  var _ended = false;
  var _done = false;

  /// The turn has been seen to end.
  bool get ended => _ended;

  /// Whether [event] asks the user something, or withdraws such a request.
  static bool isInputRequest(ChatEvent event) =>
      event is ApprovalRequested ||
      event is ClarifyRequested ||
      event is VaultRequested ||
      event is UnsupportedRequested ||
      event is InputRequestExpired ||
      event is InputRequestsCancelled;

  static bool _raisesRequest(ChatEvent event) =>
      event is ApprovalRequested ||
      event is ClarifyRequested ||
      event is VaultRequested ||
      event is UnsupportedRequested;

  /// Whether [event] belongs to the turn nobody here submitted.
  ///
  /// Once the turn has ended, the next frame that opens a turn or raises a
  /// request is the prompt's: a turn can ask for approval before it says
  /// anything else.
  bool claims(ChatEvent event) {
    if (_done) return false;
    if (_ended && (opensTurn(event) || _raisesRequest(event))) {
      _done = true;
      return false;
    }
    // An idle report from before the turn began says nothing of its end.
    _began = _began || beginsTurn(event);
    _ended =
        _ended ||
        _began &&
            (event is ReplyCompleted ||
                event is SessionInfo && event.running == false);
    return true;
  }
}

/// [ChatTransport] over the dashboard's JSON-RPC gateway: `session.create` or
/// `session.resume`, then `prompt.submit`, whose reply arrives as events.
class HermesGatewayTransport implements ChatTransport {
  HermesGatewayTransport({
    required this._connect,
    this._telemetry,
    this._events = noopAppEventLogger,
    this.requestTimeout = const Duration(seconds: 30),
    this.probeTimeout = const Duration(seconds: 10),
    this.connectTimeout = const Duration(seconds: 15),
    this.silenceProbe = const Duration(seconds: 45),
    Random? random,
    this._sleep = _delay,
  }) : _random = random ?? Random();

  /// Jitters the delay before each reconnect attempt. Tests inject a fixed one.
  final Random _random;

  /// Waits out the delay before a reconnect attempt. Tests inject a recorder.
  final Future<void> Function(Duration delay) _sleep;

  /// Replays what a dropped socket missed, per runtime session.
  final _ledger = ReplayLedger();

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

  /// Where the `gateway.*` log events go. They carry fixed names and coarse
  /// values, never the text of a message.
  final AppEventLogger _events;

  /// The frame types this connection showed nothing for, as far as they were
  /// reported.
  var _unmapped = UnmappedEvents();
  GatewayRpcClient? _open;
  Future<GatewayRpcClient>? _opening;
  final _awaiting = <String, _OpenRequest>{};

  /// The sessions still listened to after their reply ended, by thread.
  final _idle = <_ThreadOwner, _Watch>{};

  /// What a send that gave up left of the turn it set aside, for the next
  /// follow-up stream of the thread: no watch survived to carry it.
  final _stranded = <_ThreadOwner, List<_Incoming>>{};

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
  }) {
    final stopped = CancelFlag();
    return CancelAwareStream(
      _sendReply(
        threadId: threadId,
        profile: profile,
        text: text,
        attachments: attachments,
        model: model,
        queued: queued,
        stopped: stopped,
      ),
      stopped,
    );
  }

  Stream<ChatEvent> _sendReply({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
    required CancelFlag stopped,
  }) async* {
    final client = await _client();
    final scope = <String, Object?>{'profile': ?profile};
    // Listening starts before the resume is sent, so a frame the gateway pushes
    // ahead of its answer is kept for this session.
    // What the ledger held before this send's first frame: a frame the tap
    // buffers may already have been observed by a watch that was listening.
    final before = _ledger.snapshot();
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
    // After resuming a session whose last turn was cut off, Hermes runs a turn
    // of its own ahead of this send's prompt.
    final autoContinue =
        session['auto_continue'] != null && session['auto_continue'] != false;
    try {
      runtimeId = session['session_id'] as String;
      storedId = threadId ?? session['stored_session_id'] as String;
      owner = (profile, storedId);
      _stranded.remove(owner);
      await _idle.remove(owner)?.close();
      // A relay may have re-keyed its watch after compression before the
      // caller knew the new id: the runtime session is the same all the same.
      for (final key in [
        for (final e in _idle.entries)
          if (e.value.runtimeId == runtimeId) e.key,
      ]) {
        await _idle.remove(key)?.close();
      }
      if (model != null) {
        if (threadId != null) {
          await _switchModel(client, runtimeId, _modelOf[owner], model);
        }
        _modelOf[owner] = model;
      }
      _beginReply(runtimeId, owner);
      watch = _watch(
        client,
        runtimeId,
        buffered: tap.release(),
        startAt: before.resumeFrom(runtimeId, client.epoch),
        record: autoContinue,
      );
      released = true;
    } finally {
      if (!released) tap.close();
    }
    final mine = <String>{};
    var parked = false;
    final drops = _Reconnects();
    // Whether the turn has begun. A report that the session is idle only ends
    // the reply once it has, or once the grace has passed (see [settles]).
    var started = false;
    var errored = false;
    // Whether the send shows that Hermes is finishing a turn of its own.
    var finishing = false;
    // The requests of that turn the send passed on, which are withdrawn when
    // the turn ends.
    final passed = <String>{};
    var submittedAt = clock.now();
    // Set when the server queued the prompt behind a turn that was running.
    _QueuedGate? gate;
    // Set when the prompt follows a turn Hermes ran on its own. That turn's
    // events are kept in [setAside] for the follow-ups.
    _Unsolicited? unsolicited;
    final setAside = <_Incoming>[];
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
      // What the session sent before it answered. A turn of Hermes' own in it
      // ends before the prompt's reply starts.
      final earlier = watch.stopRecording();
      if (const {'redirected', 'steered'}.contains(submit['status'])) {
        // The server folded the prompt into the turn already running, whose
        // reply streams on in its own send. This one has nothing to wait for,
        // but the running turn's frames go on arriving: the watch is parked
        // for the follow-ups, which carry them.
        final displaced = _idle.remove(owner);
        _idle[owner] = watch;
        watch.release();
        parked = true;
        await displaced?.close();
        yield const PromptFolded();
        return;
      }
      if (submit['status'] == 'queued') {
        if (autoContinue) {
          unsolicited = _Unsolicited();
        } else {
          gate = _QueuedGate();
        }
      } else if (autoContinue) {
        // Answered as idle, so a turn that is already over in what came before
        // the answer is Hermes' own. One that has only begun is the prompt's:
        // the answer can trail the first frames of its reply.
        final probe = _Unsolicited();
        for (final arrived in earlier) {
          if (arrived != null) probe.claims(arrived.$1);
        }
        if (probe.ended) {
          // Over before the answer: what it recorded is history, not a turn
          // to finish, so nothing of it is shown or can be answered.
          unsolicited = _Unsolicited(live: false);
        }
      }
      while (true) {
        while (await _advance(watch, storedId)) {
          drops.frame(clock.now());
          final incoming = watch.events.current;
          if (incoming == null) continue;
          final (event, serverRequest) = incoming;
          _track(event, runtimeId, mine, serverRequest: serverRequest);
          if (event is SessionInfo) {
            final rotated = event.storedSessionId;
            if (rotated != null && rotated.isNotEmpty && rotated != storedId) {
              // Compression moved the thread to a new stored session.
              final next = (profile, rotated);
              _rekey(owner, next);
              owner = next;
              storedId = rotated;
            }
          }
          if (unsolicited != null && unsolicited.claims(event)) {
            final passes =
                unsolicited.live && _Unsolicited.isInputRequest(event);
            if (passes) {
              // Held back, the request could not be answered while the turn
              // waits on it, and the queued prompt would wait behind that.
              yield event;
              if (_requestIdOf(event) case final id? when mine.contains(id)) {
                passed.add(id);
              }
              passed.retainAll(mine);
            } else {
              setAside.add(incoming);
            }
            if (unsolicited.live) {
              if (!finishing && !unsolicited.ended) {
                finishing = true;
                yield const ReplyStatus(_finishingInterruptedTurn);
              } else if (finishing && unsolicited.ended) {
                finishing = false;
                yield const ReplyStatus('');
              }
            }
            if (unsolicited.ended && passed.isNotEmpty) {
              // Nobody can answer what the turn asked once it is over.
              final withdrawn = InputRequestsCancelled(passed.toList());
              _track(withdrawn, runtimeId, mine, serverRequest: false);
              passed.clear();
              yield withdrawn;
            }
            // The turn's end starts the prompt's clock, as a running turn's
            // does for a queued one.
            if (unsolicited.ended) submittedAt = clock.now();
            continue;
          }
          final wasEnded = gate?.ended ?? true;
          final admittedNow = gate == null ? [event] : gate.admit(event);
          // The running turn's end starts the queued turn's clock: an idle
          // report right after it is stale, however long that turn took.
          if (!wasEnded && gate!.ended) submittedAt = clock.now();
          for (final admitted in admittedNow) {
            started = started || beginsTurn(admitted);
            errored = errored || admitted is ReplyErrored;
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
              _turnSettled(admitted, errored: errored);
              // The session goes on listening: Hermes may chain another turn.
              final displaced = _idle.remove(owner);
              watch.leaveBacklog(setAside);
              _idle[owner] = watch;
              watch.release();
              parked = true;
              await displaced?.close();
              return;
            }
          }
        }
        // The connection died before the turn finished. Hermes keeps running
        // it, so pick it back up on a fresh connection rather than failing a
        // reply that is still on its way.
        if (stopped.value) return;
        final made = drops.dropped();
        if (made >= _maxReplyReconnects) {
          if (finishing) yield const ReplyStatus('');
          _strand(owner, setAside);
          throw const GatewayConnectionClosed();
        }
        drops.attempt();
        final resumed = await _reattach(
          owner,
          runtimeId: runtimeId,
          shown: mine,
          drops: made,
          cancelled: () => stopped.value,
        );
        await watch.close();
        if (stopped.value) {
          resumed.discard();
          return;
        }
        _endReply(runtimeId, owner);
        _moveRequests(mine, runtimeId, resumed.runtimeId);
        runtimeId = resumed.runtimeId;
        _beginReply(runtimeId, owner);
        final live = resumed.watch;
        if (live == null) {
          if (finishing) {
            finishing = false;
            yield const ReplyStatus('');
          }
          // A prompt queued behind a running turn keeps the gate across the
          // drop: what the replay holds of the turn ahead of it is not this
          // reply's. The same goes for a turn of Hermes' own: what the replay
          // holds of it goes to the follow-ups, ahead of the idle watch's.
          final gating = gate != null && !gate.ended;
          final own = <_Incoming>[];
          for (final incoming in resumed.ended) {
            if (unsolicited != null && unsolicited.claims(incoming.$1)) {
              (_Unsolicited.isInputRequest(incoming.$1) ? own : setAside).add(
                incoming,
              );
            } else {
              own.add(incoming);
            }
          }
          if (_rotatedIn(resumed.ended, storedId) case final rotated?) {
            final next = (profile, rotated);
            _rekey(owner, next);
            owner = next;
            storedId = rotated;
          }
          if (resumed.idle case final idle?) {
            idle.leaveBacklog(setAside);
            await _park(owner, idle);
          }
          // When the replay ends the reply with nothing of its own, the idle
          // report settles it and the refetch the gate asks for reads the
          // thread.
          final holding = gating || setAside.isNotEmpty;
          var completed = false;
          final yielded = <ChatEvent>[];
          for (final (event, serverRequest) in own) {
            _track(event, runtimeId, mine, serverRequest: serverRequest);
            for (final admitted in gating ? gate.admit(event) : [event]) {
              completed = completed || admitted is ReplyCompleted;
              yielded.add(admitted);
              yield admitted;
            }
          }
          if (holding && !completed && !resumed.giveUp) {
            yielded.add(const SessionInfo(running: false));
            yield const SessionInfo(running: false);
          }
          if (resumed.giveUp) {
            if (resumed.idle == null) _strand(owner, setAside);
            throw const GatewayConnectionClosed();
          }
          _reportSettled(
            yielded,
            errored: errored,
            started: started || setAside.isNotEmpty,
            submittedAt: submittedAt,
          );
          return;
        }
        watch = live;
        drops.reconnected(clock.now());
        // The server reported the resumed session running, so its turn began,
        // unless that turn is still the one a queued prompt waits behind.
        if (gate?.ended ?? true) started = true;
      }
    } finally {
      _forgetRequests(mine);
      _endReply(runtimeId, owner);
      if (!parked) await watch.close();
    }
  }

  /// Keeps the [events] a send set aside for the next follow-up stream of
  /// [owner], when the send fails with no watch left to carry them.
  void _strand(_ThreadOwner owner, List<_Incoming> events) {
    if (events.isNotEmpty) _stranded[owner] = List.of(events);
  }

  /// Logs the event [name], and never lets the logger break the transport.
  void _record(String name, Map<String, Object> attributes) {
    try {
      _events(name, attributes);
    } on Object {
      // Telemetry must not take a reply down with it.
    }
  }

  /// Logs that a reply ended: [via] is what ended it. A completion is the
  /// normal end; an idle report is one the reply settled on without a
  /// completion, and [errored] says an `error` event came before it.
  void _turnSettled(ChatEvent ended, {required bool errored}) =>
      _record('gateway.turn_settled', {
        'via': ended is ReplyCompleted
            ? 'complete'
            : errored
            ? 'error_event'
            : 'session_info',
      });

  /// Logs the end of a turn that finished while the app was disconnected, from
  /// the [events] the reconnect handed over: its completion, or the idle report
  /// that stands in for one. Nothing is logged when they hold neither.
  ///
  /// [errored] is set when the reply saw an `error` event before the drop. An
  /// idle report only counts as the ending under the rule of [settles], with
  /// [started] saying the turn was seen to begin: the events handed over count
  /// as having begun it too.
  void _reportSettled(
    Iterable<ChatEvent> events, {
    required DateTime submittedAt,
    bool errored = false,
    bool started = false,
  }) {
    final list = events.toList();
    final begun = started || list.any(beginsTurn);
    ChatEvent? ending;
    for (final event in list) {
      errored = errored || event is ReplyErrored;
      if (event is ReplyCompleted) {
        ending = event;
      } else if (event is SessionInfo && event.running == false) {
        if (settles(
          started: begun,
          submittedAt: submittedAt,
          now: clock.now(),
        )) {
          ending = event;
        }
      }
    }
    if (ending != null) _turnSettled(ending, errored: errored);
  }

  /// Logs that Hermes sent a frame of type [type] that the app shows nothing
  /// for, once per type on the connection. Only the type is logged. [on] is
  /// the connection's record, when the caller holds it.
  void _reportUnmapped(
    String type, {
    bool serverRequest = false,
    UnmappedEvents? on,
  }) {
    final reported = (on ?? _unmapped).admit(type);
    if (reported == null) return;
    _record('gateway.event_unmapped', {
      'event.type': reported,
      if (serverRequest) 'server_request': true,
    });
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

  /// The stored id the thread was given while the app was disconnected: the
  /// last one a `session.info` of [ended] reports other than [current]. The
  /// events of a turn that ended meanwhile are only shown, never read by the
  /// loop that follows a live turn, so the rotation is found here.
  static String? _rotatedIn(Iterable<_Incoming> ended, String current) {
    String? rotated;
    for (final (event, _) in ended) {
      if (event is SessionInfo) {
        final id = event.storedSessionId;
        if (id != null && id.isNotEmpty) rotated = id;
      }
    }
    return rotated == current ? null : rotated;
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
    if (_stranded.remove(from) case final events?) _stranded[to] = events;
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

  /// Waits for the next frame of [watch], and is false once the watch ended.
  ///
  /// A reply silent for [silenceProbe] is asked about: only the server can say
  /// whether the turn still runs, so it is given up on (as broken) only when
  /// the server no longer lists [storedId] as running.
  Future<bool> _advance(_Watch watch, String storedId) async {
    final pending = watch.events.moveNext();
    while (true) {
      try {
        return await pending.timeout(silenceProbe);
      } on TimeoutException {
        if (await _stillRunning(watch.client, storedId)) continue;
        _record('gateway.turn_settled', {'via': 'silence_probe'});
        throw const GatewayConnectionClosed();
      }
    }
  }

  /// Reconnects [owner] after a drop and resumes its runtime session, so a
  /// turn still running there is watched again, and the events it sent while
  /// the socket was down are replayed.
  ///
  /// [runtimeId] is the session the reply was on, or null when this app never
  /// followed it (a turn another client started); then nothing is replayed,
  /// since the server's ring may hold turns this app already showed. [shown]
  /// holds the request ids the reply has shown, so none is shown twice. [drops]
  /// counts the reconnects this reply already made, so the backoff keeps
  /// growing when a resumed turn drops again at once.
  ///
  /// Each attempt after the very first waits [reconnectDelay] before it. Up to
  /// [maxAttempts] failed attempts, or 60 s from the drop, give up (see
  /// [_Resumed.giveUp]). [cancelled] is asked between attempts and after each
  /// step of one: once it holds, nothing more is tried and nothing is merged.
  Future<_Resumed> _reattach(
    _ThreadOwner owner, {
    required String? runtimeId,
    required Set<String> shown,
    required int drops,
    required bool Function() cancelled,
    int maxAttempts = _maxReconnectAttempts,
  }) async {
    final budget = Completer<void>();
    final timer = Timer(_reconnectBudget, () {
      if (!budget.isCompleted) budget.complete();
    });
    bool stop() => budget.isCompleted || cancelled();
    // Attempts that got as far as opening a socket, for telemetry.
    var tried = 0;
    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (stop()) break;
        final index = attempt + drops;
        if (index > 0) {
          await _within(
            _sleep(reconnectDelay(index, _random)),
            budget.future,
            (_) {},
          );
        }
        if (stop()) break;
        tried = attempt + 1;
        final resumed = await _within(
          _resumeOnce(owner, runtimeId, shown, stop),
          budget.future,
          (resumed) => resumed?.discard(),
        );
        if (resumed != null) {
          if (!cancelled()) {
            if (runtimeId != null) _reportReconnect(tried, resumed);
            return resumed;
          }
          resumed.discard();
          break;
        }
      }
      final failed = _Resumed(
        runtimeId: runtimeId ?? owner.$2,
        giveUp: true,
        outcome: 'failed',
      );
      if (runtimeId != null && !cancelled()) _reportReconnect(tried, failed);
      return failed;
    } finally {
      timer.cancel();
    }
  }

  /// Logs how a reconnect of a reply on screen went, after [attempt] tries.
  void _reportReconnect(int attempt, _Resumed resumed) =>
      _record('gateway.reconnect', {
        'attempt': attempt,
        'outcome': resumed.outcome,
        'replayed_count': resumed.replayedCount,
        'truncated': resumed.truncated,
        'epoch_changed': resumed.epochChanged,
      });

  /// One reconnect attempt: opens a socket, resumes the session, and works out
  /// what the reply missed. Null when the attempt failed and may be retried.
  Future<_Resumed?> _resumeOnce(
    _ThreadOwner owner,
    String? previous,
    Set<String> shown,
    bool Function() stop,
  ) async {
    final GatewayRpcClient client;
    try {
      client = await _client();
    } on Object {
      return null;
    }
    if (stop()) return null;
    // Listening starts before the resume is sent, so the frames the gateway
    // pushes ahead of its answer are kept rather than dropped.
    final tap = _Tap(client);
    final Map<String, Object?> resumed;
    try {
      resumed = await _call(client, 'session.resume', {
        'session_id': owner.$2,
        'profile': ?owner.$1,
      });
    } on Object {
      tap.close();
      return null;
    }
    if (stop()) {
      tap.close();
      return null;
    }
    final answeredAt = tap.count;
    final id = resumed['session_id'];
    final runtimeId = id is String && id.isNotEmpty ? id : previous ?? owner.$2;
    // The ring only replays what this app saw of this session when the
    // session is the one the reply was on, and only from a seq this app
    // holds: from none, `last_seen: 0` would hand over the whole ring.
    final replay =
        previous != null &&
        runtimeId == previous &&
        _ledger.hasWatermark(runtimeId);
    Map<String, Object?>? since;
    if (replay) {
      try {
        since = await _call(client, 'session.events.since', {
          'session_id': runtimeId,
          'last_seen': _ledger.lastSeen(runtimeId),
        });
      } on GatewayRpcException catch (error) {
        // A gateway that predates the replay cannot fill the gap, so the
        // reply is rebuilt from the resume answer instead.
        if (error.code != kGatewayMethodNotFound) {
          tap.close();
          return null;
        }
      } on Object {
        tap.close();
        return null;
      }
    }
    // An attempt the budget or the consumer gave up on must not move the
    // watermark or park a watch.
    if (stop()) {
      tap.close();
      return null;
    }
    // Read before the merge below, which forgets the epoch it finds stale.
    final truncated = since?['truncated'] == true;
    final replayEpoch = since?['epoch'];
    final recordedEpoch = _ledger.epochOf(runtimeId);
    final epochChanged =
        recordedEpoch != null &&
        replayEpoch is String &&
        replayEpoch != recordedEpoch;
    // Nothing below awaits before the watch, so no frame is lost between the
    // release and the subscription.
    final frames = tap.release();
    final before = _ofSession(frames.take(answeredAt), runtimeId).toList();
    final after = _ofSession(frames.skip(answeredAt), runtimeId).toList();
    final openRows = [resumed['open_requests'], since?['open_requests']];
    final snapshot = _inflightText(resumed['inflight']);

    final epoch = client.epoch;
    if (resumed['running'] != true) {
      final ended = <_Incoming>[];
      // What the session said after the completion: a turn Hermes chained.
      final next = <_Incoming>[];
      var completed = false;
      var merged = false;
      var outcome = 'ended';
      var replayedCount = 0;
      if (since != null) {
        final decision = _ledger.merge(
          sid: runtimeId,
          result: since,
          parked: _eventsOf(frames, runtimeId),
        );
        if (decision case Deliver(:final events)) {
          merged = true;
          replayedCount = events.length;
          for (final event in events) {
            final incoming = _incomingOf(event, runtimeId);
            if (incoming == null) continue;
            (completed ? next : ended).add(incoming);
            completed = completed || incoming.$1 is ReplyCompleted;
          }
        }
      }
      ReplyCompleted? stored;
      if (!completed) {
        // No completion was replayed, so the stored reply ends the turn. A
        // reply on screen is refetched; a turn picked up with none has nothing
        // to refetch, and ends quietly when it has no stored reply either. The
        // refetch comes first: the completion must stay the reply's last
        // event. A replayed error is the reason the turn failed, so it is
        // shown, and the settle that follows lets the reply fail with it.
        stored = _storedReply(resumed);
        final onScreen = previous != null;
        final errored = ended.any((incoming) => incoming.$1 is ReplyErrored);
        // After the events: a request binds to the tool call it was raised
        // in, which the replay has to have started first.
        _openRequests(ended, openRows, runtimeId, shown);
        if (onScreen) {
          ended.add((const ThreadNeedsRefetch(), false));
          outcome = 'rest_refetch';
        }
        if (stored != null) {
          ended.add((stored, false));
        } else if (errored) {
          ended.add((const SessionInfo(running: false), false));
        }
        if (stored == null && !errored && onScreen) {
          return _Resumed(
            runtimeId: runtimeId,
            ended: ended,
            giveUp: true,
            outcome: 'failed',
            replayedCount: replayedCount,
            truncated: truncated,
            epochChanged: epochChanged,
          );
        }
        // Frames the replay did not cover (the merge counts them itself).
        if (!merged) {
          next.addAll(_parked(after, runtimeId, shown, epoch: epoch));
        }
      }
      // The session goes on being listened to: Hermes may chain another turn.
      return _Resumed(
        runtimeId: runtimeId,
        ended: ended,
        idle: _watch(client, runtimeId, injected: next, shown: shown),
        outcome: outcome,
        replayedCount: replayedCount,
        truncated: truncated,
        epochChanged: epochChanged,
      );
    }

    final injected = <_Incoming>[];
    var replayedCount = 0;
    final decision = since == null
        ? const Refetch()
        : _ledger.merge(
            sid: runtimeId,
            result: since,
            parked: _eventsOf(frames, runtimeId),
          );
    if (decision case Deliver(:final events)) {
      replayedCount = events.length;
      injected.addAll(_inArrivalOrder(events, frames, runtimeId, shown));
      _openRequests(injected, openRows, runtimeId, shown);
    } else {
      // The replay cannot be trusted, so the snapshot replaces the text. Its
      // leading deltas that it already holds are not shown again. With no
      // snapshot to rebuild a reply on screen from (a replay refused as
      // truncated or from another epoch, another runtime session, no seq to
      // replay from, or a gateway without the replay), the gap is one only
      // the stored thread can fill.
      if (snapshot != null) {
        injected.add((ReplyRebuilt(snapshot), false));
      } else if (previous != null) {
        injected.add((const ThreadNeedsRefetch(), false));
      }
      final dropped = snapshot == null ? 0 : _heldBySnapshot(before, snapshot);
      injected.addAll(
        _parked(before, runtimeId, shown, epoch: epoch, dropped: dropped),
      );
      injected.addAll(_parked(after, runtimeId, shown, epoch: epoch));
      _openRequests(injected, openRows, runtimeId, shown);
    }
    return _Resumed(
      runtimeId: runtimeId,
      watch: _watch(client, runtimeId, injected: injected, shown: shown),
      outcome: decision is Deliver ? 'replayed' : 'rest_refetch',
      replayedCount: replayedCount,
      truncated: truncated,
      epochChanged: epochChanged,
    );
  }

  /// The [delivered] events of a replay as chat events, in the order the
  /// session sent them: the replayed ones first, then each live event and
  /// server request where its frame sits among the [frames] parked during the
  /// reconnect. A replayed event the parked frames also hold, by seq, takes
  /// that frame's place. A request already in [shown] is not shown again.
  List<_Incoming> _inArrivalOrder(
    List<GatewayEvent> delivered,
    List<Object> frames,
    String sid,
    Set<String> shown,
  ) {
    final parked = Set<Object>.identity()..addAll(frames);
    final frameSeqs = {
      for (final frame in frames)
        if (frame is GatewayEvent &&
            frame.sessionId == sid &&
            frame.seq != null)
          frame.seq!,
    };
    final live = Set<Object>.identity();
    final replacing = <int, GatewayEvent>{};
    final out = <_Incoming>[];
    for (final event in delivered) {
      final seq = event.seq;
      if (parked.contains(event)) {
        live.add(event);
      } else if (seq != null && frameSeqs.contains(seq)) {
        replacing[seq] = event;
      } else if (_incomingOf(event, sid) case final incoming?) {
        out.add(incoming);
      }
    }
    for (final frame in frames) {
      if (frame is GatewayEvent) {
        final event = live.contains(frame) ? frame : replacing[frame.seq];
        final incoming = event == null ? null : _incomingOf(event, sid);
        if (incoming != null) out.add(incoming);
      } else if (frame is GatewayServerRequest && frame.sessionId == sid) {
        _addRequest(out, frame, shown);
      }
    }
    return out;
  }

  /// Completes with [work]'s value, or with null once [budget] completes
  /// first. A value that arrives after the budget is handed to [discard], so
  /// a connection opened for an attempt that gave up is closed.
  Future<T?> _within<T>(
    Future<T> work,
    Future<void> budget,
    void Function(T value) discard,
  ) {
    final result = Completer<T?>();
    unawaited(
      work.then(
        (value) {
          if (result.isCompleted) {
            discard(value);
          } else {
            result.complete(value);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    unawaited(
      budget.then((_) {
        if (!result.isCompleted) result.complete(null);
      }),
    );
    return result.future;
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

  /// The frames of [sid]: its events and its server requests, in order.
  static Iterable<Object> _ofSession(Iterable<Object> frames, String sid) =>
      frames.where(
        (frame) => switch (frame) {
          GatewayEvent event => event.sessionId == sid,
          GatewayServerRequest request => request.sessionId == sid,
          _ => false,
        },
      );

  static List<GatewayEvent> _eventsOf(List<Object> frames, String sid) => [
    for (final frame in frames)
      if (frame is GatewayEvent && frame.sessionId == sid) frame,
  ];

  /// The assistant text of a resume answer's `inflight` snapshot, if any.
  static String? _inflightText(Object? inflight) {
    if (inflight case {'assistant': final String text}) return text;
    return null;
  }

  /// How many leading deltas of [before] the snapshot already holds: the
  /// shortest run from the start whose joined text ends [snapshot]. The run
  /// stops at the first frame that is not a delta.
  ///
  /// Only the text can say whether the snapshot holds a delta, so the guess
  /// errs towards a duplicate over a hole: a run counts only with at least
  /// [_minHeldRun] characters besides whitespace. A shorter one ("." after a
  /// snapshot ending in "end.") is as likely a new delta that happens to
  /// match, and dropping it loses text; shown twice, it is a blemish the
  /// completion's full text corrects.
  static int _heldBySnapshot(List<Object> before, String snapshot) {
    final joined = StringBuffer();
    var count = 0;
    for (final frame in before) {
      if (frame is! GatewayEvent || frame.type != 'message.delta') break;
      count++;
      final text = frame.payload['text'];
      joined.write(text is String ? text : '');
      final run = joined.toString();
      final solid = run.replaceAll(RegExp(r'\s'), '').length;
      if (solid >= _minHeldRun && snapshot.endsWith(run)) {
        return count;
      }
    }
    return 0;
  }

  /// The frames [parked] while a reconnect was in flight, as events to show.
  /// Each event is observed on the ledger, so a later replay does not hand it
  /// again. The first [dropped] frames are observed but not shown.
  List<_Incoming> _parked(
    List<Object> parked,
    String sid,
    Set<String> shown, {
    required String? epoch,
    int dropped = 0,
  }) {
    final out = <_Incoming>[];
    for (var i = 0; i < parked.length; i++) {
      final frame = parked[i];
      if (frame is GatewayEvent) {
        final fresh = _ledger.observe(sid, frame.seq, epoch: epoch);
        if (!fresh || i < dropped) continue;
        final incoming = _incomingOf(frame, sid);
        if (incoming != null) out.add(incoming);
      } else if (frame is GatewayServerRequest) {
        _addRequest(out, frame, shown);
      }
    }
    return out;
  }

  /// The chat event a frame of [runtimeId] shows, or null when it shows
  /// nothing. Server requests are mapped as they arrive from the server.
  _Incoming? _incomingOf(Object frame, String runtimeId) {
    switch (frame) {
      case GatewayEvent event when event.sessionId == runtimeId:
        final shown = mapGatewayEvent(event);
        if (shown == null) _reportUnmapped(event.type);
        return shown == null ? null : (shown, false);
      case GatewayServerRequest request when request.sessionId == runtimeId:
        final shown = _handledRequests.contains(request.method)
            ? _fromServerRequest(request)
            : null;
        return shown == null ? null : (shown, true);
      default:
        return null;
    }
  }

  /// Shows the requests of [rows] (each an `open_requests` list from a resume
  /// or replay answer) that [shown] does not hold yet.
  void _openRequests(
    List<_Incoming> out,
    List<Object?> rows,
    String sid,
    Set<String> shown,
  ) {
    for (final row in rows) {
      if (row is! List) continue;
      for (final item in row) {
        if (item is! Map) continue;
        final id = item['id'];
        final method = item['method'];
        if (id is! String || method is! String) continue;
        final params = item['params'];
        _addRequest(
          out,
          GatewayServerRequest(
            id: id,
            method: method,
            sessionId: sid,
            params: params is Map
                ? {for (final e in params.entries) e.key.toString(): e.value}
                : const {},
          ),
          shown,
        );
      }
    }
  }

  /// Adds [request] to [out] as a shown request, unless its method is not
  /// one the app answers or [shown] already holds its id.
  void _addRequest(
    List<_Incoming> out,
    GatewayServerRequest request,
    Set<String> shown,
  ) {
    if (!_handledRequests.contains(request.method)) return;
    if (!shown.add(request.id)) return;
    final incoming = _fromServerRequest(request);
    if (incoming != null) out.add((incoming, true));
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
      _drop(client);
      throw const GatewayConnectionClosed();
    }
  }

  /// Forgets [client] and closes it. Not awaited: closing a channel whose peer
  /// has left can wait forever, and a failure to close is of no use to anyone.
  void _drop(GatewayRpcClient client) {
    if (_open == client) _open = null;
    unawaited(client.close().catchError((Object _) {}));
  }

  /// The connections being probed, so callers that arrive meanwhile wait for
  /// the same answer instead of each waiting out a probe of their own.
  final _probes = <GatewayRpcClient, Future<bool>>{};

  Future<bool> _alive(GatewayRpcClient client) =>
      _probes[client] ??= client.isResponsive(probeTimeout).whenComplete(() {
        // A block body: returning the removed future would wait on itself.
        _probes.remove(client);
      });

  @override
  Future<void> checkConnection() async {
    final open = _connected();
    if (open == null || await _alive(open)) return;
    _drop(open);
  }

  @override
  Stream<ChatEvent> followUps(String threadId, {String? profile}) {
    final owner = (profile, threadId);
    var watch = _idle[owner];
    if (watch != null && watch.isDead) {
      // The socket closed while the thread was idle and everything the watch
      // held was read: nothing arrives on it any more, so the thread is
      // picked up on a fresh one.
      unawaited(_idle.remove(owner)?.close());
      watch = null;
    }
    if (watch != null) {
      final follow = _Follow(watch);
      final out = StreamController<ChatEvent>();
      out.onListen = () => unawaited(_relay(follow, owner, out));
      out.onCancel = () => _stopFollowing(follow);
      return out.stream;
    }
    // A turn may have started in another client without a local watcher.
    final out = StreamController<ChatEvent>();
    out.onListen = () => unawaited(_pickUp(owner, out));
    return out.stream;
  }

  /// Keeps [watch] as the listener of [owner]'s session between turns.
  Future<void> _park(_ThreadOwner owner, _Watch watch) async {
    final displaced = _idle.remove(owner);
    _idle[owner] = watch;
    watch.release();
    await displaced?.close();
  }

  /// Ends [follow]: a reconnect under way stops, and the watch that is current
  /// now, which may not be the one the stream began with, is closed. It is
  /// found by identity, since compression may have re-keyed the thread.
  Future<void> _stopFollowing(_Follow follow) {
    follow.cancelled = true;
    _idle.removeWhere((_, parked) => parked == follow.watch);
    return follow.watch.close();
  }

  Future<void> _pickUp(
    _ThreadOwner owner,
    StreamController<ChatEvent> out,
  ) async {
    var canceled = false;
    out.onCancel = () => canceled = true;
    // Nothing is replayed for a turn this app never followed, so the reply
    // starts from the snapshot the resume answer carries. One attempt: this
    // runs when a thread opens, which must not wait on a server that is down.
    final mine = <String>{};
    final resumed = await _reattach(
      owner,
      runtimeId: null,
      shown: mine,
      drops: 0,
      maxAttempts: 1,
      cancelled: () => canceled || out.isClosed,
    );
    final watch = resumed.watch;
    if (canceled || out.isClosed) {
      resumed.discard();
      return;
    }
    final stranded = _stranded.remove(owner) ?? const <_Incoming>[];
    if (watch == null) {
      final idle = resumed.idle;
      if (idle != null) await _park(owner, idle);
      // What a send that gave up had set aside comes first.
      for (final (event, _) in stranded) {
        out.add(event);
      }
      for (final (event, serverRequest) in resumed.ended) {
        _track(event, resumed.runtimeId, mine, serverRequest: serverRequest);
        out.add(event);
      }
      _forgetRequests(mine);
      if (idle == null ||
          resumed.ended.isEmpty && stranded.isEmpty ||
          canceled ||
          out.isClosed) {
        await out.close();
        return;
      }
      // The turn is over, but the session goes on: what Hermes chains next
      // reaches this stream through the idle watch. A thread with no turn to
      // report has nothing to follow yet.
      final follow = _Follow(idle);
      out.onCancel = () => _stopFollowing(follow);
      await _relay(follow, owner, out);
      return;
    }
    if (_idle.remove(owner) case final previous?) {
      await previous.close();
    }
    if (canceled || out.isClosed) {
      await watch.close();
      return;
    }
    _idle[owner] = watch;
    final follow = _Follow(watch);
    out.onCancel = () => _stopFollowing(follow);
    for (final (event, _) in stranded) {
      out.add(event);
    }
    out.add(const ReplyStarted());
    await _relay(follow, owner, out, initiallyReplying: true);
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
    _Follow follow,
    _ThreadOwner owner,
    StreamController<ChatEvent> out, {
    bool initiallyReplying = false,
  }) async {
    follow.watch.hold();
    var key = owner;
    var runtimeId = follow.watch.runtimeId;
    var replying = initiallyReplying;
    if (replying) _beginReply(runtimeId, key);
    final mine = <String>{};
    final drops = _Reconnects();
    var errored = false;
    void forward(_Incoming incoming) {
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
        return;
      }
      if (!replying && opensTurn(event)) {
        replying = true;
        _beginReply(runtimeId, key);
      }
      _track(event, runtimeId, mine, serverRequest: serverRequest);
      if (out.isClosed) return;
      out.add(event);
      errored = errored || event is ReplyErrored;
      // A turn that settles without a completion is over all the same: the
      // next turn's start must not be taken for a replay of this one.
      if (replying &&
          (event is ReplyCompleted ||
              event is SessionInfo && event.running == false)) {
        _turnSettled(event, errored: errored);
        errored = false;
        replying = false;
        drops.reset();
        _forgetRequests(mine);
        _endReply(runtimeId, key);
      }
    }

    try {
      // What a send set aside, a turn Hermes ran on its own, comes first.
      for (final incoming in follow.watch.takeBacklog()) {
        forward(incoming);
        if (out.isClosed) return;
      }
      while (true) {
        while (true) {
          final bool more;
          try {
            // A turn under way is probed when it goes quiet; between turns a
            // quiet session is just idle.
            more = replying
                ? await _advance(follow.watch, key.$2)
                : await follow.watch.events.moveNext();
          } on GatewayConnectionClosed {
            if (!out.isClosed) out.addError(const GatewayConnectionClosed());
            return;
          }
          if (!more) break;
          drops.frame(clock.now());
          final incoming = follow.watch.events.current;
          if (incoming == null) continue;
          forward(incoming);
          if (out.isClosed) return;
        }
        // Idle between turns: nothing is running to pick back up, so the
        // connection dropping just ends the stream quietly. So does a watch
        // the transport closed itself (another send took the session over).
        if (!replying || follow.cancelled || out.isClosed) return;
        if (follow.watch.closedByUs) return;
        final made = drops.dropped();
        if (made >= _maxReplyReconnects) {
          out.addError(const GatewayConnectionClosed());
          return;
        }
        drops.attempt();
        final resumed = await _reattach(
          key,
          runtimeId: runtimeId,
          shown: mine,
          drops: made,
          cancelled: () => follow.cancelled || out.isClosed,
        );
        final previous = follow.watch;
        await previous.close();
        if (follow.cancelled || out.isClosed) {
          resumed.discard();
          return;
        }
        _endReply(runtimeId, key);
        _moveRequests(mine, runtimeId, resumed.runtimeId);
        runtimeId = resumed.runtimeId;
        _beginReply(runtimeId, key);
        final live = resumed.watch;
        if (live == null) {
          if (_rotatedIn(resumed.ended, key.$2) case final rotated?) {
            final next = (key.$1, rotated);
            _rekey(key, next);
            key = next;
          }
          final idle = resumed.idle;
          if (idle != null) await _park(key, idle);
          for (final (event, serverRequest) in resumed.ended) {
            if (out.isClosed) return;
            _track(event, runtimeId, mine, serverRequest: serverRequest);
            out.add(event);
          }
          if (resumed.giveUp && !out.isClosed) {
            out.addError(const GatewayConnectionClosed());
          }
          if (idle == null || out.isClosed || follow.cancelled) return;
          // The turn is over, but the session goes on: the idle watch carries
          // whatever Hermes chains next, to this same stream.
          replying = false;
          drops.reset();
          _forgetRequests(mine);
          _endReply(runtimeId, key);
          follow.watch = idle;
          continue;
        }
        _idle.updateAll((_, parked) => parked == previous ? live : parked);
        follow.watch = live;
        drops.reconnected(clock.now());
      }
    } finally {
      _forgetRequests(mine);
      if (replying) _endReply(runtimeId, key);
      // The watch is closed below, so it must not stay parked for the next
      // follow-up stream to find dead. By identity: a send that took the
      // session over has parked its own.
      _idle.removeWhere((_, parked) => parked == follow.watch);
      if (!out.isClosed) unawaited(out.close());
      await follow.watch.close();
    }
  }

  /// Starts listening to the events and requests of [runtimeId]. The
  /// [injected] events, already decided by a reconnect, come first; then the
  /// [buffered] frames of any session, filtered to it, and the live frames.
  /// A live event at or below [startAt] (by default what the ledger holds for
  /// this connection's epoch), or what the watch already showed, is dropped,
  /// so one the replay already handed over is not shown twice.
  _Watch _watch(
    GatewayRpcClient client,
    String runtimeId, {
    List<Object> buffered = const [],
    List<_Incoming> injected = const [],
    Set<String> shown = const {},
    int? startAt,
    bool record = false,
  }) {
    final inbox = StreamController<_Incoming?>();
    final watch = _Watch(runtimeId, client, inbox, record: record);
    for (final incoming in injected) {
      watch.push(incoming);
    }
    // The ledger is the transport's: it feeds the next replay. Whether this
    // watch has shown a live event is its own matter, so two watches on one
    // runtime session each get every frame.
    var seen = startAt ?? _ledger.resumeFrom(runtimeId, client.epoch);
    // A request the reply showed before the drop may come again from the new
    // socket; a copy, so the reply's own set stays the reply's.
    final requests = {...shown};
    void deliver(Object frame) {
      final String sid;
      switch (frame) {
        case GatewayEvent event:
          sid = event.sessionId;
        case GatewayServerRequest request:
          sid = request.sessionId;
        default:
          return;
      }
      if (sid != runtimeId) return;
      // A frame that shows nothing, or a replayed duplicate, still counts as
      // a sign of life for the silence probe, so it is sent as a null.
      if (frame is GatewayServerRequest && !requests.add(frame.id)) {
        watch.push(null);
        return;
      }
      if (frame is GatewayEvent) {
        final seq = frame.seq;
        if (seq != null) {
          _ledger.observe(runtimeId, seq, epoch: client.epoch);
          if (seq <= seen) {
            watch.push(null);
            return;
          }
          seen = seq;
        }
      }
      watch.push(_incomingOf(frame, runtimeId));
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

  /// Points the open requests [mine] at the runtime session [to], after a
  /// reconnect moved the reply there from [from], so that withdrawing or
  /// answering them still finds them.
  void _moveRequests(Set<String> mine, String from, String to) {
    if (from == to) return;
    for (final id in mine) {
      final open = _awaiting[id];
      if (open != null && open.sessionId == from) {
        _awaiting[id] = open.movedTo(to);
      }
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

  /// The id of the request [event] raises, if it raises one.
  static String? _requestIdOf(ChatEvent event) => switch (event) {
    ApprovalRequested(:final request) => request.requestId,
    ClarifyRequested(:final request) => request.requestId,
    VaultRequested(:final request) => request.requestId,
    UnsupportedRequested(:final request) => request.requestId,
    _ => null,
  };

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
    } else if (event is InputRequestsCancelled) {
      // No ids withdraws every request of the reply.
      final withdrawn = event.requestIds.isEmpty
          ? mine.toList()
          : event.requestIds;
      for (final id in withdrawn) {
        if (_awaiting[id]?.sessionId != sessionId) continue;
        _awaiting.remove(id);
        mine.remove(id);
      }
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

  /// Answers a server-to-client request on the open connection, which after a
  /// reconnect is not the one the request arrived on (see [_connected]). The
  /// gateway does not say whether it was still waiting; a request that ended
  /// was already expired by `request.cancel`, and it drops an answer it no
  /// longer waits for.
  bool _respond(String requestId, Map<String, Object?> result) {
    final client = _connected();
    if (client == null) return false;
    client.respond(requestId, result);
    return true;
  }

  /// The open connection, or null. The gateway matches a server-to-client
  /// answer by its request id on any connection, so after a reconnect the
  /// answer goes out on the new socket, the one open now.
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
    _stranded.clear();
    for (final watch in idle) {
      await watch.close();
    }
    // Not awaited: the socket may already be gone, and closing a channel whose
    // peer has left can wait forever. Nothing here needs the close to finish.
    unawaited(open?.close());
  }

  Future<GatewayRpcClient> _client() async {
    final open = _connected();
    if (open != null && open.isStale && !await _alive(open)) {
      // Nothing was pinging it, so a socket the OS dropped meanwhile would
      // fail the send after the request timeout.
      _drop(open);
    }
    final current = _connected();
    if (current != null) return current;
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
    final unmapped = _unmapped = UnmappedEvents();
    client.serverRequests
        .where((request) => !_handledRequests.contains(request.method))
        .listen((request) {
          _reportUnmapped(request.method, serverRequest: true, on: unmapped);
          if (_replying.containsKey(request.sessionId)) {
            client.respondError(request.id, -32601, 'Method not found');
          }
        });
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
