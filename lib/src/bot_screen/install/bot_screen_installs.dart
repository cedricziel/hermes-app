import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../../chat/gateway/gateway_rpc_client.dart';
import '../../chat/gateway/hermes_gateway_transport.dart'
    show ServerRequestHandler;
import '../../chat/gateway_connection_transport.dart';
import '../../surfaces/surface_snapshot.dart' show kDefaultProfile;
import '../../telemetry/telemetry.dart';
import '../bot_screen_models.dart';
import '../bot_screen_repository.dart';
import 'install_state.dart';

/// How long an install may run without `display.install.done` before the app
/// stops waiting for it.
const kInstallPatience = Duration(minutes: 20);

/// The sudo request method Hermes asks the password with.
const kSudoRequestMethod = 'display.install.sudo';

/// Registers [handler] for the server requests of a method; the returned
/// function removes the registration
/// (`HermesGatewayTransport.registerServerRequestHandler`).
typedef RegisterServerRequestHandler = void Function() Function(
  String method,
  ServerRequestHandler handler,
);

/// Asks the user for the sudo password of the Hermes host [host] and answers
/// it, or null when they cancel or dismiss the question. [ended] completes
/// when the install is over and the question no longer matters.
typedef SudoPasswordAsker = Future<String?> Function(
  String host,
  Future<void> ended,
);

/// The Bot screen installs of one gateway connection, which outlive any chat
/// or Activity panel.
///
/// Pressing Install on Server sends `display.install` and follows that
/// install's `display.install.log` and `display.install.done` broadcasts by
/// the profile's key. While one runs, this answers the `display.install.sudo`
/// request, which only the connection that started the install receives, by
/// asking the user through [askPassword]; any request for an install this
/// did not start on that connection is refused, as are all of them while none
/// runs. The password goes into that answer and nowhere else: it is not
/// stored, logged or kept.
///
/// A missed `display.install.done` (a lost connection, a suspended app) is
/// made up for by reading `display.status` when the app resumes and after the
/// connection was lost, and by giving up after [patience].
///
/// Log lines, the install command and the host are shown, never logged. The
/// span and the log event `bot_screen.install` carry `outcome` and
/// `asked_password` only.
class BotScreenInstalls extends ChangeNotifier {
  BotScreenInstalls({
    required this._repository,
    required Stream<GatewayConnectionEvent> connectionEvents,
    required this._connection,
    required this._registerServerRequestHandler,
    required this._askPassword,
    required this.host,
    this.telemetry = const ConnectionTelemetry(),
    this.patience = kInstallPatience,
  }) {
    _events = connectionEvents.listen(
      _onConnectionEvent,
      onError: (Object _, StackTrace _) => _readStatuses(),
    );
  }

  /// The Hermes host named in the password question; shown, never logged.
  final String host;
  final ConnectionTelemetry telemetry;
  final Duration patience;

  final BotScreenRepository _repository;
  final Object? Function() _connection;
  final RegisterServerRequestHandler _registerServerRequestHandler;
  final SudoPasswordAsker _askPassword;
  late final StreamSubscription<GatewayConnectionEvent> _events;

  /// How each profile's latest install ended, by profile name.
  final _ended = <String, InstallEnded>{};
  final _running = <_Install>[];
  void Function()? _unregister;
  var _disposed = false;

  /// What the install of [profile] (null is the default profile) is doing or
  /// ended with; null when none was started.
  InstallState? stateFor(String? profile) {
    final name = profile ?? kDefaultProfile;
    for (final install in _running) {
      if (install.profile == name) {
        return InstallRunning(
          lines: List.unmodifiable(install.lines),
          askedPassword: install.askedPassword,
        );
      }
    }
    return _ended[name];
  }

  /// Presses Install on Server for [profile]. [profileKey] is the key of the
  /// profile as `display.status` reported it, so the broadcasts that arrive
  /// before Hermes' answer are not lost. Does nothing while an install of
  /// that profile runs.
  Future<void> start(String? profile, {String? profileKey}) async {
    final name = profile ?? kDefaultProfile;
    if (_disposed || _running.any((install) => install.profile == name)) return;
    final install = _Install(name, profileKey, _connection());
    install.span = _startSpan();
    _running.add(install);
    _ended.remove(name);
    _syncHandler();
    _notify();
    final result = await _repository.install(profile);
    if (_disposed || !_running.contains(install)) return;
    switch (result) {
      case BotScreenOk(:final value):
        install
          ..profileKey = value.profileKey
          ..command = value.command
          ..connection = _connection() ?? install.connection
          ..timer = Timer(patience, () => _giveUp(install));
      case BotScreenUnsupported():
        _finish(install, const InstallRefused());
      case BotScreenFailed(:final kind, :final message):
        // A refusal has Hermes' words; no answer at all is a failure to
        // reach it.
        _finish(
          install,
          message != null
              ? InstallRefused(message: message)
              : InstallUnreachable(kind),
        );
    }
  }

  /// Reads the status of every running install: the app returned to the
  /// foreground and may have missed the done broadcast.
  void resumed() => _readStatuses();

  void _onConnectionEvent(GatewayConnectionEvent signal) {
    if (!signal.connected) {
      for (final install in _running) {
        if (identical(install.connection, signal.connection)) {
          install.connection = null;
        }
      }
      return _readStatuses();
    }
    final event = signal.event;
    if (event == null) return;
    final payload = event.payload;
    switch (event.type) {
      case 'display.install.log':
        final install = _installOf(payload['profile_key']);
        final line = payload['line'];
        if (install == null || line is! String) return;
        final text = line.trimRight();
        if (text.isEmpty) return;
        install.lines.add(text);
        if (install.lines.length > kInstallLines) install.lines.removeAt(0);
        _notify();
      case 'display.install.done':
        final install = _installOf(payload['profile_key']);
        final code = payload['code'];
        final status = payload['status'];
        if (install == null || code is! num) return;
        _done(
          install,
          code.toInt(),
          status is Map<String, Object?>
              ? BotScreenStatus.fromJson(status)
              : null,
        );
    }
  }

  /// The running install whose broadcasts carry [key]; with [connection], the
  /// one that went over that socket.
  _Install? _installOf(Object? key, {Object? connection}) {
    for (final install in _running) {
      if (install.profileKey == key &&
          (connection == null || identical(install.connection, connection))) {
        return install;
      }
    }
    return null;
  }

  void _done(_Install install, int code, BotScreenStatus? status) {
    final result = switch (code) {
      0 => const InstallInstalled(),
      -1 => const InstallCancelled(),
      -2 => InstallNoSudo(command: status?.installCommand ?? install.command),
      _ => InstallFailed(lines: List.of(install.lines)),
    };
    _finish(install, result, status: status);
  }

  void _readStatuses() {
    for (final install in List.of(_running)) {
      unawaited(_checkInstalled(install));
    }
  }

  /// Ends [install] as installed when the status says the packages are there.
  /// Returns whether it did.
  Future<bool> _checkInstalled(_Install install) async {
    final result = await _repository.status(install.profile);
    if (_disposed || !_running.contains(install)) return false;
    if (result case BotScreenOk(:final value) when value.installed) {
      _finish(install, const InstallInstalled(), status: value);
      return true;
    }
    return false;
  }

  Future<void> _giveUp(_Install install) async {
    if (await _checkInstalled(install)) return;
    if (_disposed || !_running.contains(install)) return;
    _finish(install, const InstallMayStillRun());
  }

  Future<Map<String, Object?>> _onSudoRequest(
    GatewayServerRequest request,
    Object connection,
  ) async {
    final install = _installOf(
      request.params['profile_key'],
      connection: connection,
    );
    if (install == null || install.prompting) {
      throw const GatewayRpcException(-32602, 'Not requested');
    }
    install
      ..prompting = true
      ..askedPassword = true;
    _notify();
    try {
      return {'value': await _askPassword(host, install.ended.future) ?? ''};
    } finally {
      install.prompting = false;
    }
  }

  void _finish(
    _Install install,
    InstallResult result, {
    BotScreenStatus? status,
  }) {
    if (!_running.remove(install)) return;
    install.timer?.cancel();
    if (!install.ended.isCompleted) install.ended.complete();
    _ended[install.profile] = InstallEnded(result, status: status);
    _syncHandler();
    final outcome = result.outcome;
    _quiet(() {
      install.span
        ?..setAttribute('outcome', outcome)
        ..setAttribute('asked_password', install.askedPassword)
        ..end();
      telemetry.events('bot_screen.install', {
        'outcome': outcome,
        'asked_password': install.askedPassword,
      });
    });
    _notify();
  }

  /// Answers the sudo request while an install runs, and only then, so that
  /// the transport refuses it itself the rest of the time.
  void _syncHandler() {
    if (_running.isEmpty) {
      _unregister?.call();
      _unregister = null;
    } else {
      _unregister ??= _registerServerRequestHandler(
        kSudoRequestMethod,
        _onSudoRequest,
      );
    }
  }

  Span? _startSpan() {
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        'bot_screen.install',
        attributes: telemetry.serverAttributes,
      ),
    );
    return span;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Telemetry must never break the app.
  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_events.cancel());
    _unregister?.call();
    _unregister = null;
    for (final install in _running) {
      install.timer?.cancel();
      if (!install.ended.isCompleted) install.ended.complete();
      _quiet(() => install.span?.end());
    }
    _running.clear();
    super.dispose();
  }
}

/// One install this app started and that has not ended.
class _Install {
  _Install(this.profile, this.profileKey, this.connection);

  final String profile;

  /// The key its broadcasts carry; known from the status before Hermes
  /// answers, and confirmed by the answer.
  String? profileKey;

  /// The socket `display.install` went over, which is the only one the sudo
  /// request arrives on; null once it was lost.
  Object? connection;
  String? command;
  final lines = <String>[];
  var askedPassword = false;
  var prompting = false;
  Span? span;
  Timer? timer;
  final ended = Completer<void>();
}
