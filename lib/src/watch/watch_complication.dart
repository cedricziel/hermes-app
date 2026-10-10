import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/services.dart';

import '../chat/chat_transport.dart';
import '../live_activities/live_activity_state.dart';
import '../telemetry/breadcrumbs.dart';

/// How the status reached the watch: `complication` (a budgeted transfer that
/// wakes the watch app), `context` (the latest-wins fallback), or `none` when
/// there is no watch to tell.
typedef ComplicationSender = Future<String> Function(
  Map<String, Object> payload,
);

/// The chat id the watch uses for a chat of [profile]: the profile and the
/// session id, because a session id is only unique within a profile.
String boundThreadId(String? profile, String sessionId) =>
    '${Uri.encodeComponent(profile ?? '')}/$sessionId';

/// Tells the watch's complications what the latest turn is doing. Two places
/// feed it, because no single object sees every turn: `ChatController` for a
/// reply sent from the phone, `WatchRequestHandler` for one sent from the
/// watch. It sends only the state, a time, the chat's title and the watch's
/// id for the chat, never anything a reply, command or question said.
class WatchComplicationStatus {
  WatchComplicationStatus({
    required this.send,
    this.appLock = _off,
    this.breadcrumbs = Breadcrumbs.none,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// A status that goes to the watch app over [channel], the one the watch
  /// relay uses.
  factory WatchComplicationStatus.overChannel(
    MethodChannel channel, {
    bool Function() appLock = _off,
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
  }) => WatchComplicationStatus(
    send: (payload) async =>
        await channel.invokeMethod<String>('complication', payload) ?? 'none',
    appLock: appLock,
    breadcrumbs: breadcrumbs,
  );

  final ComplicationSender send;

  /// Whether App Lock is on: the status then holds the state alone.
  final bool Function() appLock;
  final Breadcrumbs breadcrumbs;
  final DateTime Function() _now;

  static bool _off() => false;

  static const _version = 1;

  final _turns = <Object, _Turn>{};
  Map<String, Object>? _last;

  /// A turn [turn] has started for a chat. [title] is null for a chat the
  /// gateway has not named, [threadId] the watch's id for it once stored.
  /// A turn that is still running keeps its state.
  void begin(Object turn, {required String? title, String? threadId}) {
    final current = _turns[turn];
    if (current != null && !current.state.finished) return;
    _turns[turn] = _Turn(ReplyActivityState.working, _now())
      ..title = title
      ..threadId = threadId;
    _publish();
  }

  /// Moves [turn] along for [event]. The title and chat are as they are now,
  /// since both can arrive during the turn.
  void onEvent(
    Object turn,
    ChatEvent event, {
    required String? title,
    String? threadId,
  }) {
    final current = _turns[turn];
    if (current == null) return;
    final next = nextActivityState(current.state, event);
    if (next == null) {
      _turns.remove(turn);
    } else {
      if (next != current.state) current.updatedAt = _now();
      current
        ..state = next
        ..title = title
        ..threadId = threadId;
    }
    _publish();
  }

  /// [turn]'s chat is gone, so it is not shown.
  void drop(Object turn) {
    if (_turns.remove(turn) != null) _publish();
  }

  /// Forgets every turn, as when the user signs out.
  void clear() {
    _turns.clear();
    _publish();
  }

  /// The turn worth showing: the newest one waiting for the user, else the
  /// newest.
  _Turn? _shown() {
    _Turn? best;
    for (final turn in _turns.values) {
      if (best == null || turn._outranks(best)) best = turn;
    }
    return best;
  }

  void _publish() {
    _forgetOldFinished();
    final shown = _shown();
    final payload = <String, Object>{
      'v': _version,
      'state': shown == null ? 'none' : shown.wireState,
      if (shown != null) ...{
        'updatedAt': shown.updatedAt.millisecondsSinceEpoch ~/ 1000,
        if (!appLock()) ...{
          if (shown.title != null) 'title': shown.title!,
          if (shown.threadId != null) 'threadId': shown.threadId!,
        },
      },
    };
    final last = _last;
    if (last == null && shown == null) return;
    if (last != null && mapEquals(last, payload)) return;
    _last = payload;
    unawaited(_deliver(payload));
  }

  /// Only the newest finished turn is kept, as the glance's last word.
  void _forgetOldFinished() {
    _Turn? newest;
    for (final turn in _turns.values) {
      if (turn.state.finished &&
          (newest == null || turn.updatedAt.isAfter(newest.updatedAt))) {
        newest = turn;
      }
    }
    _turns.removeWhere(
      (_, turn) => turn.state.finished && !identical(turn, newest),
    );
  }

  Future<void> _deliver(Map<String, Object> payload) async {
    try {
      final via = await send(payload);
      if (via != 'none') breadcrumbs('watch.complication.sent', {'via': via});
    } on Object {
      breadcrumbs('watch.complication.failed');
    }
  }
}

class _Turn {
  _Turn(this.state, this.updatedAt);

  ReplyActivityState state;
  DateTime updatedAt;
  String? title;
  String? threadId;

  bool get waiting => switch (state) {
    ReplyActivityState.approval ||
    ReplyActivityState.question ||
    ReplyActivityState.needsYou => true,
    _ => false,
  };

  String get wireState => switch (state) {
    ReplyActivityState.working => 'working',
    ReplyActivityState.ready => 'ready',
    ReplyActivityState.failed => 'failed',
    _ => 'waiting',
  };

  bool _outranks(_Turn other) {
    if (waiting != other.waiting) return waiting;
    return !updatedAt.isBefore(other.updatedAt);
  }
}
