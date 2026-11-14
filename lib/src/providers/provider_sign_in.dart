import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart';

import '../network/poll_backoff.dart';
import '../shell/app_presence.dart';
import 'provider_links.dart';
import 'provider_results.dart';
import 'provider_signals.dart';
import 'providers_repository.dart';

/// Where a device-code sign-in stands.
enum SignInPhase {
  /// Asking Hermes for a code.
  starting,

  /// Hermes refused to start ([ProviderSignIn.message] has its sentence, if
  /// it gave one), for example because the account is already signed in.
  startRefused,

  /// The start got no answer.
  startFailed,

  /// The code is shown and the app polls.
  waiting,
  approved,
  denied,

  /// Expired, the server forgot it (404), or the code outlived its lifetime
  /// plus [kSignInGrace].
  expired,

  /// Hermes reported an error ([ProviderSignIn.message] when it said why).
  failed,

  /// The person stopped it and the server's poller was told to stop.
  cancelled,
}

/// How long past the code's lifetime a sign-in waits before it counts as
/// expired.
const kSignInGrace = Duration(seconds: 30);

const _minInterval = 2;
const _maxInterval = 10;

/// One device-code sign-in of one provider for one profile.
///
/// It starts the sign-in, shows the code and polls Hermes at the server's
/// interval (kept between 2 and 10 seconds) until the sign-in ends. Failed
/// polls back off ([PollBackoff]) without ending it. On iOS and Android the
/// timer pauses while the app is in the background and one poll runs at once
/// when it returns; on desktop it keeps running.
///
/// [close] stops polling without cancelling: the server keeps the session up
/// to 15 minutes and a later approval still saves the credential. [cancel]
/// is the person's Stop and tells the server.
///
/// The poll's `model` is never read: it does not say whether Hermes moved the
/// default (see design.md). The device code is held only while the sign-in
/// waits.
class ProviderSignIn extends ChangeNotifier {
  ProviderSignIn({
    required this.repository,
    required this.profile,
    required this.providerId,
    TargetPlatform? platform,
    this.onEnded,
  }) : _platform = platform ?? defaultTargetPlatform,
       _signals = ProviderSignals(repository.telemetry);

  final ProvidersRepository repository;

  /// The profile the sign-in was started for; it keeps following that one.
  final String? profile;
  final String providerId;
  final void Function(ProviderSignIn signIn)? onEnded;
  final TargetPlatform _platform;
  final ProviderSignals _signals;

  SignInPhase _phase = SignInPhase.starting;
  SignInSession? _session;
  String? _message;
  String? _accountEmail;
  bool _offline = false;
  bool _closed = false;
  bool _background = false;
  bool _polling = false;
  int _polls = 0;
  int _run = 0;
  final _cancelOnArrival = <int>{};
  DateTime? _deadline;
  Timer? _timer;
  Timer? _lifetime;
  Span? _span;
  final _backoff = PollBackoff();

  SignInPhase get phase => _phase;

  /// Whether the sign-in is still going: starting or waiting.
  bool get pending =>
      _phase == SignInPhase.starting || _phase == SignInPhase.waiting;

  /// Hermes' sentence of a refusal or an error; null when it gave none.
  String? get message => _message;

  /// The code, grouped as the provider gave it; null once the sign-in ended.
  String? get userCode => _session?.userCode;

  /// The provider's verification page when it passes the link check, so the
  /// code stays shown and only the Open button is dropped otherwise.
  Uri? get verificationLink => openableLink(_session?.verificationUrl);

  /// Present for Nous only, and only on approval.
  String? get accountEmail => _accountEmail;

  /// Two polls in a row failed: "Can't reach your server. Still waiting…".
  bool get offline => _offline;

  /// Starts (or starts again after a refusal or an end) the sign-in.
  Future<void> start() async {
    if (_closed || (pending && _run > 0)) return;
    final run = ++_run;
    _stop();
    _session = null;
    _message = null;
    _accountEmail = null;
    _offline = false;
    _polls = 0;
    _backoff.reset();
    _span = _signals.start('providers.signin');
    _phase = SignInPhase.starting;
    notifyListeners();
    final result = await repository.startSignIn(profile, providerId);
    if (_cancelOnArrival.remove(run)) {
      // Stop was pressed before the code arrived: the session is cancelled
      // as soon as there is one.
      if (result is SignInStarted) {
        await repository.cancelSignIn(profile, result.session.sessionId);
      }
      return;
    }
    if (_closed || run != _run) return;
    switch (result) {
      case SignInStarted(:final session):
        _session = session;
        _deadline = clock.now().add(
          Duration(seconds: session.expiresIn) + kSignInGrace,
        );
        _phase = SignInPhase.waiting;
        _lifetime = Timer(
          Duration(seconds: session.expiresIn) + kSignInGrace,
          _expire,
        );
        _arm();
        notifyListeners();
      case SignInStartRefused(:final message):
        _message = message;
        _finish(SignInPhase.startRefused, 'failed');
      case SignInStartFailed():
        _finish(SignInPhase.startFailed, 'failed');
    }
  }

  /// The person's Stop: the server's poller is told to stop, so a later
  /// approval saves nothing.
  Future<void> cancel() async {
    if (_closed) return;
    if (_phase == SignInPhase.starting && _run > 0) {
      _cancelOnArrival.add(_run);
      _run++;
      _finish(SignInPhase.cancelled, 'cancelled');
      return;
    }
    final session = _session;
    if (_phase != SignInPhase.waiting || session == null) return;
    _finish(SignInPhase.cancelled, 'cancelled');
    await repository.cancelSignIn(profile, session.sessionId);
  }

  /// The owner went away (the screen closed, sign-out, a server change):
  /// polling stops and nothing is sent to the server.
  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _stop();
    if (pending) _signals.end(_span, _spanAttributes('abandoned'));
    _span = null;
    _session = null;
    super.dispose();
  }

  /// Forwards the app's lifecycle. A phone stops polling in the background
  /// and polls at once when it comes back.
  void appLifecycle(AppLifecycleState state) {
    if (_closed || !_pausesInBackground) return;
    final background = !AppPresence.foreground(state, platform: _platform);
    if (background == _background) return;
    _background = background;
    if (_phase != SignInPhase.waiting) return;
    if (background) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_pastDeadline) {
      unawaited(_expireNow());
      return;
    }
    _backoff.reset();
    unawaited(_poll());
  }

  bool get _pausesInBackground =>
      _platform == TargetPlatform.iOS || _platform == TargetPlatform.android;

  bool get _pastDeadline {
    final deadline = _deadline;
    return deadline != null && !clock.now().isBefore(deadline);
  }

  Duration get _interval {
    final seconds = _session?.pollInterval ?? 5;
    return Duration(seconds: seconds.clamp(_minInterval, _maxInterval));
  }

  void _arm() {
    _timer?.cancel();
    if (_closed || _phase != SignInPhase.waiting || _background) return;
    _timer = Timer(_interval, () {
      _timer = null;
      if (_pastDeadline) {
        unawaited(_expireNow());
      } else if (_backoff.tick()) {
        unawaited(_poll());
      } else {
        _arm();
      }
    });
  }

  Future<void> _poll() async {
    final session = _session;
    if (_closed || _polling || session == null) return;
    if (_phase != SignInPhase.waiting) return;
    _polling = true;
    _timer?.cancel();
    _timer = null;
    final run = _run;
    _polls++;
    final result = await repository.pollSignIn(
      profile,
      providerId,
      session.sessionId,
    );
    _polling = false;
    if (_closed || run != _run || _phase != SignInPhase.waiting) return;
    switch (result) {
      case SignInPolled(
        :final status,
        :final accountEmail,
        :final errorMessage,
      ):
        _backoff.succeeded();
        _offline = false;
        switch (status) {
          case SignInStatus.pending:
            _arm();
            notifyListeners();
          case SignInStatus.approved:
            _accountEmail = accountEmail;
            _finish(SignInPhase.approved, 'approved');
          case SignInStatus.denied:
            _finish(SignInPhase.denied, 'denied');
          case SignInStatus.expired:
            _finish(SignInPhase.expired, 'expired');
          case SignInStatus.error:
            _message = errorMessage;
            _finish(SignInPhase.failed, 'failed');
          case SignInStatus.cancelled:
            _finish(SignInPhase.cancelled, 'cancelled');
        }
      case SignInGone():
        _finish(SignInPhase.expired, 'expired');
      case SignInPollFailed():
        _backoff.failed();
        _offline = _backoff.failures >= 2;
        _arm();
        notifyListeners();
    }
  }

  void _expire() {
    if (_phase == SignInPhase.waiting) unawaited(_expireNow());
  }

  /// The code outlived its lifetime: treated as expired, and the session is
  /// cancelled so a late approval saves nothing.
  Future<void> _expireNow() async {
    final session = _session;
    if (_closed || _phase != SignInPhase.waiting || session == null) return;
    _finish(SignInPhase.expired, 'expired');
    await repository.cancelSignIn(profile, session.sessionId);
  }

  void _finish(SignInPhase phase, String outcome) {
    _stop();
    _phase = phase;
    _offline = false;
    _session = null;
    _signals.end(_span, _spanAttributes(outcome));
    _span = null;
    notifyListeners();
    onEnded?.call(this);
  }

  Map<String, Object> _spanAttributes(String outcome) => {
    'outcome': outcome,
    'polls': ProviderSignals.bucket(_polls),
  };

  void _stop() {
    _timer?.cancel();
    _lifetime?.cancel();
    _timer = _lifetime = null;
    _deadline = null;
  }
}
