/// Sends the text typed into a "Reply ready" notification as a new prompt in
/// that chat, from whichever isolate received it, on the headless runtime.
///
/// The text goes out at most once, exactly as typed, queued behind a turn
/// that still runs, and is never resent. Every ending the user must hear of
/// (not sent, may not have been sent, App Lock) goes through [postEnding].
library;

import 'dart:async';
import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, Tracer, noopAppEventLogger;

import '../app_lock/app_lock_controller.dart';
import '../background/app_presence.dart' as presence;
import '../background/headless_hermes.dart';
import '../background/running_replies.dart';
import '../chat/chat_transport.dart';
import '../telemetry/breadcrumbs.dart';
import 'attention_policy.dart';
import 'local_notification_service.dart' show targetFromPayload;
import 'notification_posting.dart';
import 'notification_service.dart';
import 'notification_settings.dart';
import 'request_notifications.dart' show accountHashFor;

/// Where an inline reply is handled, which sets when its run is cut off and
/// whether it may post after its budget.
enum InlineReplyRoute {
  /// The running app, after the background isolate handed the response over.
  /// The isolate waits until `due` plus a grace for its report, so the app
  /// stops six seconds before `due` and posts nothing after it.
  app('app', Duration(seconds: 6), postsAfterDue: false),

  /// The background isolate alone: the run ends at `due`.
  lone('lone', Duration.zero, postsAfterDue: true),

  /// The Mac's app isolate: the run ends at `due`.
  mac('mac', Duration.zero, postsAfterDue: true);

  const InlineReplyRoute(this.wire, this.margin, {required this.postsAfterDue});

  /// The `route` of the `notification.reply` event.
  final String wire;

  /// How long before `due` the run is cut off.
  final Duration margin;

  /// Whether an ending may still be posted after `due`.
  final bool postsAfterDue;
}

/// How an inline reply went, as `notification.reply` logs it.
enum InlineReplyOutcome {
  answered('answered'),
  sent('sent'),
  failed('failed'),
  unconfirmed('unconfirmed'),

  /// The run found nobody signed in before any prompt was written.
  signedOut('signed_out'),

  /// The keychain could not be read yet, which is not App Lock.
  storeLocked('store_locked'),
  unreachable('unreachable'),
  appLocked('app_locked'),

  /// Nothing to do: no text, not a chat reply. Nothing is logged.
  ignored('ignored');

  const InlineReplyOutcome(this.wire);

  final String wire;
}

/// The notification a reply that did not go through ends in.
enum ReplyEnding { notSent, unconfirmed, appLocked }

/// What [sendInlineReply] did. [ending] is the ending the outcome calls for
/// (null when none) and [endingPosted] whether it was posted, which the app
/// reports to the background isolate.
class InlineReplyResult {
  const InlineReplyResult(
    this.outcome, {
    this.ending,
    this.endingPosted = false,
  });

  final InlineReplyOutcome outcome;
  final ReplyEnding? ending;
  final bool endingPosted;
}

/// What a send's transport said about how far the prompt got: written once
/// `onSubmitting` ran, acknowledged once the server answered `prompt.submit`.
/// After [freeze], a late callback changes nothing.
class SubmitMark {
  PromptAcknowledgement? _transport;
  var _written = false;
  var _frozen = false;

  /// Reads the acknowledgement from [transport], when it can tell.
  void bind(ChatTransport transport) {
    if (transport is PromptAcknowledgement) {
      _transport = transport as PromptAcknowledgement;
    }
  }

  /// `prompt.submit` was, or may have been, written.
  bool get written => _written;

  /// The server answered `prompt.submit`.
  bool get acknowledged {
    try {
      return _transport?.promptAccepted ?? false;
    } on Object {
      return false;
    }
  }

  /// The transport's `onSubmitting`.
  void markWritten() {
    if (!_frozen) _written = true;
  }

  /// Decides: nothing more can be written, whatever a callback says later.
  void freeze() => _frozen = true;
}

/// Posts the ending [ending] for the chat [threadId]: the one place every
/// ending goes through, whoever decided it.
///
/// Nothing is posted while notifications are off or not permitted. App Lock
/// is read again right now ([appLockOn]; unreadable counts as on): when it is
/// on, the [draft] and the chat's [title] are dropped (the title becomes
/// "Hermes") and the body keeps its meaning, so a not-sent ending then says to
/// write it again. A kept [draft] (with the [accountHash] it was typed under)
/// is only in the payload, never in the title or the body. Returns whether a
/// notification was accepted.
Future<bool> postEnding({
  required NotificationService? notifications,
  NotificationSettings? settings,
  required Future<bool> Function() appLockOn,
  required ReplyEnding ending,
  required String threadId,
  String? profile,
  String title = _hermes,
  String? draft,
  String? accountHash,
}) async {
  final locked = await _lockedNow(appLockOn);
  final keep =
      !locked &&
      ending == ReplyEnding.notSent &&
      draft != null &&
      accountHash != null;
  return _post(
    notifications,
    settings,
    AttentionNotification(
      threadId: threadId,
      profile: profile,
      title: locked || ending == ReplyEnding.appLocked ? _hermes : title,
      body: switch (ending) {
        ReplyEnding.notSent => keep ? kReplyNotSentKeptBody : kReplyNotSentBody,
        ReplyEnding.unconfirmed => kReplyUnconfirmedBody,
        ReplyEnding.appLocked => kOpenToReplyBody,
      },
      bodyIsPlainText: true,
      payloadProfile: ending != ReplyEnding.appLocked,
      draft: keep ? draft : null,
      accountHash: keep ? accountHash : null,
    ),
  );
}

const _hermes = 'Hermes';

Future<bool> _lockedNow(Future<bool> Function() appLockOn) async {
  try {
    return await appLockOn();
  } on Object {
    return true;
  }
}

/// Posts [notification] while notifications are on and permitted.
Future<bool> _post(
  NotificationService? service,
  NotificationSettings? settings,
  AttentionNotification notification,
) async {
  if (service == null) return false;
  try {
    if (settings != null) {
      if (!settings.loaded) await settings.load();
      if (!settings.enabled) return false;
    }
    if (await service.allowed() == false) return false;
    if (service is NotificationPoster) {
      final result = await (service as NotificationPoster).post(notification);
      return result.status == NotificationPostStatus.accepted;
    }
    await service.show(notification);
    return true;
  } on Object {
    return false;
  }
}

/// Sends the reply typed into the notification whose payload is [payload]
/// ([input] is the text), and tells the user how it ended. [due] is the end
/// of the budget (`kAnswerBudget` after the response); the run is cut off at
/// `due - route.margin`, and [now] is the clock.
///
/// Nothing is sent for an empty [input], a job or message target or a payload
/// that is not a reply's (no `'y'`). App Lock is read first ([appLockAtArrival];
/// on or unreadable sends nothing and keeps nothing). The text goes out once
/// with `queued: true` (never `sendQueued`, which refuses a server without
/// profiles) and is never resent. It never answers a request, clears the
/// session or signs out.
///
/// [running] and [platform]: on iOS a reply the server acknowledged but that
/// has not finished is recorded in [running] for the background check; on
/// macOS nothing is recorded. An answer inside the window is announced only
/// while [appInFront] says the app is not in front.
Future<InlineReplyResult> sendInlineReply({
  required String? payload,
  required String? input,
  required DateTime due,
  required InlineReplyRoute route,
  required TargetPlatform platform,
  NotificationService? notifications,
  NotificationSettings? settings,
  Future<bool> Function()? appLockAtArrival,
  Future<bool> Function()? appLockBeforePost,
  Future<bool> Function()? appInFront,
  RunningReplies? running,
  DateTime Function()? now,
  HeadlessDeps? deps,
  ChatTransport Function(HeadlessHermes hermes)? transportFor,
  AppEventLogger events = noopAppEventLogger,
  Breadcrumbs breadcrumbs = Breadcrumbs.none,
  Tracer? tracer,
  String engine = 'headless',
}) => _InlineReply(
  payload: payload,
  input: input,
  due: due,
  route: route,
  platform: platform,
  notifications: notifications,
  settings: settings,
  appLockAtArrival: appLockAtArrival ?? AppLockController.savedEnabled,
  appLockBeforePost: appLockBeforePost ?? AppLockController.savedEnabled,
  appInFront: appInFront ?? presence.appInFront,
  running: running,
  now: now ?? DateTime.now,
  deps: deps,
  transportFor: transportFor,
  events: events,
  breadcrumbs: breadcrumbs,
  tracer: tracer,
  engine: engine,
).run();

/// What the body found out; the verdict is made from it and the mark.
class _Verdict {
  const _Verdict(
    this.outcome, {
    this.ending,
    this.keepText = false,
    this.record = false,
  });

  final InlineReplyOutcome outcome;
  final ReplyEnding? ending;

  /// Whether the text may be kept in the ending's payload.
  final bool keepText;

  /// Whether the reply is acknowledged and still running, for the background
  /// check.
  final bool record;
}

class _InlineReply {
  _InlineReply({
    required this.payload,
    required this.input,
    required this.due,
    required this.route,
    required this.platform,
    required this.notifications,
    required this.settings,
    required this.appLockAtArrival,
    required this.appLockBeforePost,
    required this.appInFront,
    required this.running,
    required this.now,
    required this.deps,
    required this.transportFor,
    required this.events,
    required this.breadcrumbs,
    required this.tracer,
    required this.engine,
  });

  final String? payload;
  final String? input;
  final DateTime due;
  final InlineReplyRoute route;
  final TargetPlatform platform;
  final NotificationService? notifications;
  final NotificationSettings? settings;
  final Future<bool> Function() appLockAtArrival;
  final Future<bool> Function() appLockBeforePost;
  final Future<bool> Function() appInFront;
  final RunningReplies? running;
  final DateTime Function() now;
  final HeadlessDeps? deps;
  final ChatTransport Function(HeadlessHermes hermes)? transportFor;
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  final Tracer? tracer;
  final String engine;

  final _mark = SubmitMark();
  ChatTransport? _transport;

  /// After the cutoff nothing more is announced.
  var _muted = false;

  /// An announcement of the answer is being posted or was.
  var _announcing = false;
  Future<void>? _announcement;

  /// The body compared the payload's account hash with the run's, and they
  /// matched.
  var _accountVerified = false;

  late final String _threadId;
  late final String? _profile;
  late final String _title;
  late final String? _accountHash;

  Duration get _closeGrace => deps?.closeGrace ?? const Duration(seconds: 3);

  Future<InlineReplyResult> run() async {
    final text = input;
    if (!_parse() || text == null || text.trim().isEmpty) {
      return const InlineReplyResult(InlineReplyOutcome.ignored);
    }
    if (await _lockedAtArrival()) return _refuseForAppLock();

    final left = due.subtract(route.margin).difference(now());
    final outcome = await withHeadlessHermes<_Verdict>(
      (hermes) => _body(hermes, text),
      task: 'notification.reply',
      attributes: {'engine': engine},
      timeout: left.isNegative ? Duration.zero : left,
      deps: deps,
    );
    // Whatever the body still does must not announce: the window is over.
    _muted = true;
    // The outcome is decided once, from the mark, with the transport closed:
    // nothing it still does can be written to the server any more.
    await _closeTransport();
    _mark.freeze();
    // An announcement under way gets to finish, so that a reply is never left
    // neither recorded nor announced when the process is suspended.
    try {
      await _announcement?.timeout(_closeGrace);
    } on Object {
      // Gave up waiting; it goes on, or is dropped with the process.
    }
    final (verdict, logged) = switch (outcome) {
      HeadlessDone(:final value) => (value, value.outcome),
      HeadlessSignedOut() => _byMark(
        InlineReplyOutcome.signedOut,
        keepText: false,
      ),
      // Locked ends before the body, so the account was never verified.
      HeadlessLocked() => _byMark(
        InlineReplyOutcome.storeLocked,
        keepText: false,
      ),
      HeadlessUnreachable() => _byMark(
        InlineReplyOutcome.unreachable,
        keepText: _accountVerified,
      ),
    };
    // An answer already announced (or being) needs no record.
    if (verdict.record && !_announcing) await _record();
    final posted = await _end(verdict, text);
    _log(logged);
    return InlineReplyResult(
      verdict.outcome,
      ending: verdict.ending,
      endingPosted: posted,
    );
  }

  /// Reads the payload; false when it is not a chat reply's.
  bool _parse() {
    final raw = payload;
    if (raw == null) return false;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return false;
    }
    if (decoded is! Map || decoded['y'] == null) return false;
    final target = targetFromPayload(raw);
    if (target == null ||
        target.isJob ||
        target.isMessage ||
        target.prompt != null ||
        target.threadId.isEmpty) {
      return false;
    }
    _threadId = target.threadId;
    _profile = target.profile;
    final title = decoded['n'];
    _title = title is String && title.isNotEmpty ? title : _hermes;
    final account = decoded['a'];
    _accountHash = account is String && account.isNotEmpty ? account : null;
    return true;
  }

  Future<bool> _lockedAtArrival() async {
    try {
      return await appLockAtArrival();
    } on Object {
      return true;
    }
  }

  Future<InlineReplyResult> _refuseForAppLock() async {
    final posted = await _end(
      const _Verdict(
        InlineReplyOutcome.appLocked,
        ending: ReplyEnding.appLocked,
      ),
      '',
    );
    try {
      tracer
          ?.startSpan(
            'background.task',
            attributes: {
              'task': 'notification.reply',
              'engine': engine,
              'reply.outcome': InlineReplyOutcome.appLocked.wire,
            },
          )
          .end();
    } on Object {
      // Telemetry must never keep an ending from the user.
    }
    _log(InlineReplyOutcome.appLocked);
    return InlineReplyResult(
      InlineReplyOutcome.appLocked,
      ending: ReplyEnding.appLocked,
      endingPosted: posted,
    );
  }

  Future<_Verdict> _body(HeadlessHermes hermes, String text) async {
    final verdict = await _send(hermes, text);
    hermes.annotate('reply.outcome', verdict.outcome.wire);
    return verdict;
  }

  Future<_Verdict> _send(HeadlessHermes hermes, String text) async {
    final account = _accountHash;
    if (account == null || accountHashFor(hermes.accountKey) != account) {
      // Posted for another account or server: nothing is sent or kept.
      return const _Verdict(
        InlineReplyOutcome.failed,
        ending: ReplyEnding.notSent,
      );
    }
    _accountVerified = true;
    final cutoff = hermes.untilDeadline;
    if (cutoff <= Duration.zero) return _cut();
    final transport = _transport =
        transportFor?.call(hermes) ?? hermes.transport();
    _mark.bind(transport);

    final done = Completer<_Verdict>();
    var reclaimed = false;
    StreamSubscription<ChatEvent>? subscription;
    Timer? timer;
    void finish(FutureOr<_Verdict> Function() verdict) {
      if (done.isCompleted) return;
      timer?.cancel();
      unawaited(subscription?.cancel().catchError((Object _) {}));
      done.complete(Future.sync(verdict));
    }

    timer = Timer(cutoff, () => finish(_cut));
    try {
      subscription = transport
          .send(
            threadId: _threadId,
            profile: _profile,
            text: text,
            queued: true,
            onSubmitting: _mark.markWritten,
          )
          .listen(
            (event) {
              switch (event) {
                case ReplyCompleted(
                  failed: false,
                  stopped: false,
                  text: final answer,
                ):
                  finish(() => _answered(answer));
                case ReplyCompleted():
                  // A turn that ended in an error or a stop: nothing runs.
                  finish(_finishedTurn);
                case PromptFolded():
                  // No reply of its own will come: not recorded either, or the
                  // check would announce the turn it was folded into.
                  finish(() => const _Verdict(InlineReplyOutcome.sent));
                case SessionReclaimed():
                  reclaimed = true;
                default:
                  break;
              }
            },
            onError: (Object error) => finish(() => _failed(error)),
            onDone: () => finish(() => _ended(reclaimed)),
            cancelOnError: true,
          );
    } on Object catch (error) {
      finish(() => _failed(error));
    }
    return done.future;
  }

  _Verdict _finishedTurn() {
    final verdict = _byMark(InlineReplyOutcome.sent).$1;
    return verdict.record ? const _Verdict(InlineReplyOutcome.sent) : verdict;
  }

  /// The window ended before the reply did: stop waiting, mute announcing,
  /// close the transport so that nothing more can be written, then decide.
  Future<_Verdict> _cut() async {
    _muted = true;
    await _closeTransport();
    _mark.freeze();
    return _byMark(InlineReplyOutcome.sent).$1;
  }

  Future<_Verdict> _answered(String answer) async {
    final announcing = _announcement = _announce(answer);
    await announcing;
    return const _Verdict(InlineReplyOutcome.answered);
  }

  /// Announces the answer, only while the app is not in front and the window
  /// has not ended. The announcement is recorded first, so the chat's replay
  /// when the app returns does not announce it again.
  Future<void> _announce(String answer) async {
    if (_muted) return;
    final front = await _quiet(appInFront, true);
    if (front || _muted) return;
    final locked = await _lockedNow(appLockBeforePost);
    final reply = RunningReply(
      profile: _profile,
      threadId: _threadId,
      since: now(),
    );
    try {
      await running?.markAnnounced([reply]);
    } on Object {
      // Announcing goes on; at worst the replay announces it once more.
    }
    if (_muted) {
      // The run ended meanwhile and decided without this announcement.
      try {
        await running?.takeAnnounced(_profile, _threadId);
      } on Object {
        // Nothing more to undo.
      }
      return;
    }
    _announcing = true;
    await _post(
      notifications,
      settings,
      replyReadyNotification(
        threadId: _threadId,
        title: locked ? _hermes : _title,
        text: answer,
        profile: _profile,
        appLock: locked,
      ),
    );
  }

  /// The verdict for a failed send, by the step it reached.
  _Verdict _failed(Object error) {
    if (error is SendFailure) {
      if (error.step == SendStep.reply || _mark.acknowledged) {
        return _byMark(InlineReplyOutcome.sent, acknowledged: true).$1;
      }
      if (error.beforeSubmit && !_mark.written) {
        return _byMark(InlineReplyOutcome.failed).$1;
      }
      return const _Verdict(
        InlineReplyOutcome.unconfirmed,
        ending: ReplyEnding.unconfirmed,
      );
    }
    // Not typed: only the mark knows how far it got.
    return _byMark(InlineReplyOutcome.failed).$1;
  }

  /// The stream ended with no error and no reply: told by the mark. After the
  /// answer, a clean end means nothing runs any more, except for a session
  /// another client reclaimed.
  _Verdict _ended(bool reclaimed) {
    final verdict = _byMark(InlineReplyOutcome.sent).$1;
    if (verdict.outcome == InlineReplyOutcome.sent && !reclaimed) {
      return const _Verdict(InlineReplyOutcome.sent);
    }
    return verdict;
  }

  /// What the mark says: not written, nothing was sent; written and not
  /// acknowledged, it may have been; acknowledged, it was, and the reply may
  /// still run. [fallback] is what a run that never wrote reports.
  (_Verdict, InlineReplyOutcome) _byMark(
    InlineReplyOutcome fallback, {
    bool keepText = true,
    bool acknowledged = false,
  }) {
    if (acknowledged || _mark.acknowledged) {
      return (
        const _Verdict(InlineReplyOutcome.sent, record: true),
        InlineReplyOutcome.sent,
      );
    }
    if (_mark.written) {
      return (
        const _Verdict(
          InlineReplyOutcome.unconfirmed,
          ending: ReplyEnding.unconfirmed,
        ),
        InlineReplyOutcome.unconfirmed,
      );
    }
    if (fallback == InlineReplyOutcome.sent) {
      // A run that ended with no sign of the prompt having gone out.
      fallback = InlineReplyOutcome.failed;
    }
    return (
      _Verdict(
        InlineReplyOutcome.failed,
        ending: ReplyEnding.notSent,
        keepText: keepText,
      ),
      fallback,
    );
  }

  /// Tells the user what the verdict calls for. Past `due` the app route
  /// posts nothing: the background isolate then does.
  Future<bool> _end(_Verdict verdict, String text) async {
    final ending = verdict.ending;
    if (ending == null) return false;
    if (!route.postsAfterDue && !now().isBefore(due)) return false;
    final keep =
        verdict.keepText &&
        text.characters.length <= kPreviewLength &&
        _accountHash != null;
    return postEnding(
      notifications: notifications,
      settings: settings,
      appLockOn: appLockBeforePost,
      ending: ending,
      threadId: _threadId,
      profile: _profile,
      title: _title,
      draft: keep ? text : null,
      accountHash: keep ? _accountHash : null,
    );
  }

  /// Remembers the chat for the background check, on iOS only.
  Future<void> _record() async {
    if (platform != TargetPlatform.iOS) return;
    try {
      await running?.add(
        RunningReply(
          profile: _profile,
          threadId: _threadId,
          since: now(),
          fromAsk: true,
        ),
      );
    } on Object {
      // The answer is then seen when the chat is opened.
    }
  }

  Future<void> _closeTransport() async {
    final transport = _transport;
    if (transport == null) return;
    try {
      await transport.close().timeout(_closeGrace);
    } on Object {
      // Nothing more can be written to a transport that failed to close.
    }
  }

  void _log(InlineReplyOutcome outcome) {
    try {
      events('notification.reply', {
        'outcome': outcome.wire,
        'route': route.wire,
      });
      if (engine == 'foreground') {
        breadcrumbs('notification.replied', {'outcome': outcome.wire});
      }
    } on Object {
      // Telemetry must never keep an ending from the user.
    }
  }

  static Future<bool> _quiet(
    Future<bool> Function() read,
    bool fallback,
  ) async {
    try {
      return await read();
    } on Object {
      return fallback;
    }
  }
}
