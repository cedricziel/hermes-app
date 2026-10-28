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

/// The names the span gives the RFB encodings the stream used.
const _encodingNames = {
  0: 'raw',
  1: 'copyrect',
  16: 'zrle',
  -223: 'desktop_size',
};

/// One watch-only view of a profile's Bot Screen: it asks `display.observe`
/// for a ticket, opens the display stream with it, keeps the framebuffer
/// current and decides what each way the stream can end means.
///
/// The stream is open only while the viewer can be seen: [foreground] and
/// [unlocked] close it with 1000 and drop the picture, and [dispose] does the
/// same for good. The server counts an attached viewer as use and skips its
/// idle stop, so a stream is never kept for a viewer nobody sees.
///
/// Nothing here sends input. The ticket, the stream path and the viewer id are
/// credentials: they live in this object's memory and in no log, span or
/// breadcrumb.
class BotScreenViewerController extends ChangeNotifier {
  /// [screen] supplies the lease and is watched for as long as the viewer
  /// lives, so its status stays current. [openSocket] opens the stream.
  BotScreenViewerController({
    required this.repository,
    required this.screen,
    required this.openSocket,
    this.profile,
    this.telemetry = const ConnectionTelemetry(),
    Random? random,
  }) : _random = random ?? Random();

  final BotScreenRepository repository;
  final BotScreenController screen;
  final DisplaySocketOpener openSocket;

  /// The profile watched; null is the server's default.
  final String? profile;
  final ConnectionTelemetry telemetry;
  final Random _random;

  BotScreenWatch? _watch;
  BotScreenViewerPhase _base = BotScreenViewerPhase.connecting;
  Framebuffer? _picture;
  var _revision = 0;
  var _foreground = true;
  var _unlocked = true;
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
  RfbClient? _client;
  StreamSubscription<RfbEvent>? _events;
  Timer? _retry;
  Span? _span;

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
    return base;
  }

  /// What the viewer shows while a stream is being opened: the last picture
  /// dimmed if there is one.
  BotScreenViewerPhase get _waiting => _picture == null
      ? BotScreenViewerPhase.connecting
      : BotScreenViewerPhase.reconnecting;

  bool get _leaseKnown => screen.status != null;

  /// Whether a person holds control and this device is not known to be that
  /// person. A missing or unreadable lease counts as a person in control.
  bool get someoneElseInControl =>
      screen.status?.lease.holder == BotScreenHolder.human;

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

  bool get _hidden => !_foreground || !_unlocked;

  /// Starts watching: holds the screen's status and opens the first stream.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _watch = screen.watch();
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
    await screen.start();
    if (!_disposed &&
        _base == BotScreenViewerPhase.off &&
        screen.status?.running == true) {
      _connectNow();
    }
  }

  void _onScreen() {
    final running = screen.status?.running ?? false;
    final started = running && !_screenRunning;
    _screenRunning = running;
    if (started && _base == BotScreenViewerPhase.off) {
      _connectNow();
      return;
    }
    _notify();
  }

  void _syncVisible() {
    if (_disposed || !_started) return;
    if (_hidden) {
      _run++;
      _retry?.cancel();
      _retry = null;
      _dropStream();
      _picture = null;
      _base = BotScreenViewerPhase.connecting;
      // The setters can run while the tree builds.
      scheduleMicrotask(_notify);
    } else {
      _attempts = 0;
      _ticketRetried = false;
      _connectNow();
    }
  }

  void _connectNow() {
    if (_disposed || _hidden) return;
    _retry?.cancel();
    _retry = null;
    _dropStream();
    unawaited(_connect(++_run));
  }

  bool _stale(int run) => _disposed || run != _run;

  Future<void> _connect(int run) async {
    _base = _waiting;
    _notify();
    final result = await repository.observe(profile, viewerId: _viewerId);
    if (_stale(run)) return;
    switch (result) {
      case BotScreenOk(:final value):
        _viewerId = value.viewerId;
        await _open(run, value);
      case BotScreenUnsupported():
        await _observeFailed(run, 'unsupported');
      case BotScreenFailed(:final kind):
        await _observeFailed(run, kind.slug);
    }
  }

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
    _startSpan();
    final WebSocketChannel channel;
    try {
      channel = await openSocket(observation.path, observation.ticket);
    } on DisplaySocketError catch (error) {
      if (_stale(run)) return _endSpan('closed');
      _logFailure('connect', error.kind.name);
      if (error.kind == DisplaySocketErrorKind.notAllowed) {
        _endSpan('not_allowed');
        _picture = null;
        _base = BotScreenViewerPhase.notAllowed;
        _notify();
      } else {
        _endSpan('error');
        _retryLater();
      }
      return;
    } on Object {
      // Whatever the opener threw, its message may name the ticket.
      if (_stale(run)) return _endSpan('closed');
      _logFailure('connect', 'unreachable');
      _endSpan('error');
      _retryLater();
      return;
    }
    if (_stale(run)) {
      _endSpan('closed', code: 1000);
      unawaited(_closeQuietly(channel));
      return;
    }
    _connected = false;
    final client = _client = RfbClient(channel);
    _events = client.events.listen((event) => _onEvent(run, client, event));
  }

  void _onEvent(int run, RfbClient client, RfbEvent event) {
    if (_stale(run) || !identical(client, _client)) return;
    switch (event) {
      case RfbConnected():
        _connected = true;
        _attempts = 0;
        _ticketRetried = false;
        _picture = client.framebuffer;
        _base = BotScreenViewerPhase.live;
        _revision++;
        _notify();
      case RfbUpdated() || RfbResized():
        _picture = client.framebuffer;
        _revision++;
        _notify();
      case RfbEnded():
        _ended(client, event);
    }
  }

  /// The stream ended without the app closing it.
  void _ended(RfbClient client, RfbEnded ended) {
    final code = ended.closeCode;
    final failure = ended.failure;
    final step = switch (ended.step) {
      RfbStep.handshake => 'handshake',
      RfbStep.decode => 'decode',
      null => _connected ? 'decode' : 'handshake',
    };
    _forgetClient();
    void end(String outcome, String errorType) {
      _logFailure(step, errorType);
      _endSpan(outcome, code: code, client: client);
    }

    switch (code) {
      case 4000:
        // Another person took control from this viewer; watch again.
        end('closed', 'control_taken');
        _connectNow();
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

  /// Opens the stream again after a jittered, growing delay, or gives up.
  void _retryLater() {
    if (_disposed || _hidden) return;
    if (_attempts >= kViewerReconnectAttempts) {
      _picture = null;
      _base = BotScreenViewerPhase.unreachable;
      _notify();
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
  }

  /// Closes the open stream, if any, as the app's own doing (1000).
  void _dropStream() {
    final client = _client;
    if (client == null) return;
    _forgetClient();
    _endSpan('closed', code: 1000, client: client);
    unawaited(client.close(1000).catchError((Object _) {}));
  }

  Future<void> _closeQuietly(WebSocketChannel channel) async {
    try {
      await channel.sink.close(1000);
    } on Object {
      return;
    }
  }

  void _startSpan() {
    _span = null;
    _quiet(
      () => _span = telemetry.tracer?.startSpan(
        'bot_screen.stream',
        attributes: telemetry.serverAttributes,
      ),
    );
  }

  /// Ends the stream's span with its outcome, the close code, the encodings
  /// used and the bytes received in a bucket. Never the ticket or the path.
  void _endSpan(String outcome, {int? code, RfbClient? client}) {
    final span = _span;
    _span = null;
    if (span == null) return;
    _quiet(() {
      span.setAttribute('outcome', outcome);
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

  static String _bucket(int kib) => switch (kib) {
    < 256 => '<256',
    < 4096 => '256-4096',
    _ => '>=4096',
  };

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
    _disposed = true;
    _run++;
    _retry?.cancel();
    _retry = null;
    _dropStream();
    _picture = null;
    screen.removeListener(_onScreen);
    _watch?.release();
    _watch = null;
    super.dispose();
  }
}
