part of 'hermes_gateway_transport.dart';

// The private helpers: watches, turn gates and reconnect results.

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
  SessionReclaimed? reclaimed;
  var _pushed = 0;

  /// Everything pushed so far, while a send still has to tell the turns that
  /// came before its prompt from its own. Null once that is settled.
  List<_Incoming?>? _arrivals;

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
  /// the inbox does) after everything it pushed was read. A closed watch that
  /// still holds frames is not dead yet; the reader gets them first.
  bool get isDead =>
      closedByUs ||
      (_inbox.isClosed || client.isClosed) && events.read == _pushed;

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
      case ReplyCompleted(
        :final usage,
        :final usageRuntimeId,
        :final usageConnection,
        :final usageMalformed,
      ):
        _ended = true;
        return [
          if (usage != null || usageMalformed)
            SessionUsageUpdated(
              usage,
              runtimeId: usageRuntimeId,
              connection: usageConnection,
              finalSnapshot: true,
              malformed: usageMalformed,
            ),
          const ThreadNeedsRefetch(),
        ];
      case ConnectorOperationReceived() ||
          BillingVerificationReceived() ||
          MessageReactionsUpdated() ||
          SessionAcknowledgementReported() ||
          SideResultReceived() ||
          ProcessOutputReceived() ||
          SessionUsageUpdated() ||
          ApprovalRequested() ||
          WarningScopeDiscarded() ||
          TodoUpdated() ||
          SessionControlUpdated() ||
          SessionControlUnavailable() ||
          SessionWaitUpdated() ||
          SessionReclaimed() ||
          SessionResumeProgress() ||
          ToolRiskFlagged() ||
          NoticeShown() ||
          NoticeCleared() ||
          ClarifyRequested() ||
          VaultRequested() ||
          UnsupportedRequested() ||
          InputRequestExpired() ||
          InputRequestsCancelled() ||
          ThreadTitled() ||
          ReviewSummarized() ||
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

/// Tells the turn Hermes ran on its own after a resume that reported
/// `auto_continue` from the prompt sent behind it, so each gets a reply of its
/// own. The send hands the turn over as [UnsolicitedEvent]s while it runs.
///
/// Everything up to the turn's end is its, and so are the idle reports that
/// trail it; the next frame that opens a turn is the prompt's. What the user
/// must answer is handed over with the rest, so the request can be answered
/// while the turn runs.
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
  /// Once the turn has ended, the next frame that opens a turn, raises a
  /// request or rebuilds a reply from a snapshot is the prompt's: a turn can
  /// ask for approval before it says anything else, and a reconnect rebuilds
  /// the turn running now.
  bool claims(ChatEvent event) {
    if (event is MessageReactionsUpdated ||
        event is SessionAcknowledgementReported ||
        event is SessionUsageUpdated ||
        event is TodoUpdated ||
        event is ConnectorOperationReceived ||
        event is SideResultReceived ||
        event is ProcessOutputReceived ||
        event is BillingVerificationReceived) {
      return false;
    }
    if (_done) return false;
    if (_ended &&
        (opensTurn(event) || _raisesRequest(event) || event is ReplyRebuilt)) {
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

/// How far a send got: `connect`, `open` (the session), `attach`, `submit`,
/// or `reply` once the prompt was taken.
class _SendStep {
  String name = 'connect';
}
