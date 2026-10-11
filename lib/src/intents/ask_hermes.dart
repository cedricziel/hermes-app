/// The "Ask Hermes" App Intent's side of the work: send one question as a
/// turn and report what Siri should say, on the headless runtime. The turn is
/// the watch's (`WatchRequestHandler`), so both answer, cut and announce
/// alike.
library;

import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, Tracer, noopAppEventLogger;

import '../app_lock/app_lock_controller.dart';
import '../background/headless_hermes.dart';
import '../background/running_replies.dart';
import '../chat/chat_transport.dart';
import '../deep_links/deep_link_parser.dart' show deepLinkPromptLimit;
import '../notifications/attention_policy.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../telemetry/breadcrumbs.dart';
import '../watch/watch_bridge.dart';
import '../watch/watch_request_handler.dart';
import 'tapped_transport.dart';

/// How a question ended for the person who asked it.
enum AskOutcome {
  answered('answered'),
  stillWorking('still_working'),
  needsYou('needs_you'),

  /// The question went into a turn that was already running in the chat.
  folded('folded'),
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

/// How much earlier than Swift's clock the answer is decided.
const kAskMargin = Duration(milliseconds: 500);

/// What the notification for a question that never reached Hermes says.
const kAskNotSentBody = "Couldn't send your question";

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

  /// How long this side waits before it says "still working": a little less
  /// than [answerWithin], so that it decides before Swift's clock does.
  Duration get decideWithin {
    final left = answerWithin - kAskMargin;
    return left.isNegative ? Duration.zero : left;
  }
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

const _unavailableReasons = {'ready_timeout', 'engine_start_failed'};

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
    this.running,
    this.tracer,
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

  /// Where a reply that outlives its answer is remembered, so that a
  /// background run announces it if this process is suspended first.
  final RunningReplies? running;

  /// For the span of an ask that starts no run (App Lock, a blank question).
  final Tracer? tracer;

  AskRun start(AskRequest request) {
    final ask = _Ask(this, request);
    return AskRun(
      answer: ask.answered.future,
      finished: ask.run(),
      onExpire: ask.abandon,
    );
  }

  /// Records that the Runner could not run an ask in an engine, which Dart
  /// can only learn afterwards. [reason] is one of a fixed few.
  void recordUnavailable(String reason) {
    try {
      events('intent.unavailable', {
        'reason': _unavailableReasons.contains(reason) ? reason : 'other',
      });
    } on Object {
      // Telemetry must never keep an ask from running.
    }
  }
}

class _Ask {
  _Ask(this._owner, this._request) {
    final chat = _unbind(_request.chatId);
    _profile = chat != null ? chat.$1 : _request.profile;
    _threadId = chat?.$2;
    _timer = Timer(
      _request.decideWithin,
      () => _answer(const AskResult(AskOutcome.stillWorking)),
    );
  }

  final AskHermes _owner;
  final AskRequest _request;
  final answered = Completer<AskResult>();
  final _abandoned = Completer<void>();
  final _clock = Stopwatch()..start();
  late final Timer _timer;
  late final String? _profile;
  String? _threadId;
  var _muted = false;

  /// Whether the intent already told the person that the reply will come as
  /// a notification.
  var _stillWorkingAnswered = false;

  /// What the turn did, as its events went by. A frame of the reply means
  /// Hermes has the question; so does the transport saying that
  /// `prompt.submit` was answered, which comes before any frame.
  var _frameSeen = false;
  PromptAcknowledgement? _acknowledgement;
  Timer? _watching;
  var _completed = false;
  var _folded = false;
  var _registered = false;

  bool get _foreground => _owner.engine == AskEngine.foreground;

  /// Whether Hermes has the question.
  bool get _reached =>
      _frameSeen || (_acknowledgement?.promptAccepted ?? false);

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
    if (_stillWorkingAnswered) _watchForHandOver();
  }

  /// Hands the reply over as soon as Hermes has the question, which a
  /// transport can know without a single frame having come.
  void _watchForHandOver() {
    _handOver();
    if (_registered) return;
    _watching ??= Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _handOver(),
    );
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

  /// The span of an ask that never started a run.
  void _spanWithoutRun(AskOutcome outcome) {
    try {
      _owner.tracer
          ?.startSpan(
            'background.task',
            attributes: {
              'task': 'intent.ask',
              'engine': _owner.engine.name,
              'continued': _request.chatId != null,
              'ask.outcome': outcome.wire,
            },
          )
          .end();
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
        _spanWithoutRun(AskOutcome.appLocked);
        return;
      }
      if (_request.question.trim().isEmpty) {
        _answer(const AskResult(AskOutcome.failed));
        _spanWithoutRun(AskOutcome.failed);
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
      if (_stillWorkingAnswered) {
        _handOver();
        if (!_reached) await _tellNotSent();
      }
    } on Object {
      _answer(const AskResult(AskOutcome.failed));
    } finally {
      _timer.cancel();
      _watching?.cancel();
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
    final post = _poster();
    final handler = WatchRequestHandler(
      repository: () => hermes.repositories.chat,
      transport: () {
        final inner = _owner.transportFor?.call(hermes) ?? hermes.transport();
        if (inner is PromptAcknowledgement) {
          _acknowledgement = inner as PromptAcknowledgement;
        }
        return TappedTransport(inner, _seen);
      },
      activeProfile: () async => _request.profile,
      announce: (notification) async {
        if (_muted) return false;
        // A request is always told, since only the app can answer it.
        if (notification.timeSensitive) return post(notification);
        // What was answered in place is not told again.
        if (!_stillWorkingAnswered) return false;
        // The turn ending without a reply (a timeout, a closed socket) says
        // nothing about the reply: the background check decides.
        if (notification.body == kReplyFailedBody && !_completed) return false;
        return post(notification);
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

  /// Notes what a turn's event says about how the ask is going.
  void _seen(ChatEvent event) {
    switch (event) {
      case ThreadBound(:final threadId):
        // The chat exists; the question may not have gone into it yet.
        _threadId = threadId;
      case PromptFolded():
        _frameSeen = true;
        _folded = true;
      case ReplyCompleted():
        _frameSeen = true;
        _completed = true;
        // Announced by this process, so there is nothing left to hand over.
        if (_registered && !_muted) _forget();
      default:
        _frameSeen = true;
    }
    if (_stillWorkingAnswered) _handOver();
  }

  AskResult _resultOf(Map<String, Object?> reply) {
    if (_folded && !_completed) return const AskResult(AskOutcome.folded);
    if (reply['ok'] != true || reply['failed'] == true) {
      return const AskResult(AskOutcome.failed);
    }
    final text = reply['text'];
    if (text == WatchRequestHandler.cannotAnswerText) {
      return const AskResult(AskOutcome.needsYou);
    }
    return AskResult(AskOutcome.answered, text is String ? text : '');
  }

  /// Hands the reply to the background check, which announces it if this
  /// process is suspended before it does: "I'll notify you" was promised.
  void _handOver() {
    final running = _owner.running;
    final thread = _threadId;
    // A chat whose question never went in must not be announced for its
    // earlier reply.
    if (_registered ||
        _completed ||
        running == null ||
        thread == null ||
        !_reached) {
      return;
    }
    _registered = true;
    _watching?.cancel();
    unawaited(
      _quietly(
        () => running.add(
          RunningReply(
            profile: _profile,
            threadId: thread,
            since: DateTime.now(),
            fromAsk: true,
          ),
        ),
      ),
    );
  }

  void _forget() {
    final running = _owner.running;
    final thread = _threadId;
    if (running == null || thread == null) return;
    unawaited(
      _quietly(
        () => running.forget([
          RunningReply(
            profile: _profile,
            threadId: thread,
            since: DateTime.now(),
          ),
        ]),
      ),
    );
  }

  /// Tells the person that the question they were promised an answer to never
  /// reached Hermes. The notification opens a new chat with it, unsent.
  Future<void> _tellNotSent() => _quietly(() async {
    // With App Lock on, nothing of the question stays in the notification.
    final keep = !await _appLocked();
    await _poster()(
      AttentionNotification(
        threadId: 'ask:${DateTime.now().microsecondsSinceEpoch}',
        title: WatchRequestHandler.untitledChat,
        body: kAskNotSentBody,
        profile: _profile,
        prompt: keep
            ? _request.question.characters.take(deepLinkPromptLimit).toString()
            : null,
      ),
    );
  });

  Future<bool> Function(AttentionNotification) _poster() =>
      WatchBridge.announcer(_owner.notifications, _owner.settings);

  static Future<void> _quietly(Future<void> Function() work) async {
    try {
      await work();
    } on Object {
      // Nothing here may keep an ask from ending.
    }
  }

  /// The profile and the id of a chat id in the `<encoded profile>/<id>`
  /// shape, or null for none; the profile is null for the server's default.
  static (String?, String)? _unbind(String? chatId) {
    if (chatId == null) return null;
    final slash = chatId.indexOf('/');
    if (slash < 0 || slash == chatId.length - 1) return null;
    try {
      final profile = Uri.decodeComponent(chatId.substring(0, slash));
      return (profile.isEmpty ? null : profile, chatId.substring(slash + 1));
    } on ArgumentError {
      return null;
    }
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
