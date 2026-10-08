import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../telemetry/breadcrumbs.dart';
import 'live_activity_service.dart';
import 'live_activity_state.dart';

export 'live_activity_service.dart';
export 'live_activity_state.dart';

/// How long a finished reply stays on the Lock Screen.
const kFinishedActivityLinger = Duration(minutes: 15);

/// Hermes has no push channel, so an activity is only current while the app
/// runs: an update made in the background marks it stale this soon after.
const kBackgroundStaleAfter = Duration(minutes: 1);

/// The stale delay while the app is in front. The plugin keeps the last stale
/// date when an update names none, so it is pushed out instead of cleared.
const kForegroundStaleAfter = Duration(hours: 8);

class _Activity {
  _Activity(this.id, this.profile, this.startedAt);

  final String id;
  final String? profile;
  final DateTime startedAt;
  ReplyActivityState state = ReplyActivityState.working;

  /// The values last sent to iOS, to skip updates that change nothing.
  Map<String, Object>? shown;
  bool? shownFocused;
}

/// Shows each reply sent from this iPhone as a Live Activity: one per chat,
/// started by the send (ActivityKit only starts one while the app is in
/// front), moved along by the reply's events, and ended when the reply
/// finishes, is stopped, or the user signs out or turns the setting off.
class LiveActivities with WidgetsBindingObserver {
  LiveActivities({
    required this.service,
    required this.settings,
    Stream<void>? signedOut,
    this.breadcrumbs = Breadcrumbs.none,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _focused = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _signedOut = signedOut?.listen((_) => _endAll('signed_out'));
    _launch = service.launchTap();
    settings.addListener(_onSettings);
  }

  final LiveActivityService service;
  final NotificationSettings settings;
  final Breadcrumbs breadcrumbs;
  final DateTime Function() _now;

  final _activities = <ChatThread, _Activity>{};
  StreamSubscription<void>? _signedOut;
  Future<Uri?>? _launch;
  var _focused = true;
  var _wasOn = true;
  var _ids = 0;

  /// ActivityKit calls run one after another, so an update never overtakes
  /// the start of its activity.
  Future<void> _queue = Future.value();

  /// Whether iOS lets Hermes show Live Activities; null until asked.
  final systemAllowed = ValueNotifier<bool?>(null);

  bool get _on => settings.loaded && settings.liveActivities;

  /// Sets ActivityKit up and ends what an earlier launch left running, which
  /// this process cannot update.
  Future<void> start() {
    _wasOn = settings.liveActivities;
    _run(() async {
      await service.init();
      await service.endAll();
      breadcrumbs('live_activity.ended', {'outcome': 'orphaned'});
    });
    unawaited(_refreshAllowed());
    return _queue;
  }

  Future<void> _refreshAllowed() async {
    systemAllowed.value = await service.allowed();
  }

  void _run(Future<void> Function() call) {
    _queue = _queue.then((_) => call()).catchError((Object _) {});
  }

  /// Shows [thread] working for a prompt just sent under [profile]. A chat
  /// keeps a running activity; a finished one is replaced, since ActivityKit
  /// cannot update an activity after it ended.
  void begin(ChatThread thread, {String? profile}) {
    if (!_on) return;
    final current = _activities[thread];
    if (current != null && !current.state.finished) return;
    if (current != null) _run(() => service.endNow(current.id));
    final activity = _Activity(
      'hermes-${_now().microsecondsSinceEpoch}-${_ids++}',
      profile,
      _now(),
    );
    _activities[thread] = activity;
    final data = _data(thread, activity);
    activity
      ..shown = data
      ..shownFocused = _focused;
    final staleIn = _staleIn;
    _run(() async {
      if (await service.start(activity.id, data, staleIn)) {
        breadcrumbs('live_activity.started');
      } else {
        if (_activities[thread] == activity) _activities.remove(thread);
        breadcrumbs('live_activity.unavailable');
      }
    });
  }

  /// Moves [thread]'s activity along for [event] of its reply.
  void onEvent(ChatThread thread, ChatEvent event) {
    final activity = _activities[thread];
    if (activity == null || activity.state.finished) return;
    final next = nextActivityState(activity.state, event);
    if (next == null) {
      _end(thread, 'stopped');
      return;
    }
    activity.state = next;
    _push(thread, activity);
    // A finished activity stays in the map so that the next send in this chat
    // replaces it.
    if (next.finished) {
      final dismissAt = _now().add(kFinishedActivityLinger);
      _run(() => service.endAt(activity.id, dismissAt));
      breadcrumbs('live_activity.ended', {
        'outcome': next == ReplyActivityState.ready ? 'completed' : 'failed',
      });
    }
  }

  /// Ends the activity of the chat [threadId] of [profile], which was deleted.
  void endChat(String threadId, String? profile) {
    final thread = _activities.keys
        .where((t) => t.id == threadId && _activities[t]!.profile == profile)
        .firstOrNull;
    if (thread != null) _end(thread, 'deleted');
  }

  void _end(ChatThread thread, String outcome) {
    final activity = _activities.remove(thread);
    if (activity == null) return;
    _run(() => service.endNow(activity.id));
    if (!activity.state.finished) {
      breadcrumbs('live_activity.ended', {'outcome': outcome});
    }
  }

  void _endAll(String outcome) {
    if (_activities.isEmpty) return;
    final running = _activities.values.any((a) => !a.state.finished);
    _activities.clear();
    _run(service.endAll);
    if (running) breadcrumbs('live_activity.ended', {'outcome': outcome});
  }

  void _onSettings() {
    final on = settings.liveActivities;
    if (_wasOn && !on) _endAll('disabled');
    _wasOn = on;
  }

  Duration get _staleIn =>
      _focused ? kForegroundStaleAfter : kBackgroundStaleAfter;

  Map<String, Object> _data(ChatThread thread, _Activity activity) => {
    'title': thread.title,
    'state': activity.state.name,
    'label': activity.state.label,
    'startedAt': activity.startedAt.millisecondsSinceEpoch.toDouble(),
    'threadId': thread.id,
    'profile': activity.profile ?? '',
  };

  /// Sends [activity]'s values to iOS unless they and the focus are what it
  /// already shows. A finished state never goes stale.
  void _push(ChatThread thread, _Activity activity) {
    final data = _data(thread, activity);
    if (mapEquals(data, activity.shown) && activity.shownFocused == _focused) {
      return;
    }
    activity
      ..shown = data
      ..shownFocused = _focused;
    final staleIn = activity.state.finished ? kForegroundStaleAfter : _staleIn;
    _run(() => service.update(activity.id, data, staleIn));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final focused = state == AppLifecycleState.resumed;
    if (focused == _focused) return;
    _focused = focused;
    if (focused) unawaited(_refreshAllowed());
    for (final MapEntry(key: thread, value: activity) in _activities.entries) {
      if (!activity.state.finished) _push(thread, activity);
    }
  }

  /// The chats of activities the user tapped while the app ran.
  Stream<NotificationTarget> get taps =>
      service.taps.map(_targetOf).where((t) => t != null).cast();

  /// The chat of the activity whose tap started the app. Only the first call
  /// has it.
  Future<NotificationTarget?> takeLaunchTarget() async {
    final launch = _launch;
    _launch = null;
    final uri = await launch;
    return uri == null ? null : _targetOf(uri);
  }

  static NotificationTarget? _targetOf(Uri uri) {
    final thread = uri.queryParameters['thread'];
    if (uri.scheme != kLiveActivityUrlScheme || thread == null) return null;
    if (thread.isEmpty) return null;
    final profile = uri.queryParameters['profile'];
    return NotificationTarget(
      threadId: thread,
      profile: profile == null || profile.isEmpty ? null : profile,
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    settings.removeListener(_onSettings);
    unawaited(_signedOut?.cancel());
    systemAllowed.dispose();
  }
}
