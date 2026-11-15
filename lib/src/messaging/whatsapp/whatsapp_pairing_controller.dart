import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../../core/safe_notifier.dart';
import '../../telemetry/report_bug.dart';
import '../hermes_messaging_repository.dart';
import 'whatsapp_pairing.dart';
import 'whatsapp_pairing_telemetry.dart';

/// How often a live pairing is read while the app is in front and unlocked.
const kWhatsAppPollInterval = Duration(seconds: 2);

/// How long a start, an apply, a Check or a poll may go unanswered. One that
/// gets none ends in a state the user can act on; nothing is ever resent.
const kWhatsAppAnswerTimeout = Duration(seconds: 10);

/// Where the screen's body stands.
enum WhatsAppPairingPhase {
  /// The form: mode and allowed numbers, and Start. Nothing has been sent.
  setup,

  /// The start request is out (at most [kWhatsAppAnswerTimeout]).
  starting,

  /// Installing or starting on the server; see
  /// [WhatsAppPairingController.workStage].
  working,

  /// A code to scan (see [WhatsAppPairingController.codeVisibility]).
  waiting,

  /// Linked; see [WhatsAppPairingController.alreadyLinked] and
  /// [WhatsAppPairingController.applyStatus].
  connected,

  /// The bridge or the server gave up; see
  /// [WhatsAppPairingController.failReason].
  failed,

  /// The setup's ten minutes ran out.
  expired,

  /// A newer setup on the same session folder replaced this one.
  superseded,

  /// The record is no longer on the server (a poll or an apply got 404).
  gone,

  /// 404 naming the profile.
  profileDeleted,

  /// The server has no such route: the entry point goes away.
  unsupported,

  /// A start got no answer: it may or may not have begun.
  startLost,
}

/// What the page says about Finish.
enum WhatsAppApplyStatus {
  /// Nothing asked yet (or a question was cancelled).
  idle,

  /// The question is open; nothing has been sent.
  asking,

  /// The apply is out (at most [kWhatsAppAnswerTimeout]). Back is off.
  applying,

  /// The server said `ok`; see
  /// [WhatsAppPairingController.restartRequested].
  saved,

  /// The server refused (400, 409, 500 and the like); the record is still
  /// there and Finish can ask again. See
  /// [WhatsAppPairingController.applyFailure].
  refused,

  /// No answer, or a 200 without `ok`: the save is not known. Check reads the
  /// platform list; Finish is not offered again.
  lostAnswer,

  /// A Check read is out.
  checking,

  /// Check found WhatsApp enabled for the profile. It cannot tell this apply
  /// from an earlier setup.
  checkEnabled,

  /// Check found WhatsApp not enabled: the settings were probably not saved.
  checkNotEnabled,

  /// Check could not read the list ("Couldn't confirm"); it may be pressed
  /// again.
  checkFailed,
}

/// Whether the code may be drawn.
enum WhatsAppCodeVisibility {
  /// Draw it.
  shown,

  /// Allowed, but the user has to tap "Show QR code" first (every handset
  /// after a hide, and any device after [WhatsAppPairingController.hideCode]).
  needsTap,

  /// The app is not in front, App Lock is locked or (computers) the window
  /// has no focus: "Hidden".
  hidden,
}

/// Why the allowed numbers were refused.
enum WhatsAppNumbersProblem {
  /// Something that is not a phone number (letters, punctuation, a length no
  /// number has).
  notPhoneNumber,

  /// `*`: everyone may write to the agent. That is a server setting, never
  /// offered here.
  everyone,

  /// A WhatsApp address (`...@s.whatsapp.net`, `...@lid`).
  address,
}

/// The result of reading the allowed-numbers text.
typedef WhatsAppNumbers = ({
  String? normalized,
  WhatsAppNumbersProblem? problem,
});

final _phoneNumber = RegExp(r'^\+?\d{5,15}$');

/// Reads [text]: phone numbers (digits, an optional leading `+`, spaces
/// ignored) separated by commas. The app never opens the bot to everyone, so
/// `*`, JIDs and LIDs are refused even though the bridge takes them. An empty
/// list is fine and is [WhatsAppNumbers.normalized] null (not sent: the server
/// keeps what it has).
WhatsAppNumbers parseWhatsAppAllowedUsers(String text) {
  final numbers = <String>[];
  WhatsAppNumbersProblem? problem;
  for (final raw in text.split(',')) {
    final entry = raw.replaceAll(RegExp(r'\s+'), '');
    if (entry.isEmpty) continue;
    if (entry.contains('*')) {
      problem = WhatsAppNumbersProblem.everyone;
    } else if (entry.contains('@') || entry.contains(':')) {
      if (problem != WhatsAppNumbersProblem.everyone) {
        problem = WhatsAppNumbersProblem.address;
      }
    } else if (!_phoneNumber.hasMatch(entry)) {
      problem ??= WhatsAppNumbersProblem.notPhoneNumber;
    } else {
      numbers.add(entry);
    }
  }
  if (problem != null) return (normalized: null, problem: problem);
  return (
    normalized: numbers.isEmpty ? null : numbers.join(','),
    problem: null,
  );
}

/// A refused start or apply: its kind, and the server's own text for the
/// screen (opaque; never logged).
typedef WhatsAppRefusal = ({
  WhatsAppPairingFailureKind kind,
  WhatsAppServerText? serverText,
});

/// One visit to the WhatsApp pairing screen of a profile: the form, the
/// pairing the server runs, the polling and the guarded Finish.
///
/// It is bound to one profile (explicit in every request, never the server's
/// active profile) and one connection. The shell calls [clear] on sign-out, a
/// server change and a profile switch, [cover] and [uncover] for App Lock,
/// [setInForeground] with the lifecycle and [setWindowFocused] with a desktop
/// window's focus. The screen reads state and calls the methods; nothing here
/// builds a widget or a string.
///
/// The code and the pairing id are credentials. They live only in this object
/// (no preferences, log, span, breadcrumb or clipboard) and go when it closes
/// or App Lock covers (the id stays: it is not shown and polling needs it).
/// The account, the server's text and the code are dropped on [cover] and
/// read again after [uncover].
///
/// Nothing is sent without a user action: Start, the Finish question and its
/// confirmation, Check. Start and apply go once and are never resent.
/// Polling runs only while the app is in front and unlocked. Leaving before
/// Finish asks the server to drop the pairing once, ignoring a failure.
class WhatsAppPairingController extends ChangeNotifier with SafeNotifier {
  WhatsAppPairingController({
    required HermesMessagingRepository repository,
    required this.profile,
    required this.handset,
    this._mode = WhatsAppMode.bot,
    this._allowedUsers = '',
    WhatsAppPairingTelemetry? telemetry,
    this.pollInterval = kWhatsAppPollInterval,
    this.answerTimeout = kWhatsAppAnswerTimeout,
    DateTime Function()? now,
  }) : _repository = repository.forProfile(profile),
       _telemetry = telemetry ?? WhatsAppPairingTelemetry(),
       _now = now ?? DateTime.now,
       _revealed = !handset;

  final HermesMessagingRepository _repository;
  final WhatsAppPairingTelemetry _telemetry;
  final DateTime Function() _now;

  /// The profile this screen is bound to.
  final String profile;

  /// A handset (shortest side under 600 dp) cannot scan its own screen: the
  /// code needs a tap, again after every hide, and window focus does not
  /// matter. Tablets and computers show it at once.
  final bool handset;

  final Duration pollInterval;
  final Duration answerTimeout;

  var _phase = WhatsAppPairingPhase.setup;
  WhatsAppMode _mode;
  String _allowedUsers;
  WhatsAppNumbersProblem? _numbersProblem;
  WhatsAppRefusal? _startFailure;

  WhatsAppPairingId? _id;
  WhatsAppQrPayload? _qr;
  DateTime? _expiresAt;
  var _stage = WhatsAppWorkStage.starting;
  WhatsAppLinkedAccount? _account;
  var _alreadyLinked = false;
  WhatsAppFailReason? _failReason;
  WhatsAppServerText? _serverText;
  var _goneDuringApply = false;

  var _applyStatus = WhatsAppApplyStatus.idle;
  var _statusBeforeQuestion = WhatsAppApplyStatus.idle;
  WhatsAppApplyResult? _applyResult;
  WhatsAppRefusal? _applyFailure;

  // Where the code may be drawn.
  var _foreground = true;
  var _covered = false;
  var _windowFocused = true;
  var _revealed = false;
  var _qrWasShown = false;

  // Polling.
  Timer? _timer;
  var _pollInFlight = false;
  var _pausedBefore = false;
  var _pausedLine = false;
  var _pollFailing = false;
  var _needsRefresh = false;

  /// Moves when an answer in flight stops mattering for good: Start again,
  /// leaving, [clear].
  var _epoch = 0;

  /// Moves when polling stops for a while, so a poll in flight is discarded.
  var _pollEpoch = 0;
  var _opened = false;
  var _closed = false;
  var _cleared = false;
  var _endLogged = false;

  WhatsAppPairingPhase get phase => _phase;
  WhatsAppMode get mode => _mode;

  /// The allowed numbers as typed.
  String get allowedUsers => _allowedUsers;

  /// Why Start was refused for the numbers; null while they are fine.
  WhatsAppNumbersProblem? get numbersProblem => _numbersProblem;

  /// Why the last start was refused (400, 422, 5xx and the like), while the
  /// form is up; null once the form is edited.
  WhatsAppRefusal? get startFailure => _startFailure;

  /// What the server is doing, while [phase] is [WhatsAppPairingPhase.working].
  WhatsAppWorkStage get workStage => _stage;

  /// The code, only while it may be drawn; null otherwise. It is a secret:
  /// draw it, never copy, log or store it.
  WhatsAppQrPayload? get qr =>
      _phase == WhatsAppPairingPhase.waiting &&
          codeVisibility == WhatsAppCodeVisibility.shown
      ? _qr
      : null;

  WhatsAppCodeVisibility get codeVisibility {
    if (_closed || _covered || !_foreground) {
      return WhatsAppCodeVisibility.hidden;
    }
    if (!handset && !_windowFocused) return WhatsAppCodeVisibility.hidden;
    return _revealed
        ? WhatsAppCodeVisibility.shown
        : WhatsAppCodeVisibility.needsTap;
  }

  /// The setup's fixed deadline, when the server's time parsed.
  DateTime? get expiresAt => _expiresAt;

  /// The time left until [expiresAt] while a code can still come or is shown;
  /// the screen ticks itself.
  Duration? get timeLeft {
    final end = _expiresAt;
    if (end == null ||
        (_phase != WhatsAppPairingPhase.working &&
            _phase != WhatsAppPairingPhase.waiting)) {
      return null;
    }
    final left = end.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// The linked account; null while App Lock covers.
  WhatsAppLinkedAccount? get account => _account;

  /// The start answered `connected` at once: nothing was scanned.
  bool get alreadyLinked => _alreadyLinked;

  WhatsAppFailReason? get failReason => _failReason;

  /// The server's own text of a failed pairing, for the screen only; null
  /// while App Lock covers.
  WhatsAppServerText? get serverText => _serverText;

  /// [phase] is `gone` because an apply got 404: the settings may not be
  /// saved.
  bool get goneDuringApply => _goneDuringApply;

  WhatsAppApplyStatus get applyStatus => _applyStatus;
  WhatsAppApplyResult? get applyResult => _applyResult;

  /// Why the server refused the apply, while [applyStatus] is `refused`.
  WhatsAppRefusal? get applyFailure => _applyFailure;

  /// The save went through and a restart of the messaging gateway was asked
  /// for (and the server did not say it still has to be done by hand). Never
  /// "the gateway restarted".
  bool get restartRequested {
    final result = _applyResult;
    return result != null && result.restartStarted && !result.needsRestart;
  }

  /// The last poll got no usable answer; the code may be out of date.
  bool get pollFailing => _pollFailing;

  /// Polling was paused and is resuming; goes with the next answer.
  bool get pausedLine =>
      _pausedLine &&
      (_phase == WhatsAppPairingPhase.working ||
          _phase == WhatsAppPairingPhase.waiting);

  /// A poll timer is running.
  bool get polling => _timer != null;

  bool get covered => _covered;
  bool get closed => _closed;

  bool get canStart => !_closed && _phase == WhatsAppPairingPhase.setup;

  bool get canFinish =>
      !_closed &&
      !_covered &&
      _phase == WhatsAppPairingPhase.connected &&
      (_applyStatus == WhatsAppApplyStatus.idle ||
          _applyStatus == WhatsAppApplyStatus.refused);

  bool get canCheck =>
      !_closed &&
      !_covered &&
      (_applyStatus == WhatsAppApplyStatus.lostAnswer ||
          _applyStatus == WhatsAppApplyStatus.checkFailed);

  /// Start again is offered: a setup that ended, got lost or may be gone.
  bool get canStartAgain =>
      !_closed &&
      (_phase == WhatsAppPairingPhase.failed ||
          _phase == WhatsAppPairingPhase.expired ||
          _phase == WhatsAppPairingPhase.superseded ||
          _phase == WhatsAppPairingPhase.gone ||
          _phase == WhatsAppPairingPhase.startLost ||
          (_phase == WhatsAppPairingPhase.connected &&
              _applyStatus == WhatsAppApplyStatus.checkNotEnabled));

  /// Back may be used. It is not while the apply is out.
  bool get canLeave => _applyStatus != WhatsAppApplyStatus.applying;

  /// Notes that the screen opened (once). Sends nothing.
  void open() {
    if (_closed || _opened) return;
    _opened = true;
    _telemetry.opened();
  }

  void setMode(WhatsAppMode value) {
    if (_closed || _phase != WhatsAppPairingPhase.setup || value == _mode) {
      return;
    }
    _mode = value;
    _startFailure = null;
    _changed();
  }

  void setAllowedUsers(String value) {
    if (_closed || _phase != WhatsAppPairingPhase.setup) return;
    _allowedUsers = value;
    _numbersProblem = null;
    _startFailure = null;
    _changed();
  }

  /// Asks the server to start linking. Checks the numbers first and sends
  /// nothing when they are refused. Sent once: no answer for
  /// [answerTimeout] is [WhatsAppPairingPhase.startLost], and only a new
  /// press (after Start again) sends another.
  Future<void> start() async {
    if (!canStart) return;
    final parsed = parseWhatsAppAllowedUsers(_allowedUsers);
    if (parsed.problem != null) {
      _numbersProblem = parsed.problem;
      _changed();
      return;
    }
    _numbersProblem = null;
    _startFailure = null;
    final epoch = ++_epoch;
    _endLogged = false;
    _phase = WhatsAppPairingPhase.starting;
    _changed();
    final span = _telemetry.startStart();

    WhatsAppPairingStart? started;
    WhatsAppPairingFailureKind? failure;
    WhatsAppServerText? failureText;
    Future<WhatsAppPairingStart>? call;
    try {
      call = _repository.startWhatsAppPairing(
        mode: _mode,
        allowedUsers: parsed.normalized,
      );
      started = await call.timeout(answerTimeout);
    } on WhatsAppPairingFailure catch (e) {
      failure = e.kind;
      failureText = e.serverText;
    } on TimeoutException {
      failure = WhatsAppPairingFailureKind.lostAnswer;
      // The answer may still come: the pairing it names is dropped, once,
      // never adopted.
      unawaited(
        call?.then<void>((late) {
          if (!_cleared) _orphan(late.id);
        }, onError: (Object _) {}),
      );
    } on DioException {
      // A 401: the sign-in path handles the session; nothing began.
      failure = WhatsAppPairingFailureKind.unexpected;
    } on Object catch (error, stack) {
      reportBug(error, stack, 'whatsapp.pair.start');
      failure = WhatsAppPairingFailureKind.unexpected;
    }

    if (_closed || epoch != _epoch) {
      _telemetry.endStart(span, WhatsAppStartOutcome.discarded);
      // The pairing began after the user stopped waiting for it: drop it, once.
      if (started != null && !_cleared) _orphan(started.id);
      return;
    }
    if (started != null) {
      _id = started.id;
      _expiresAt = started.snapshot.expiresAt;
      _alreadyLinked = started.snapshot.state is WhatsAppConnected;
      _telemetry.endStart(
        span,
        _alreadyLinked
            ? WhatsAppStartOutcome.alreadyLinked
            : WhatsAppStartOutcome.started,
      );
      _adopt(started.snapshot.state);
      _syncPolling();
      _changed();
      return;
    }
    _failStart(span, failure!, failureText);
  }

  void _failStart(
    Span? span,
    WhatsAppPairingFailureKind kind,
    WhatsAppServerText? text,
  ) {
    final outcome = switch (kind) {
      WhatsAppPairingFailureKind.lostAnswer => WhatsAppStartOutcome.lostAnswer,
      WhatsAppPairingFailureKind.unsupported =>
        WhatsAppStartOutcome.unsupported,
      WhatsAppPairingFailureKind.profileGone =>
        WhatsAppStartOutcome.profileGone,
      WhatsAppPairingFailureKind.badRequest ||
      WhatsAppPairingFailureKind.validation ||
      WhatsAppPairingFailureKind.notConnected => WhatsAppStartOutcome.refused,
      _ => WhatsAppStartOutcome.failed,
    };
    _telemetry.endStart(span, outcome);
    switch (kind) {
      case WhatsAppPairingFailureKind.lostAnswer:
        _phase = WhatsAppPairingPhase.startLost;
      case WhatsAppPairingFailureKind.unsupported:
        _phase = WhatsAppPairingPhase.unsupported;
        _telemetry.unavailable();
      case WhatsAppPairingFailureKind.profileGone:
        _phase = WhatsAppPairingPhase.profileDeleted;
      default:
        _phase = WhatsAppPairingPhase.setup;
        _startFailure = (kind: kind, serverText: _covered ? null : text);
    }
    _changed();
  }

  /// Back to the form with the earlier mode and numbers. Sends nothing; the
  /// next Start supersedes whatever the server still holds.
  void startAgain() {
    if (!canStartAgain) return;
    _epoch++;
    _dropPairing();
    _phase = WhatsAppPairingPhase.setup;
    _applyStatus = WhatsAppApplyStatus.idle;
    _applyResult = null;
    _applyFailure = null;
    _startFailure = null;
    _numbersProblem = null;
    _goneDuringApply = false;
    _alreadyLinked = false;
    _syncPolling();
    _changed();
  }

  /// The user tapped "Show QR code" (or shows it again after [hideCode]). It
  /// shows only while the app is in front, unlocked and focused.
  void revealQr() {
    if (_closed ||
        _revealed ||
        codeVisibility == WhatsAppCodeVisibility.hidden) {
      return;
    }
    _revealed = true;
    _changed();
  }

  /// Hides the code until [revealQr].
  void hideCode() {
    if (_closed || !_revealed) return;
    _revealed = false;
    _changed();
  }

  /// The lifecycle: `true` while resumed. Anything else hides the code and
  /// pauses polling.
  void setInForeground(bool value) {
    if (_closed || value == _foreground) return;
    _foreground = value;
    if (!value && handset) _revealed = false;
    _syncPolling();
    _changed();
  }

  /// A desktop window's focus. A tablet or computer hides the code while it
  /// has none and shows it again with focus; a handset ignores it.
  void setWindowFocused(bool value) {
    if (_closed || value == _windowFocused) return;
    _windowFocused = value;
    _changed();
  }

  /// App Lock covers the app: the code, the account and the server's text go
  /// at once and nothing polls. A request in flight finishes and its outcome
  /// is dropped (an apply's is kept: it happened). [uncover] reads the
  /// pairing again.
  void cover() {
    if (_closed || _covered) return;
    _covered = true;
    if (handset) _revealed = false;
    _qr = null;
    _account = null;
    _serverText = null;
    _startFailure = null;
    _applyFailure = null;
    if (_applyStatus == WhatsAppApplyStatus.asking) {
      _applyStatus = _statusBeforeQuestion;
    }
    _needsRefresh =
        _id != null &&
        (_applyStatus == WhatsAppApplyStatus.idle ||
            _applyStatus == WhatsAppApplyStatus.refused) &&
        (_phase == WhatsAppPairingPhase.connected ||
            _phase == WhatsAppPairingPhase.failed ||
            _phase == WhatsAppPairingPhase.waiting);
    if (_applyStatus == WhatsAppApplyStatus.refused) {
      _applyStatus = WhatsAppApplyStatus.idle;
    }
    _syncPolling();
    _changed();
  }

  /// App Lock let go: polling resumes and the pairing is read again.
  void uncover() {
    if (_closed || !_covered) return;
    _covered = false;
    _syncPolling();
    _changed();
  }

  /// The Finish question. Sends nothing; false when Finish is not offered.
  bool requestFinish() {
    if (!canFinish) return false;
    _statusBeforeQuestion = _applyStatus;
    _applyStatus = WhatsAppApplyStatus.asking;
    _changed();
    return true;
  }

  /// The user said Cancel to the question.
  void cancelFinish() {
    if (_applyStatus != WhatsAppApplyStatus.asking) return;
    _applyStatus = _statusBeforeQuestion;
    _changed();
  }

  /// The user confirmed the question: sends the apply once. The profile goes
  /// in the query and the body; `allowed_users` is left out so the list the
  /// start stored stays (an empty string would discard it).
  Future<void> confirmFinish() async {
    final id = _id;
    if (_closed ||
        _covered ||
        id == null ||
        _phase != WhatsAppPairingPhase.connected ||
        _applyStatus != WhatsAppApplyStatus.asking) {
      return;
    }
    final epoch = _epoch;
    _applyStatus = WhatsAppApplyStatus.applying;
    _applyFailure = null;
    _changed();
    final span = _telemetry.startApply();

    WhatsAppApplyResult? result;
    WhatsAppPairingFailureKind? failure;
    WhatsAppServerText? failureText;
    try {
      result = await _repository
          .applyWhatsAppPairing(id, mode: _mode)
          .timeout(answerTimeout);
    } on WhatsAppPairingFailure catch (e) {
      failure = e.kind;
      failureText = e.serverText;
    } on TimeoutException {
      failure = WhatsAppPairingFailureKind.lostAnswer;
    } on DioException {
      // A 401: refused before anything was written.
      failure = WhatsAppPairingFailureKind.unexpected;
    } on Object catch (error, stack) {
      reportBug(error, stack, 'whatsapp.pair.apply');
      failure = WhatsAppPairingFailureKind.lostAnswer;
    }

    if (_closed || epoch != _epoch) {
      _telemetry.endApply(span, WhatsAppApplyOutcome.discarded);
      return;
    }
    if (result != null && result.confirmed) {
      _applyResult = result;
      _applyStatus = WhatsAppApplyStatus.saved;
      _id = null;
      _needsRefresh = false;
      _telemetry.applied(restartRequested: restartRequested);
      _telemetry.endApply(
        span,
        WhatsAppApplyOutcome.saved,
        restartRequested: restartRequested,
      );
      _syncPolling();
      _changed();
      return;
    }
    if (result != null || failure == WhatsAppPairingFailureKind.lostAnswer) {
      // The record is most likely gone either way: never resent, Check reads.
      _applyStatus = WhatsAppApplyStatus.lostAnswer;
      _id = null;
      _telemetry.endApply(
        span,
        result != null
            ? WhatsAppApplyOutcome.unconfirmed
            : WhatsAppApplyOutcome.lostAnswer,
      );
      _changed();
      return;
    }
    switch (failure!) {
      case WhatsAppPairingFailureKind.recordGone:
        _telemetry.endApply(span, WhatsAppApplyOutcome.recordGone);
        _applyStatus = WhatsAppApplyStatus.idle;
        _goneDuringApply = true;
        _goneNow();
      case WhatsAppPairingFailureKind.profileGone:
        _telemetry.endApply(span, WhatsAppApplyOutcome.profileGone);
        _applyStatus = WhatsAppApplyStatus.idle;
        _dropPairing();
        _phase = WhatsAppPairingPhase.profileDeleted;
        _syncPolling();
      default:
        _telemetry.endApply(
          span,
          failure == WhatsAppPairingFailureKind.badRequest ||
                  failure == WhatsAppPairingFailureKind.notConnected ||
                  failure == WhatsAppPairingFailureKind.validation
              ? WhatsAppApplyOutcome.refused
              : WhatsAppApplyOutcome.failed,
        );
        _applyStatus = WhatsAppApplyStatus.refused;
        _applyFailure = (
          kind: failure,
          serverText: _covered ? null : failureText,
        );
    }
    _changed();
  }

  /// After a lost apply: reads the platform list of the profile and says
  /// whether WhatsApp is enabled there. It cannot tell this apply from an
  /// earlier setup, and it never sends the apply again.
  Future<void> check() async {
    if (!canCheck) return;
    final epoch = _epoch;
    _applyStatus = WhatsAppApplyStatus.checking;
    _changed();
    bool? enabled;
    try {
      final platforms = await _repository.load().timeout(answerTimeout);
      enabled = platforms.any((p) => p.id == 'whatsapp' && p.enabled);
    } on TimeoutException {
      enabled = null;
    } on DioException {
      enabled = null;
    } on Object catch (error, stack) {
      reportBug(error, stack, 'whatsapp.pair.check');
      enabled = null;
    }
    if (_closed || epoch != _epoch) return;
    _applyStatus = switch (enabled) {
      true => WhatsAppApplyStatus.checkEnabled,
      false => WhatsAppApplyStatus.checkNotEnabled,
      null => WhatsAppApplyStatus.checkFailed,
    };
    _changed();
  }

  /// The user leaves the screen before Finish. Asks the server to drop a live
  /// pairing once, best effort, then ends the controller. Does nothing while
  /// the apply is out ([canLeave]). Completes when the request did.
  Future<void> leave() async {
    if (_closed || !canLeave) return;
    final id = _liveIdToCancel();
    _shutdown();
    _changed();
    if (id != null) await _cancel(id);
  }

  /// Sign-out, a server change or a profile switch: drops everything and ends
  /// the controller without a request (the connection is not the user's any
  /// more).
  void clear() {
    if (_closed) return;
    _cleared = true;
    _shutdown();
    _changed();
  }

  @override
  void dispose() {
    if (disposed) return;
    final id = _closed || _cleared || !canLeave ? null : _liveIdToCancel();
    _shutdown();
    if (id != null) unawaited(_cancel(id));
    super.dispose();
  }

  /// The id of a record that is still live on the server and not finished:
  /// working, waiting or connected with no apply sent.
  WhatsAppPairingId? _liveIdToCancel() {
    final id = _id;
    if (id == null) return null;
    final live =
        (_phase == WhatsAppPairingPhase.working ||
            _phase == WhatsAppPairingPhase.waiting ||
            _phase == WhatsAppPairingPhase.connected) &&
        (_applyStatus == WhatsAppApplyStatus.idle ||
            _applyStatus == WhatsAppApplyStatus.asking ||
            _applyStatus == WhatsAppApplyStatus.refused);
    return live ? id : null;
  }

  void _shutdown() {
    if (_closed) return;
    if (_liveIdToCancel() != null && !_cleared && !_endLogged) {
      _endLogged = true;
      _telemetry.ended(WhatsAppEndStatus.cancelled);
    }
    _closed = true;
    _epoch++;
    _pollEpoch++;
    _timer?.cancel();
    _timer = null;
    _dropPairing();
    _numbersProblem = null;
    _startFailure = null;
    _applyFailure = null;
    _applyResult = null;
  }

  /// Best effort and once; a failure of any kind is ignored.
  Future<void> _cancel(WhatsAppPairingId id) async {
    try {
      await _repository.cancelWhatsAppPairing(id).timeout(answerTimeout);
    } on WhatsAppPairingFailure {
      return;
    } on TimeoutException {
      return;
    } on DioException {
      return;
    } on Object catch (error, stack) {
      reportBug(error, stack, 'whatsapp.pair.cancel');
    }
  }

  void _orphan(WhatsAppPairingId id) => unawaited(_cancel(id));

  void _dropPairing() {
    _id = null;
    _qr = null;
    _account = null;
    _serverText = null;
    _failReason = null;
    _expiresAt = null;
    _pollFailing = false;
    _pausedLine = false;
    _pausedBefore = false;
    _needsRefresh = false;
  }

  /// Takes the server's reading of the pairing into the state.
  void _adopt(WhatsAppPairingState state) {
    _pollFailing = false;
    _pausedLine = false;
    _needsRefresh = false;
    switch (state) {
      case WhatsAppWorking(:final stage):
        _phase = WhatsAppPairingPhase.working;
        _stage = stage;
        _qr = null;
      case WhatsAppWaitingForScan(:final qr):
        _phase = WhatsAppPairingPhase.waiting;
        _qr = _covered ? null : qr;
        _needsRefresh = _covered;
      case WhatsAppConnected(:final account):
        _phase = WhatsAppPairingPhase.connected;
        _qr = null;
        _account = _covered ? null : account;
        _needsRefresh = _covered;
        _logEnded(WhatsAppEndStatus.connected);
      case WhatsAppPairingFailed(:final reason, :final serverText):
        _phase = WhatsAppPairingPhase.failed;
        _failReason = reason;
        _serverText = _covered ? null : serverText;
        _needsRefresh = _covered;
        _finishedWithoutRecord(WhatsAppEndStatus.error);
      case WhatsAppPairingExpired():
        _phase = WhatsAppPairingPhase.expired;
        _finishedWithoutRecord(WhatsAppEndStatus.expired);
      case WhatsAppPairingSuperseded():
        _phase = WhatsAppPairingPhase.superseded;
        _finishedWithoutRecord(WhatsAppEndStatus.superseded);
    }
  }

  /// Error, expired and superseded: nothing left to cancel, finish or read
  /// (apart from an error's text after App Lock).
  void _finishedWithoutRecord(WhatsAppEndStatus status) {
    _qr = null;
    // An error keeps the id so its text can be read again after App Lock.
    if (status != WhatsAppEndStatus.error) _id = null;
    _logEnded(status);
  }

  void _logEnded(WhatsAppEndStatus status) {
    if (_endLogged) return;
    _endLogged = true;
    _telemetry.ended(status);
  }

  void _goneNow() {
    _dropPairing();
    _phase = WhatsAppPairingPhase.gone;
    _syncPolling();
  }

  void _expireLocally() {
    _dropPairing();
    _phase = WhatsAppPairingPhase.expired;
    _logEnded(WhatsAppEndStatus.expired);
    _syncPolling();
  }

  bool get _pollWanted =>
      !_closed &&
      _id != null &&
      (_phase == WhatsAppPairingPhase.working ||
          _phase == WhatsAppPairingPhase.waiting ||
          _needsRefresh);

  bool get _gateOpen => _foreground && !_covered && !_closed;

  /// Starts or stops the poll timer to match the state: polling runs only
  /// while a pairing is live, the app is in front and App Lock is unlocked.
  void _syncPolling() {
    final wanted = _pollWanted;
    final open = _gateOpen;
    if (wanted && open) {
      if (_timer != null) return;
      final resuming = _pausedBefore;
      _pausedBefore = false;
      if (resuming) {
        _pausedLine = true;
        final end = _expiresAt;
        if (end != null &&
            !_now().isBefore(end) &&
            (_phase == WhatsAppPairingPhase.working ||
                _phase == WhatsAppPairingPhase.waiting)) {
          _expireLocally();
          return;
        }
      }
      _timer = Timer.periodic(pollInterval, (_) => unawaited(_tick()));
      if (resuming) unawaited(_tick());
      return;
    }
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      _pollEpoch++;
    }
    if (wanted && !open) {
      _pollEpoch++;
      _pausedBefore = true;
    }
  }

  Future<void> _tick() async {
    final id = _id;
    if (_pollInFlight || _timer == null || id == null) return;
    _pollInFlight = true;
    final epoch = _epoch;
    final pollEpoch = _pollEpoch;
    WhatsAppPairingSnapshot? snapshot;
    WhatsAppPairingFailureKind? failure;
    try {
      snapshot = await _repository
          .whatsAppPairingStatus(id)
          .timeout(answerTimeout);
    } on WhatsAppPairingFailure catch (e) {
      failure = e.kind;
    } on TimeoutException {
      failure = WhatsAppPairingFailureKind.unreachable;
    } on DioException {
      // A 401 is the sign-in path's to handle, not ours; the read did not
      // happen. Nothing of the request is logged or reported.
      failure = WhatsAppPairingFailureKind.unreachable;
    } on Object catch (error, stack) {
      reportBug(error, stack, 'whatsapp.pair.poll');
      failure = WhatsAppPairingFailureKind.unexpected;
    } finally {
      _pollInFlight = false;
    }
    if (_closed || epoch != _epoch) return;
    if (pollEpoch != _pollEpoch) {
      // Paused while it ran: its outcome is dropped. If polling is back on,
      // read again at once rather than wait for the next tick.
      if (_timer != null) unawaited(_tick());
      return;
    }
    if (snapshot != null) {
      final end = snapshot.expiresAt;
      if (end != null) _expiresAt = end;
      _adopt(snapshot.state);
      _syncPolling();
      _changed();
      return;
    }
    switch (failure!) {
      case WhatsAppPairingFailureKind.recordGone ||
          WhatsAppPairingFailureKind.badRequest ||
          WhatsAppPairingFailureKind.validation:
        _goneDuringApply = false;
        _goneNow();
      default:
        // Keep the last state and poll on; the code may be out of date.
        _pollFailing = true;
        final end = _expiresAt;
        if (end != null && !_now().isBefore(end)) {
          _expireLocally();
        }
    }
    _changed();
  }

  void _changed() {
    final shown = qr != null;
    if (shown && !_qrWasShown) _telemetry.qrShown();
    _qrWasShown = shown;
    notifyListeners();
  }
}
