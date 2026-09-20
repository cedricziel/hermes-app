import 'dart:async';

import 'package:flutter/widgets.dart';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import 'attention_policy.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// Tells the user about a reply or request they would otherwise miss: it
/// tracks whether the app is in front, posts what [attentionFor] asks for,
/// asks for permission once, and reports which chat a notification was
/// tapped for. Without a [service] it does nothing.
class AttentionNotifier with WidgetsBindingObserver {
  AttentionNotifier({
    required this.service,
    required this.settings,
    required this.onOpen,
  }) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _focused = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _launch = service?.launchTarget();
    _taps = service?.taps.listen(onOpen);
  }

  final NotificationService? service;
  final NotificationSettings? settings;

  /// Called with the chat of a notification the user tapped.
  final void Function(NotificationTarget target) onOpen;

  StreamSubscription<NotificationTarget>? _taps;
  Future<NotificationTarget?>? _launch;
  var _focused = true;
  var _askingPermission = false;
  Future<void>? _permissionRequest;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _focused = state == AppLifecycleState.resumed;
  }

  /// The chat of the notification whose tap started the app. Only the first
  /// call has it; later calls answer null.
  Future<NotificationTarget?> takeLaunchTarget() {
    final lookup = _launch;
    _launch = null;
    return lookup ?? Future.value();
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
  }
}
