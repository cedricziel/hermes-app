import 'dart:async';

import 'package:flutter/widgets.dart';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import '../live_activities/live_activities.dart';
import '../app_lock/app_lock_controller.dart';
import '../shell/app_presence.dart';
import 'attention_policy.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// Tells the user about a reply or request they would otherwise miss: it
/// tracks whether the app is focused (a hidden macOS app that runs without a
/// window is not, so it still posts), posts what [attentionFor] asks for,
/// asks for permission once, and reports which chat a notification or a Live
/// Activity was tapped for. Without a [service] it does nothing.
class AttentionNotifier with WidgetsBindingObserver {
  AttentionNotifier({
    required this.service,
    required this.settings,
    required this.onOpen,
    this.activities,
    this.appLock = _off,
  }) {
    _focused = AppPresence.focused(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(this);
    _launch = service?.launchTarget();
    _taps = service?.taps.listen(onOpen);
    _activityTaps = activities?.taps.listen(onOpen);
  }

  final NotificationService? service;
  final NotificationSettings? settings;
  final LiveActivities? activities;

  /// Whether App Lock is on: requests are then announced without their text
  /// or buttons.
  final bool Function() appLock;

  static bool _off() => false;

  /// Called with the chat of a notification the user tapped.
  final void Function(NotificationTarget target) onOpen;

  StreamSubscription<NotificationTarget>? _taps;
  StreamSubscription<NotificationTarget>? _activityTaps;
  Future<NotificationTarget?>? _launch;
  var _focused = true;
  var _askingPermission = false;
  Future<void>? _permissionRequest;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _focused = AppPresence.focused(state);
  }

  /// The chat of the notification or Live Activity whose tap started the
  /// app. Only the first call has it; later calls answer null.
  Future<NotificationTarget?> takeLaunchTarget() async {
    final lookup = _launch;
    _launch = null;
    return await lookup ?? await activities?.takeLaunchTarget();
  }

  /// Posts the notification [event] on [thread] deserves, if any.
  /// [selectedThreadId] is the thread on screen and [profile] the one it is
  /// listed under.
  void announce(
    ChatThread thread,
    ChatEvent event, {
    required String? selectedThreadId,
    required String? profile,
  }) {
    final service = this.service;
    if (service == null) return;
    final settings = this.settings;
    final notification = attentionFor(
      event: event,
      thread: thread,
      appFocused: _focused,
      selectedThreadId: selectedThreadId,
      enabled: settings == null || (settings.loaded && settings.enabled),
      profile: profile,
      appLock: appLock(),
    );
    if (notification == null) return;
    final pending = _permissionRequest;
    unawaited(
      pending == null
          ? service.show(notification)
          : pending.then((_) => service.show(notification)),
    );
  }

  /// Asks the system for permission once, when notifications are on and the
  /// user has not been asked. A notification posted meanwhile waits for the
  /// answer.
  Future<void> askForPermission() async {
    final service = this.service;
    final settings = this.settings;
    if (service == null || settings == null) return;
    if (!settings.loaded ||
        !settings.enabled ||
        settings.permissionAsked ||
        _askingPermission) {
      return;
    }
    _askingPermission = true;
    try {
      final request = service.requestPermission();
      _permissionRequest = request
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() => _permissionRequest = null);
      final answer = await request;
      if (answer != NotificationPermission.unavailable) {
        await settings.recordPermission(
          granted: answer == NotificationPermission.granted,
        );
      }
    } finally {
      _askingPermission = false;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taps?.cancel();
    _taps = null;
    _activityTaps?.cancel();
    _activityTaps = null;
  }
}

/// Whether [lock] keeps requests out of notifications: while App Lock is on,
/// and until its saved choice has loaded.
bool appLockHidesRequests(AppLockController? lock) =>
    lock != null && (!lock.loaded || lock.enabled);
