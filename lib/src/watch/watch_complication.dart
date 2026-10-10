import 'dart:async';

import 'package:flutter/foundation.dart' show Listenable, mapEquals;
import 'package:flutter/services.dart';

import '../chat/chat_transport.dart';
import '../live_activities/live_activity_state.dart';
import '../telemetry/breadcrumbs.dart';

/// Hands [payload] to the watch and answers how it went: `complication` (a
/// budgeted transfer that wakes the watch app), `context` (the latest-wins
/// fallback), or `none` when there is no watch to tell. [urgent] asks for the
/// transfer: a change of state, which the watch face should show now.
typedef ComplicationSender = Future<String> Function(
  Map<String, Object> payload, {
  required bool urgent,
});

/// How long a working or waiting turn is believed without news. Hermes has no
/// push channel, so a phone app that was suspended cannot say a turn ended,
/// and a turn left waiting when its connection closed has nobody to end it.
/// The watch applies the same limit to what it holds.
const kComplicationStaleAfter = Duration(minutes: 30);

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
    this.lockChanges,
    this.breadcrumbs = Breadcrumbs.none,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    lockChanges?.addListener(_publish);
  }

  /// A status that goes to the watch app over [channel], the one the watch
  /// relay uses.
  factory WatchComplicationStatus.overChannel(
    MethodChannel channel, {
    bool Function() appLock = _off,
    Listenable? lockChanges,
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
  }) => WatchComplicationStatus(
    send: (payload, {required urgent}) async =>
        await channel.invokeMethod<String>('complication', {
          'payload': payload,
          'urgent': urgent,
        }) ??
        'none',
    appLock: appLock,
    lockChanges: lockChanges,
    breadcrumbs: breadcrumbs,
  );

  final ComplicationSender send;

  /// Whether App Lock is on: the status then holds the state alone.
  final bool Function() appLock;

  /// Notifies when [appLock] may have changed, so a title already on the watch
  /// is taken off it.
  final Listenable? lockChanges;
  final Breadcrumbs breadcrumbs;
  final DateTime Function() _now;

  static bool _off() => false;

  static const _version = 1;

  final _turns = <Object, _Turn>{};

  /// What was last handed to [send], without its sequence number.
  Map<String, Object>? _last;
  var _seq = 0;

  /// The turn [turn] has started for a chat. [title] is null until the gateway
  /// or the server has named the chat: a title made from the prompt would put
  /// the prompt on the watch face. [threadId] is the watch's id for the chat
  /// once it is stored. A turn that is still running keeps its state; one the
  /// watch sent ([fromWatch]) does not spend the complication budget.
  void begin(
    Object turn, {
    required String? title,
    String? threadId,
    bool fromWatch = false,
  }) {
    final current = _turns[turn];
    if (current != null && !current.state.finished) return;
    _turns[turn] = _Turn(ReplyActivityState.working, _now(), fromWatch)
      ..title = title
      ..threadId = threadId;
    _supersede(turn);
    _publish();
  }

  /// A turn that starts on a chat replaces the earlier ones of that chat, which
  /// can no longer be waiting for anything: one the watch left waiting on a
  /// request it could not answer is not ended by anything else.
  void _supersede(Object turn) {
    final threadId = _turns[turn]?.threadId;
    if (threadId == null) return;
    _turns.removeWhere(
      (key, other) => key != turn && other.threadId == threadId,
    );
  }

  /// Moves [turn] along for [event]. The title and chat are as they are now,
  /// since both can arrive during the turn. A finished turn starts again when
  /// the same chat opens another one (a goal that goes on, a queued prompt)
  /// or asks for something, and a turn nobody began here opens the same way.
  void onEvent(
    Object turn,
    ChatEvent event, {
    required String? title,
    String? threadId,
    bool fromWatch = false,
  }) {
    var current = _turns[turn];
    var started = false;
    if (current == null || current.state.finished) {
      if (opensTurn(event) || _asks(event)) {
        current = _turns[turn] = _Turn(
          ReplyActivityState.working,
          _now(),
          fromWatch,
        );
        started = true;
      } else if (current == null) {
        return;
      }
    }
    final next = nextActivityState(current.state, event);
    if (next == null) {
      _turns.remove(turn);
    } else {
      if (next != current.state) current.updatedAt = _now();
      current
        ..state = next
        ..title = title
        ..threadId = threadId;
      if (started) _supersede(turn);
    }
    _publish();
  }

  static bool _asks(ChatEvent event) =>
      event is ApprovalRequested ||
      event is ClarifyRequested ||
      event is VaultRequested ||
      event is UnsupportedRequested;

  /// [turn]'s chat is gone, so it is not shown.
  void drop(Object turn) {
    if (_turns.remove(turn) != null) _publish();
  }

  /// [turn] can no longer be followed, as when the chat's profile went out of
  /// view: it stops being shown unless it already finished, since a "working"
  /// nobody can end would stay on the watch.
  void abandon(Object turn) {
    final current = _turns[turn];
    if (current == null || current.state.finished) return;
    drop(turn);
  }

  /// Forgets every turn and tells the watch, as when the user signs out. The
  /// watch may still hold a status from an earlier run, so it is sent whether
  /// or not this run showed anything.
  void clear() {
    _turns.clear();
    _publish(force: true);
  }

  void dispose() => lockChanges?.removeListener(_publish);

  /// The turn worth showing: the newest one waiting for the user, else the
  /// newest.
  _Turn? _shown() {
    _Turn? best;
    for (final turn in _turns.values) {
      if (best == null || turn._outranks(best)) best = turn;
    }
    return best;
  }

  void _publish({bool force = false}) {
    _forgetStale();
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
    if (!force) {
      if (last == null && shown == null) return;
      if (last != null && mapEquals(last, payload)) return;
    }
    _last = payload;
    // The watch applies a payload only if it is newer than what it holds, and
    // two transports can deliver out of order. The clock in milliseconds also
    // keeps it rising across a restart.
    final now = _now().millisecondsSinceEpoch;
    _seq = now > _seq ? now : _seq + 1;
    // A change of state is news worth the budget, a stop or a clear included,
    // and so is a title taken off the watch for App Lock. A new title or chat
    // id is not. The first working of a turn the watch sent is not either: the
    // watch app is awake for it.
    final stripped =
        last != null &&
        appLock() &&
        (last.containsKey('title') && !payload.containsKey('title') ||
            last.containsKey('threadId') && !payload.containsKey('threadId'));
    final stateChanged =
        force || last == null || last['state'] != payload['state'];
    final urgent =
        (stateChanged || stripped) &&
        !(shown != null &&
            shown.fromWatch &&
            !shown.published &&
            payload['state'] == 'working');
    shown?.published = true;
    unawaited(_deliver(payload, {...payload, 'seq': _seq}, urgent));
  }

  /// A working or waiting turn nothing has renewed is no longer believed.
  void _forgetStale() {
    final now = _now();
    _turns.removeWhere(
      (_, turn) =>
          !turn.state.finished &&
          now.difference(turn.updatedAt) > kComplicationStaleAfter,
    );
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

  Future<void> _deliver(
    Map<String, Object> shown,
    Map<String, Object> payload,
    bool urgent,
  ) async {
    var delivered = false;
    try {
      final via = await send(payload, urgent: urgent);
      delivered = via != 'none';
      if (delivered) breadcrumbs('watch.complication.sent', {'via': via});
    } on Object {
      breadcrumbs('watch.complication.failed');
    }
    // What did not arrive is sent again with the next change.
    if (!delivered && identical(_last, shown)) _last = null;
  }
}

class _Turn {
  _Turn(this.state, this.updatedAt, this.fromWatch);

  ReplyActivityState state;
  DateTime updatedAt;
  String? title;
  String? threadId;
  final bool fromWatch;

  /// Whether the watch was told about this turn already.
  bool published = false;

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
