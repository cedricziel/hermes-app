import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../chat/gateway/gateway_replay.dart' show reconnectDelay;
import '../../telemetry/telemetry.dart';
import '../bot_screen_controller.dart';
import '../bot_screen_models.dart';
import '../bot_screen_repository.dart';
import '../bot_screen_viewer_ids.dart';
import '../input/screen_input.dart';
import '../input/screen_paste.dart';
import '../rfb/display_socket.dart';
import '../rfb/rfb_client.dart';

/// Opens the display stream at [path] with the single-use [ticket]. Throws
/// [DisplaySocketError] when it cannot.
typedef DisplaySocketOpener = Future<WebSocketChannel> Function(
  String path,
  String ticket,
);

/// How many times a stream that ended badly is opened again before the viewer
/// says it cannot reach the screen.
const kViewerReconnectAttempts = 5;

/// How long the app may be covered while this device is in control before the
/// stream closes: a glance at the notification shade or Control Center is
/// shorter, and the App Lock cover hides the picture meanwhile.
const kViewerCoverGrace = Duration(seconds: 2);

/// How long a hand back may take when the viewer is being shut down before
/// the stream closes without waiting for it.
const kViewerReleaseBudget = Duration(seconds: 2);

/// The close code of a stream the app closes while this device is in control
/// and means to come back to. The server treats anything but 1000 and 1001 as
/// a dropped link and keeps the lease.
const kCloseKeepingControl = 4100;

/// The names the span gives the RFB encodings the stream used.
const _encodingNames = {
  0: 'raw',
  1: 'copyrect',
  16: 'zrle',
  -223: 'desktop_size',
};

/// One view of a profile's Bot Screen: it asks `display.observe` for a ticket,
/// opens the display stream with it, keeps the framebuffer current and decides
/// what each way the stream can end means. It also holds the control lease for
/// this device: [takeOver] and [handBack], pinned to the gateway connection
/// that minted the viewer id.
///
/// The stream is open only while the viewer can be seen: [foreground] and
/// [unlocked] close it with 1000 and drop the picture, and [dispose] does the
/// same for good. The server counts an attached viewer as use and skips its
/// idle stop, so a stream is never kept for a viewer nobody sees. While this
/// device is in control the app leaving the foreground closes it with 4100
/// instead, a dropped link the server does not hand the lease back for, and a
/// cover (App Lock, the notification shade) does so only after
/// [coverGrace]; the viewer then takes the stream up again on return.
///
/// The ticket, the stream path and the viewer id are credentials: they live in
/// this object's memory and in no log, span or breadcrumb.
class BotScreenViewerController extends ChangeNotifier {
  /// [screen] supplies the lease and is watched for as long as the viewer
  /// lives, so its status stays current. [openSocket] opens the stream.
  BotScreenViewerController({
    required this.repository,
    required this.screen,
    required this.openSocket,
    this.profile,
    this.telemetry = const ConnectionTelemetry(),
    this.coverGrace = kViewerCoverGrace,
    this.readClipboard = readDeviceClipboard,
    TargetPlatform? platform,
    Random? random,
  }) : platform = platform ?? defaultTargetPlatform,
       _random = random ?? Random();

  final BotScreenRepository repository;
  final BotScreenController screen;
  final DisplaySocketOpener openSocket;

  /// The profile watched; null is the server's default.
  final String? profile;
  final ConnectionTelemetry telemetry;

  /// How long a cover may last, while in control, before the stream closes.
  final Duration coverGrace;

  /// Reads the device clipboard's text, for Paste.
  final Future<String?> Function() readClipboard;

  /// The platform whose reserved keys apply.
  final TargetPlatform platform;
  final Random _random;

  BotScreenWatch? _watch;
  BotScreenViewerPhase _base = BotScreenViewerPhase.connecting;
  Framebuffer? _picture;
  var _revision = 0;
  var _foreground = true;
  var _unlocked = true;
  var _visible = true;
  var _delivered = false;
  var _started = false;
  var _disposed = false;

  /// Counts the attempts to open a stream; an answer or a failure from an
  /// earlier one is out of date.
  var _run = 0;
  var _attempts = 0;
  var _ticketRetried = false;
  var _connected = false;
  var _screenRunning = false;
  String? _viewerId;

  /// The gateway connection that minted [_viewerId]; the lease calls go over
  /// it and no other.
  Object? _connection;
  var _streamPaused = false;
  Timer? _coverTimer;
  var _acquiring = false;
  var _releasing = false;
  var _closing = false;
  var _wasInControl = false;
  String? _lostCause;

  /// What the open stream was used for, for its span.
  var _use = _StreamUse();
  ScreenInput? _input;
  RfbClient? _client;

  /// The lease hash of the viewer id the open stream was ticketed with. The
  /// server accepts input only on the stream of the id that holds the lease, so
  /// `inControl` compares it on every read.
  String? _streamViewerHash;
  StreamSubscription<RfbEvent>? _events;
  Timer? _retry;

  /// The span of the open client's stream. The span of a stream still being
  /// opened is local to its run, so a superseded run cannot end a newer one.
  Span? _clientSpan;

  /// What the viewer shows now. A picture waits for the lease: it is hidden
  /// while that is unknown and blanked while another person holds control.
  BotScreenViewerPhase get phase {
    final base = _base;
    if (base != BotScreenViewerPhase.live &&
        base != BotScreenViewerPhase.reconnecting) {
      return base;
    }
    if (someoneElseInControl) return BotScreenViewerPhase.blanked;
    if (!_leaseKnown) return BotScreenViewerPhase.connecting;
    // The stream stays open through the grace period of a cover, but what is
    // typed into the screen is not shown: a snapshot of a covered app (the
    // app switcher) must not capture it.
    if (!_unlocked && screen.inControlHere) {
      return BotScreenViewerPhase.connecting;
    }
    return base;
  }

  /// What the viewer shows while a stream is being opened: the last picture
  /// dimmed if there is one.
  BotScreenViewerPhase get _waiting => _picture == null
      ? BotScreenViewerPhase.connecting
      : BotScreenViewerPhase.reconnecting;

  bool get _leaseKnown => screen.status != null;

  /// Whether a person holds control and this device is not that person: a
  /// lease naming no viewer id of this app counts as someone else, and so does
  /// a missing or unreadable one.
  bool get someoneElseInControl => screen.someoneElseInControl;

  BotScreenViewerIds get _ids => screen.viewerIds;

  /// Whether this device holds the lease on the stream the viewer shows: the
  /// lease names this stream's own viewer id (any id of this app while there is
  /// no stream) and the viewer has not been told it lost control since. A
  /// lease naming another id of this app is not driven from this stream.
  bool get inControl {
    if (_lostCause != null || !screen.inControlHere) return false;
    final stream = _streamViewerHash;
    return stream == null || screen.status?.lease.viewerHash == stream;
  }

  /// Who is driving, as far as this viewer knows.
  BotScreenControl get control {
    if (_acquiring) return BotScreenControl.acquiring;
    if (_releasing) return BotScreenControl.releasing;
    if (inControl) return BotScreenControl.inControl;
    if (_lostCause != null) return BotScreenControl.lost;
    return BotScreenControl.watching;
  }

  /// What the notice of lost control says: who has the screen now.
  String get lostText => screen.status?.lease.holder == BotScreenHolder.agent
      ? 'Hermes took control back.'
      : 'Someone else took control.';

  /// What the person in control sends input through, or null while this
  /// device is not in control or the stream is not open. It belongs to the open
  /// stream and goes with it (keys still held are released and the screen's
  /// clipboard is cleared first), so ask again after a reconnect.
  ScreenInput? get input {
    final client = _client;
    if (client == null || !inControl) return null;
    // `_forgetClient` drops the input with its client, so a live one is
    // always the open stream's.
    if (_input == null) {
      final use = _use;
      _input = ScreenInput(
        client,
        platform: platform,
        readClipboard: readClipboard,
        onEvent: () => use.inputEvents++,
      );
    }
    return _input;
  }

  void _dropInput() {
    _input?.dispose();
    _input = null;
  }

  /// Pastes the device clipboard onto the screen. A paste the screen cannot
  /// take is logged by its reason alone, never the text.
  Future<PasteOutcome> paste() async {
    final input = this.input;
    if (input == null) return PasteOutcome.closed;
    final outcome = await input.paste.paste();
    final reason = switch (outcome) {
      PasteOutcome.notLatin1 => 'not_latin1',
      PasteOutcome.tooLarge => 'too_large',
      _ => null,
    };
    if (reason != null) {
      _quiet(
        () => telemetry.events('bot_screen.paste_refused', {'reason': reason}),
      );
    }
    return outcome;
  }

  /// Whether Take over can be offered: the picture shows, Hermes holds the
  /// lease and the viewer knows the connection its id belongs to.
  bool get canTakeOver =>
      phase == BotScreenViewerPhase.live &&
      !_acquiring &&
      !_releasing &&
      !inControl &&
      !someoneElseInControl &&
      _viewerId != null &&
      _connection != null;

  /// The picture, or null when there is none to draw: while connecting, off,
  /// failed, while the lease is unknown and while someone else is in control.
  Framebuffer? get framebuffer => switch (phase) {
    BotScreenViewerPhase.live || BotScreenViewerPhase.reconnecting => _picture,
    _ => null,
  };

  /// Counts the changes to the picture, for a view that redraws on a change.
  int get revision => _revision;

  /// Whether the app is resumed. A background app has no stream.
  bool get foreground => _foreground;
  set foreground(bool value) {
    if (value == _foreground) return;
    _foreground = value;
    _syncVisible();
  }

  /// Whether App Lock is off. A locked app has no stream.
  bool get unlocked => _unlocked;
  set unlocked(bool value) {
    if (value == _unlocked) return;
    _unlocked = value;
    _syncVisible();
  }

  /// Whether the viewer is on screen: false while another route covers it.
  bool get visible => _visible;
  set visible(bool value) {
    if (value == _visible) return;
    _visible = value;
    _syncVisible();
  }

  bool get _hidden => !_foreground || !_unlocked || !_visible;

  /// Whether the app left the foreground or another route covers the viewer,
  /// as opposed to a cover that may pass in a moment.
  bool get _gone => !_foreground || !_visible;

  /// Starts watching: holds the screen's status and opens the first stream.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _watch = screen.watch(frames: false);
    _screenRunning = screen.status?.running ?? false;
    screen.addListener(_onScreen);
    _connectNow();
  }

  /// Opens the stream again, from Try Again.
  void retry() {
    if (_disposed || _hidden) return;
    _attempts = 0;
    _ticketRetried = false;
    _connectNow();
  }

  /// Starts the profile's screen, from Start Screen; the viewer then watches
  /// it as soon as it runs.
  Future<void> startScreen() async {
    try {
      await screen.start();
    } on Object {
      _logFailure('observe', 'unexpected');
      return;
    }
    if (!_disposed &&
        _base == BotScreenViewerPhase.off &&
        screen.status?.running == true) {
      _connectNow();
    }
  }

  void _onScreen() {
    if (_disposed) return;
    final running = screen.status?.running ?? false;
    final started = running && !_screenRunning;
    _screenRunning = running;
    _trackControl();
    if (started && _base == BotScreenViewerPhase.off) {
      _connectNow();
      return;
    }
    _notify();
  }

  /// Notices this device gaining or losing the lease. A lease that stops
  /// naming this device without the user's hand back is lost control.
  void _trackControl() {
    final ours = screen.inControlHere;
    if (_wasInControl && !ours && !_releasing && !_closing) {
      _lose('other_holder');
    }
    if (ours && _client != null) _use.tookOver = true;
    if (!ours) _dropInput();
    _wasInControl = ours && _lostCause == null;
  }

  void _lose(String cause) {
    if (_lostCause != null) return;
    _lostCause = cause;
    _wasInControl = false;
    _quiet(() => telemetry.events('bot_screen.lost_control', {'cause': cause}));
  }

  void _syncVisible() {
    if (_disposed || !_started) return;
    _coverTimer?.cancel();
    _coverTimer = null;
    if (!_hidden) {
      if (!_streamPaused) return;
      _attempts = 0;
      _ticketRetried = false;
      // Starting tells the listeners, which a setter that runs while the tree
      // builds must not do.
      scheduleMicrotask(() {
        if (!_hidden) _connectNow();
      });
    } else if (screen.inControlHere && !_gone) {
      // Only covered: a glance may pass, and the cover hides the picture.
      _coverTimer = Timer(coverGrace, () {
        _coverTimer = null;
        if (_hidden) _pause();
      });
    } else {
      _pause();
    }
  }

  /// Closes the stream because nobody can see it: with 4100 while this device
  /// is in control, so the server keeps the lease, else with 1000.
  void _pause() {
    _run++;
    _retry?.cancel();
    _retry = null;
    _dropStream();
    _picture = null;
    _base = BotScreenViewerPhase.connecting;
    _streamPaused = true;
    // The setters can run while the tree builds.
    scheduleMicrotask(_notify);
  }

  void _connectNow() {
    if (_disposed || _closing) return;
    if (_hidden) {
      _streamPaused = true;
      return;
    }
    _streamPaused = false;
    _retry?.cancel();
    _retry = null;
    _dropStream();
    unawaited(_connect(++_run));
  }

  bool _stale(int run) => _disposed || run != _run;

  Future<void> _connect(int run) async {
    _base = _waiting;
    _notify();
    try {
      final result = await repository.observe(
        profile,
        viewerId: _viewerId ?? _ids.latest,
      );
      if (_stale(run)) return;
      switch (result) {
        case BotScreenOk(:final value):
          await _adopt(value);
          if (_stale(run) || _closing) return;
          await _open(run, value);
        case BotScreenUnsupported():
          await _observeFailed(run, 'unsupported');
        case BotScreenFailed(:final kind):
          await _observeFailed(run, kind.slug);
      }
    } on Object {
      // Nothing may escape this method, and the error's text is not logged.
      if (_stale(run)) return;
      _logFailure('observe', 'unexpected');
      _retryLater();
    }
  }

  /// Takes what an observe answered: the viewer id and the connection that
  /// minted it, and the status with its lease. With [reacquire], a lease that
  /// names a viewer id this app held on an earlier connection is taken over
  /// with the new id, so a person in the middle of a login stays in control
  /// across a reconnect; that is only for a viewer with no stream of its own
  /// open, because the bridge answers the new holder by evicting the stream of
  /// the old one. Nothing is taken while the viewer is shutting down.
  Future<void> _adopt(
    BotScreenObservation observation, {
    bool reacquire = true,
  }) async {
    if (_closing || _disposed) return;
    final id = observation.viewerId;
    _viewerId = id;
    _connection = observation.connection;
    _ids.add(id);
    // The answer carries the screen's status and so the lease.
    screen.adoptStatus(observation.status);
    final lease = observation.status.lease;
    if (lease.holder != BotScreenHolder.human ||
        !_ids.holds(lease.viewerHash)) {
      return;
    }
    if (lease.viewerHash == BotScreenViewerIds.hashOf(id)) {
      _lostCause = null;
      return;
    }
    final connection = observation.connection;
    if (!reacquire || connection == null) return;
    var outcome = 'error';
    try {
      final result = await repository.acquire(
        profile,
        viewerId: id,
        connection: connection,
      );
      if (result case BotScreenOk(:final value)) {
        if (_closing || _disposed) {
          // Shut down meanwhile: what was just taken is not kept.
          if (_holdsLease(value)) unawaited(_releaseQuietly(id, connection));
          return;
        }
        screen.adoptLease(value);
        _lostCause = null;
        outcome = _holdsLease(value) ? 'resumed' : 'refused';
      } else {
        outcome = 'refused';
      }
    } on Object {
      outcome = 'error';
    }
    _logTakeover(outcome);
  }

  /// Gives the lease back without waiting for or reporting the answer.
  Future<void> _releaseQuietly(String id, Object connection) async {
    try {
      await repository.release(profile, viewerId: id, connection: connection);
    } on Object {
      return;
    }
  }

  /// Whether [lease] names a viewer id of this app.
  bool _holdsLease(BotScreenLease lease) =>
      lease.holder == BotScreenHolder.human && _ids.holds(lease.viewerHash);

  /// `display.observe` carries no machine-readable reason, so the status
  /// tells a stopped screen from a failure.
  Future<void> _observeFailed(int run, String errorType) async {
    final status = await repository.status(profile);
    if (_stale(run)) return;
    if (status case BotScreenOk(:final value) when !value.running) {
      _picture = null;
      _base = BotScreenViewerPhase.off;
      _notify();
      return;
    }
    _logFailure('observe', errorType);
    _retryLater();
  }

  Future<void> _open(int run, BotScreenObservation observation) async {
    if (_closing || _disposed) return;
    final span = _startSpan();
    final WebSocketChannel channel;
    try {
      channel = await openSocket(observation.path, observation.ticket);
    } on DisplaySocketError catch (error) {
      if (_stale(run)) return _endSpan(span, 'closed');
      _logFailure('connect', error.kind.name);
      if (error.kind == DisplaySocketErrorKind.notAllowed) {
        _endSpan(span, 'not_allowed');
        _picture = null;
        _base = BotScreenViewerPhase.notAllowed;
        _notify();
      } else {
        _endSpan(span, 'error');
        _retryLater();
      }
      return;
    } on Object {
      // Whatever the opener threw, its message may name the ticket.
      if (_stale(run)) return _endSpan(span, 'closed');
      _logFailure('connect', 'unreachable');
      _endSpan(span, 'error');
      _retryLater();
      return;
    }
    if (_stale(run) || _closing) {
      _endSpan(span, 'closed', code: 1000);
      unawaited(_closeQuietly(channel));
      return;
    }
    _connected = false;
    _delivered = false;
    _use = _StreamUse()..tookOver = screen.inControlHere;
    final client = _client = RfbClient(channel);
    _streamViewerHash = BotScreenViewerIds.hashOf(observation.viewerId);
    _clientSpan = span;
    _events = client.events.listen((event) => _onEvent(run, client, event));
  }

  void _onEvent(int run, RfbClient client, RfbEvent event) {
    if (_stale(run) || !identical(client, _client)) return;
    switch (event) {
      case RfbConnected():
        // The framebuffer is black until the first update, so the last
        // picture stays and the viewer is not live yet.
        _connected = true;
      case RfbUpdated() || RfbResized():
        if (!_delivered) {
          // A stream that delivers a picture has earned its attempts anew.
          _delivered = true;
          _attempts = 0;
          _ticketRetried = false;
          _base = BotScreenViewerPhase.live;
        }
        _picture = client.framebuffer;
        _revision++;
        _notify();
      case RfbEnded():
        _ended(run, client, event);
    }
  }

  /// The stream ended without the app closing it.
  void _ended(int run, RfbClient client, RfbEnded ended) {
    final code = ended.closeCode;
    final failure = ended.failure;
    final step = switch (ended.step) {
      RfbStep.handshake => 'handshake',
      RfbStep.decode => 'decode',
      null => _connected ? 'decode' : 'handshake',
    };
    final span = _clientSpan;
    final use = _use;
    _forgetClient();
    void end(String outcome, String errorType) {
      _logFailure(step, errorType);
      _endSpan(span, outcome, code: code, client: client, use: use);
    }

    switch (code) {
      case 4000:
        // Another person took control from this viewer; watch again.
        if (_wasInControl && !_releasing && !_closing) _lose('control_taken');
        end('closed', 'control_taken');
        _retryLater(immediate: true);
      case 4001:
        end('gone', 'gone');
        _picture = null;
        _base = BotScreenViewerPhase.off;
        _notify();
      case 4401:
        end('ticket', 'ticket');
        if (_ticketRetried) {
          _picture = null;
          _base = BotScreenViewerPhase.failed;
          _notify();
        } else {
          _ticketRetried = true;
          _connectNow();
        }
      case 1000 || 1001 when failure == null:
        // The bridge closes this way when Xvnc's end of the stream is gone,
        // which is how a stopped screen shows.
        unawaited(_closedByServer(run, client, ended, span, step, use));
      case 1003:
        end('protocol', 'protocol');
        _picture = null;
        _base = BotScreenViewerPhase.failed;
        _notify();
      default:
        end('error', failure?.name ?? 'closed');
        _retryLater();
    }
  }

  /// A clean close from the server: Off when the screen is not running any
  /// more, else a stream that ended and is opened again.
  Future<void> _closedByServer(
    int run,
    RfbClient client,
    RfbEnded ended,
    Span? span,
    String step,
    _StreamUse use,
  ) async {
    BotScreenResult<BotScreenStatus> status;
    try {
      status = await repository.status(profile);
    } on Object {
      status = const BotScreenFailed(BotScreenFailure.display);
    }
    if (_stale(run)) {
      _endSpan(span, 'closed', code: ended.closeCode, client: client, use: use);
      return;
    }
    if (status case BotScreenOk(:final value) when !value.running) {
      _endSpan(span, 'gone', code: ended.closeCode, client: client, use: use);
      _picture = null;
      _base = BotScreenViewerPhase.off;
      _notify();
      return;
    }
    _logFailure(step, 'closed');
    _endSpan(span, 'error', code: ended.closeCode, client: client, use: use);
    _retryLater();
  }

  /// Opens the stream again after a jittered, growing delay (at once with
  /// [immediate]), or gives up after [kViewerReconnectAttempts].
  void _retryLater({bool immediate = false}) {
    if (_disposed || _closing) return;
    if (_hidden) {
      // Opened again when the viewer can be seen (see `_syncVisible`).
      _streamPaused = true;
      return;
    }
    if (_attempts >= kViewerReconnectAttempts) {
      _picture = null;
      _base = BotScreenViewerPhase.unreachable;
      _notify();
      return;
    }
    if (immediate) {
      _attempts++;
      _connectNow();
      return;
    }
    final delay = reconnectDelay(_attempts++, _random);
    _base = _waiting;
    _notify();
    _retry?.cancel();
    _retry = Timer(delay, () {
      _retry = null;
      _connectNow();
    });
  }

  /// Forgets the client once its stream ended.
  void _forgetClient() {
    unawaited(_events?.cancel());
    _events = null;
    _client = null;
    _streamViewerHash = null;
    _clientSpan = null;
    _use = _StreamUse();
    _dropInput();
  }

  /// Closes the open stream, if any, as the app's own doing: with 1000, which
  /// the server takes as the viewer leaving and answers by handing the lease
  /// back, or with 4100 while this device is in control and means to come
  /// back, which it takes as a dropped link and keeps the lease for. [code]
  /// overrides that choice.
  void _dropStream({int? code}) {
    final client = _client;
    if (client == null) return;
    final span = _clientSpan;
    final closeCode =
        code ?? (screen.inControlHere ? kCloseKeepingControl : 1000);
    final use = _use;
    _forgetClient();
    _endSpan(span, 'closed', code: closeCode, client: client, use: use);
    unawaited(client.close(closeCode).catchError((Object _) {}));
  }

  Future<void> _closeQuietly(WebSocketChannel channel) async {
    try {
      await channel.sink.close(1000);
    } on Object {
      return;
    }
  }

  Span? _startSpan() {
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        'bot_screen.stream',
        attributes: telemetry.serverAttributes,
      ),
    );
    return span;
  }

  /// Ends the stream's span with its outcome, the close code, whether the user
  /// took over during the stream, the encodings used and the bytes received in
  /// a bucket. Never the ticket, the path or the viewer id.
  void _endSpan(
    Span? span,
    String outcome, {
    int? code,
    RfbClient? client,
    _StreamUse? use,
  }) {
    if (span == null) return;
    _quiet(() {
      span.setAttribute('outcome', outcome);
      span.setAttribute('took_over', use?.tookOver ?? false);
      span.setAttribute('input_events', _eventsBucket(use?.inputEvents ?? 0));
      if (code != null) span.setAttribute('close_code', code);
      if (client != null) {
        final names = [
          for (final encoding in client.encodingsSeen)
            _encodingNames[encoding] ?? 'other',
        ]..sort();
        span.setAttribute(
          'encodings_used',
          names.isEmpty ? 'none' : names.toSet().join(','),
        );
        span.setAttribute(
          'kib_received',
          _bucket(client.bytesReceived ~/ 1024),
        );
      }
      span.end();
    });
  }

  /// How many input events a stream sent, in a bucket: never which.
  static String _eventsBucket(int events) => switch (events) {
    0 => '0',
    <= 10 => '1-10',
    <= 100 => '11-100',
    _ => '>100',
  };

  static String _bucket(int kib) => switch (kib) {
    < 256 => '<256',
    < 4096 => '256-4096',
    _ => '>=4096',
  };

  // Control ------------------------------------------------------------------

  /// Takes control of the screen for this device. Asking the user first is the
  /// caller's job. The acquire goes over the connection that minted the viewer
  /// id; if that connection is gone or the server does not know the id, the
  /// viewer observes again and tries once more with the id it gets, and the
  /// stream follows it, since the server accepts input only on the stream of
  /// the id that holds the lease.
  Future<void> takeOver() async {
    if (!canTakeOver) return;
    final run = _run;
    final id = _viewerId!, connection = _connection!;
    _lostCause = null;
    _acquiring = true;
    _notify();
    var outcome = 'error';
    try {
      var step = await _acquire(id, connection);
      if (step == _Step.retry && !_disposed) {
        _logTakeover('retried');
        final fresh = await _observeAgain(reacquire: false);
        if (fresh == null || fresh.connection == null) {
          step = _Step.refused;
        } else if (_disposed || _closing || _stale(run)) {
          step = _Step.refused;
        } else {
          // The stream carries the old id: follow the new one, whatever the
          // acquire answers, since the old id is of no use any more.
          _run++;
          _dropStream(code: 1000);
          await _open(_run, fresh);
          step = await _acquire(fresh.viewerId, fresh.connection!);
        }
      }
      outcome = step == _Step.done ? 'acquired' : 'refused';
    } on Object {
      outcome = 'error';
    } finally {
      _acquiring = false;
    }
    _logTakeover(outcome);
    _notify();
  }

  /// Gives control back to Hermes, from the Hand Back button ([reason]
  /// `button`) or because the viewer is closing. The stream stays open and the
  /// viewer watches. Answers whether the lease is no longer this device's. The
  /// request is sent before anything is awaited, so an owner that is going
  /// away can start it from its own teardown.
  Future<bool> handBack({String reason = 'button'}) async {
    final id = _viewerId, connection = _connection;
    if (_disposed ||
        _releasing ||
        !screen.inControlHere ||
        id == null ||
        connection == null) {
      return false;
    }
    _releasing = true;
    // An owner that is being torn down starts this from its dispose, when
    // nothing may rebuild.
    scheduleMicrotask(_notify);
    var done = false;
    try {
      var step = await _release(id, connection);
      if (step == _Step.retry && !_disposed) {
        if (_client != null) {
          // The id cannot be released over this connection, but the stream
          // that holds the lease can end: the bridge takes a clean close of
          // the holder's stream as its release.
          step = await _releaseByClosing() ? _Step.done : _Step.refused;
        } else if (!_closing) {
          final fresh = await _observeAgain();
          step = fresh == null || fresh.connection == null
              ? _Step.refused
              : await _release(fresh.viewerId, fresh.connection!);
        }
      }
      done = step == _Step.done;
    } on Object {
      done = false;
    } finally {
      _releasing = false;
    }
    _logHandBack(done ? reason : 'error');
    _notify();
    return done;
  }

  /// Hands control back to Hermes from a lease no viewer of this app holds,
  /// from Hand back to Hermes. The caller asks the user first.
  Future<bool> forceHandBack() => screen.forceHandBack();

  /// Closes the viewer for good: hands control back first when this device is
  /// in control (waiting at most [kViewerReleaseBudget] for the server), then
  /// closes the stream with 1000 and disposes. [reason] is why, for the log:
  /// `close`, `sign_out`, `profile` or `server`. The owner calls this where it
  /// would call [dispose].
  Future<void> shutDown(String reason) async {
    if (_disposed) return;
    _closing = true;
    _retry?.cancel();
    _retry = null;
    _coverTimer?.cancel();
    _coverTimer = null;
    if (screen.inControlHere) {
      try {
        await handBack(reason: reason)
            .timeout(kViewerReleaseBudget, onTimeout: () => false);
      } on Object {
        // The close below hands the lease back as well.
      }
    }
    dispose();
  }

  /// Forgets the notice that this device lost control.
  void dismissLost() {
    if (_lostCause == null) return;
    _lostCause = null;
    _notify();
  }

  Future<_Step> _acquire(String id, Object connection) async => _stepOf(
    await repository.acquire(profile, viewerId: id, connection: connection),
    holding: true,
  );

  Future<_Step> _release(String id, Object connection) async {
    final result = await repository.release(
      profile,
      viewerId: id,
      connection: connection,
    );
    if (result case BotScreenOk(:final value)
        when _holdsLease(value) &&
            value.viewerHash != BotScreenViewerIds.hashOf(id)) {
      // The lease names an id this app held before the connection changed,
      // which no release by this id can free.
      screen.adoptLease(value);
      return _Step.retry;
    }
    return _stepOf(result, holding: false);
  }

  /// Ends the open stream with 1000, which the bridge answers by handing the
  /// lease back when the stream is its holder's, and answers whether the lease
  /// is not this device's afterwards. While shutting down the answer is not
  /// waited for (the gateway may be going away too) and the close counts as the
  /// hand back; otherwise the viewer watches again on a new stream.
  Future<bool> _releaseByClosing() async {
    _dropStream(code: 1000);
    if (_closing) return true;
    var released = false;
    for (var attempt = 0; attempt < 3 && !released; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (_disposed) return false;
      final status = await repository.status(profile);
      if (status case BotScreenOk(:final value)) {
        screen.adoptStatus(value);
        released = !_holdsLease(value.lease);
      }
    }
    if (!_disposed && !_closing) {
      _attempts = 0;
      _connectNow();
    }
    return released;
  }

  /// How a lease call ended, taking the lease it answered. [holding] is
  /// whether the call meant to leave this device holding it. A closed
  /// connection, an id the server does not know and a call that got no answer
  /// say the connection or the id is no longer good.
  _Step _stepOf(
    BotScreenResult<BotScreenLease> result, {
    required bool holding,
  }) {
    switch (result) {
      case BotScreenOk(:final value):
        screen.adoptLease(value);
        return _holdsLease(value) == holding ? _Step.done : _Step.refused;
      case BotScreenFailed(:final kind)
          when kind == BotScreenFailure.closed ||
              kind == BotScreenFailure.mismatch ||
              kind == BotScreenFailure.timeout:
        return _Step.retry;
      case _:
        return _Step.refused;
    }
  }

  /// Asks for a ticket again, which gives the id and the connection the
  /// gateway has now. Null when that fails. See [_adopt] for [reacquire].
  Future<BotScreenObservation?> _observeAgain({bool reacquire = true}) async {
    final result = await repository.observe(profile, viewerId: _viewerId);
    if (_disposed) return null;
    if (result case BotScreenOk(:final value)) {
      await _adopt(value, reacquire: reacquire);
      return value;
    }
    return null;
  }

  void _logTakeover(String outcome) => _quiet(
    () => telemetry.events('bot_screen.takeover', {'outcome': outcome}),
  );

  void _logHandBack(String reason) =>
      _quiet(() => telemetry.events('bot_screen.handback', {'reason': reason}));

  void _logFailure(String step, String errorType) => _quiet(
    () => telemetry.events('bot_screen.stream_failed', {
      'step': step,
      'error_type': errorType,
    }),
  );

  /// Telemetry must never break the app.
  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    // An owner that did not hand back first still must not leave the lease
    // behind; the 1000 below frees it as well, this makes it explicit.
    if (!_closing) unawaited(handBack(reason: 'close'));
    _disposed = true;
    _run++;
    _retry?.cancel();
    _retry = null;
    _coverTimer?.cancel();
    _coverTimer = null;
    _dropStream(code: 1000);
    _picture = null;
    screen.removeListener(_onScreen);
    _watch?.release();
    _watch = null;
    super.dispose();
  }
}

/// How a lease call ended: it did what was asked, the connection or the id is
/// no longer good and an observe repairs it, or it was refused.
enum _Step { done, retry, refused }

/// What one stream was used for, for its span.
class _StreamUse {
  var tookOver = false;
  var inputEvents = 0;
}
