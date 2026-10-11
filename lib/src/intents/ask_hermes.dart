/// The "Ask Hermes" App Intent's side of the work: send one question as a
/// turn and report what Siri should say, on the headless runtime. The turn is
/// the watch's (`WatchRequestHandler`), so both answer, cut and announce
/// alike.
library;

import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../app_lock/app_lock_controller.dart';
import '../background/headless_hermes.dart';
import '../chat/chat_transport.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../telemetry/breadcrumbs.dart';
import '../watch/watch_bridge.dart';
import '../watch/watch_request_handler.dart';

/// How a question ended for the person who asked it.
enum AskOutcome {
  answered('answered'),
  stillWorking('still_working'),
  needsYou('needs_you'),
  failed('failed'),
  signedOut('signed_out'),
  deviceLocked('device_locked'),
  unreachable('unreachable'),
  appLocked('app_locked');

  const AskOutcome(this.wire);

  /// The name Swift and telemetry know it by.
  final String wire;
}

/// What the intent says: the reply's [text] for [AskOutcome.answered], and
/// nothing otherwise, since Swift words every other outcome itself.
class AskResult {
  const AskResult(this.outcome, [this.text]);

  final AskOutcome outcome;
  final String? text;
}

class AskRequest {
  const AskRequest({
    required this.question,
    required this.answerWithin,
    this.profile,
    this.chatId,
  });

  final String question;

  /// The profile for a new chat; null for the server's default.
  final String? profile;

  /// The chat to continue, `<percent-encoded profile>/<thread id>`; its
  /// profile wins over [profile].
  final String? chatId;

  /// What is left of the intent's 25 seconds. The question is sent whatever
  /// happens; only the answer is cut at this.
  final Duration answerWithin;
}

/// One ask under way.
class AskRun {
  AskRun({
    required this.answer,
    required this.finished,
    required void Function() onExpire,
  }) : _abandon = onExpire;

  final void Function() _abandon;

  /// What the intent says. Completes once, at the reply or at the deadline.
  final Future<AskResult> answer;

  /// Completes when nothing is left to do for this ask, which for a reply
  /// that outlives its deadline is when the reply arrived or time ran out.
  final Future<void> finished;

  /// iOS ended the time this ask could run in. Nothing more is announced,
  /// and the run winds down.
  void expire() => _abandon();
}

/// Which engine the ask runs in, for telemetry.
enum AskEngine { foreground, headless }

/// How long the whole run may take, however late the reply is: iOS ends the
/// process long before, and [AskRun.expire] with it.
const _runTimeout = Duration(minutes: 3);

/// Sends questions for the "Ask Hermes" intent.
class AskHermes {
  AskHermes({
    required this.engine,
    this.notifications,
    this.settings,
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
    this.appLockOn = AppLockController.savedEnabled,
    this.transportFor,
    this.deps,
    this.flush,
  });

  final AskEngine engine;
  final NotificationService? notifications;
  final NotificationSettings? settings;
  final AppEventLogger events;

  /// Only the app's own engine has a crash trail to add to.
  final Breadcrumbs breadcrumbs;

  /// Whether App Lock is on; unreadable counts as on.
  final Future<bool> Function() appLockOn;

  /// The transport of a run; the headless runtime's own by default.
  final ChatTransport Function(HeadlessHermes hermes)? transportFor;
  final HeadlessDeps? deps;

  /// Sends the telemetry of an ask before its process may be suspended; only
  /// a background engine, which no one else flushes for, has one.
  final Future<void> Function()? flush;

  AskRun start(AskRequest request) {
    final ask = _Ask(this, request);
    return AskRun(
      answer: ask.answered.future,
      finished: ask.run(),
      onExpire: ask.abandon,
    );
  }
}

class _Ask {
  _Ask(this._owner, this._request) {
    _timer = Timer(
      _request.answerWithin,
      () => _answer(const AskResult(AskOutcome.stillWorking)),
    );
  }

  final AskHermes _owner;
  final AskRequest _request;
  final answered = Completer<AskResult>();
  final _abandoned = Completer<void>();
  final _clock = Stopwatch()..start();
  late final Timer _timer;
  var _muted = false;

  bool get _foreground => _owner.engine == AskEngine.foreground;

  /// Whether the intent already told the person that the reply will come as
  /// a notification.
  var _stillWorkingAnswered = false;

  void abandon() {
    _muted = true;
    _answer(const AskResult(AskOutcome.stillWorking));
    if (!_abandoned.isCompleted) _abandoned.complete();
  }

  /// Settles what the intent says, once; later calls change nothing.
  void _answer(AskResult result) {
    if (answered.isCompleted) return;
    _timer.cancel();
    _stillWorkingAnswered = result.outcome == AskOutcome.stillWorking;
    answered.complete(result);
    _record(result.outcome);
  }

  void _record(AskOutcome outcome) {
    final bucket = outcome == AskOutcome.stillWorking
        ? 'late'
        : waitedBucket(_clock.elapsed);
    try {
      _owner.events('intent.ask', {
        'outcome': outcome.wire,
        'waited_s': bucket,
      });
      if (_foreground) {
        _owner.breadcrumbs('intent.ask.ended', {'outcome': outcome.wire});
      }
    } on Object {
      // Telemetry must never keep an answer from the person asking.
    }
  }

  Future<void> run() async {
    if (_foreground) {
      _owner.breadcrumbs('intent.ask.started', {
        'continued': _request.chatId != null,
      });
    }
    try {
      if (await _appLocked()) {
        _answer(const AskResult(AskOutcome.appLocked));
        return;
      }
      if (_request.question.trim().isEmpty) {
        _answer(const AskResult(AskOutcome.failed));
        return;
      }
      final outcome = await withHeadlessHermes<void>(
        _turn,
        task: 'intent.ask',
        attributes: {
          'engine': _owner.engine.name,
          'continued': _request.chatId != null,
        },
        timeout: _runTimeout,
        deps: _owner.deps,
      );
      // A run that never got to send: the body answers otherwise.
      switch (outcome) {
        case HeadlessDone():
          _answer(const AskResult(AskOutcome.failed));
        case HeadlessSignedOut():
          _answer(const AskResult(AskOutcome.signedOut));
        case HeadlessLocked():
          _answer(const AskResult(AskOutcome.deviceLocked));
        case HeadlessUnreachable():
          _answer(const AskResult(AskOutcome.unreachable));
      }
    } on Object {
      _answer(const AskResult(AskOutcome.failed));
    } finally {
      _timer.cancel();
      await _flush();
    }
  }

  Future<void> _flush() async {
    try {
      await _owner.flush?.call().timeout(const Duration(seconds: 2));
    } on Object {
      // Telemetry must never hold an ask back.
    }
  }

  Future<bool> _appLocked() async {
    try {
      return await _owner.appLockOn();
    } on Object {
      return true;
    }
  }

  Future<void> _turn(HeadlessHermes hermes) async {
    final announce = WatchBridge.announcer(
      _owner.notifications,
      _owner.settings,
    );
    final handler = WatchRequestHandler(
      repository: () => hermes.repositories.chat,
      transport: () => _owner.transportFor?.call(hermes) ?? hermes.transport(),
      activeProfile: () async => _request.profile,
      announce: (notification) async {
        // What the intent answered in place is not told again; a request is
        // always told, since only the app can answer it.
        final wanted = notification.timeSensitive || _stillWorkingAnswered;
        return !_muted && wanted && await announce(notification);
      },
    );
    final reply = handler.handle({
      'op': 'send',
      'threadId': _request.chatId,
      'text': _request.question,
    });
    final settled = await Future.any<Map<String, Object?>?>([
      reply,
      _abandoned.future.then((_) => null),
    ]);
    final result = settled == null ? null : _resultOf(settled);
    if (result != null) _answer(result);
    hermes.annotate('ask.outcome', (await answered.future).outcome.wire);
    if (result != null) hermes.annotate('ask.reply', result.outcome.wire);
  }

  static AskResult _resultOf(Map<String, Object?> reply) {
    if (reply['ok'] != true || reply['failed'] == true) {
      return const AskResult(AskOutcome.failed);
    }
    final text = reply['text'];
    if (text == WatchRequestHandler.cannotAnswerText) {
      return const AskResult(AskOutcome.needsYou);
    }
    return AskResult(AskOutcome.answered, text is String ? text : '');
  }
}

/// Which window a wait falls in, for the `waited_s` of the `intent.ask`
/// event.
String waitedBucket(Duration waited) {
  if (waited < const Duration(seconds: 5)) return '<5';
  if (waited < const Duration(seconds: 15)) return '<15';
  if (waited < const Duration(seconds: 25)) return '<25';
  return 'late';
}
