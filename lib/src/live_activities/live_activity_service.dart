import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart' as plugin;

/// The App Group the Runner and the Live Activity extension share; the
/// activity's values travel through its `UserDefaults`.
const kLiveActivityAppGroup = 'group.com.cedricziel.hermesApp';

/// The scheme of the URL an activity opens when tapped.
const kLiveActivityUrlScheme = 'hermes-activity';

/// ActivityKit, as far as the app uses it. Every call swallows its own
/// failure: an activity that cannot be shown must never break a send.
abstract interface class LiveActivityService {
  Future<void> init();

  /// Whether iOS lets Hermes show Live Activities at all.
  Future<bool> allowed();

  /// Shows a new activity named [id] with [data]. Answers the id iOS gave
  /// it, which the other calls take, or null when iOS refused it.
  Future<String?> start(String id, Map<String, Object> data, Duration staleIn);

  Future<void> update(String id, Map<String, Object> data, Duration staleIn);

  /// Ends [id], leaving its last state on the Lock Screen until [dismissAt].
  Future<void> endAt(String id, DateTime dismissAt);

  Future<void> endNow(String id);

  /// Ends every running activity, including ones from an earlier launch.
  Future<void> endAll();

  /// URLs of activities the user tapped while the app ran.
  Stream<Uri> get taps;

  /// The URL of the tap that started the app, once.
  Future<Uri?> launchTap();
}

/// [LiveActivityService] on the `live_activities` plugin, for iOS.
class PluginLiveActivityService implements LiveActivityService {
  PluginLiveActivityService({plugin.LiveActivities? activities})
    : _activities = activities ?? plugin.LiveActivities();

  final plugin.LiveActivities _activities;
  static const _launch = MethodChannel('hermes_app/live_activity');

  Future<T?> _safely<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Object catch (error) {
      debugPrint('Live Activity call failed: $error');
      return null;
    }
  }

  @override
  Future<void> init() => _safely(
    () => _activities.init(
      appGroupId: kLiveActivityAppGroup,
      urlScheme: kLiveActivityUrlScheme,
      requestAndroidNotificationPermission: false,
    ),
  );

  @override
  Future<bool> allowed() async =>
      await _safely(_activities.areActivitiesEnabled) ?? false;

  @override
  Future<String?> start(
    String id,
    Map<String, Object> data,
    Duration staleIn,
  ) => _safely<String?>(
    () => _activities.createActivity(
      id,
      data,
      iOSEnableRemoteUpdates: false,
      staleIn: staleIn,
    ),
  );

  @override
  Future<void> update(String id, Map<String, Object> data, Duration staleIn) =>
      _safely(() => _activities.updateActivity(id, data, staleIn: staleIn));

  @override
  Future<void> endAt(String id, DateTime dismissAt) =>
      _safely(() => _activities.scheduleEnd(id, at: dismissAt));

  @override
  Future<void> endNow(String id) => _safely(() => _activities.endActivity(id));

  @override
  Future<void> endAll() => _safely(_activities.endAllActivities);

  @override
  Stream<Uri> get taps => _activities
      .urlSchemeStream()
      .map((data) => Uri.tryParse(data.url ?? ''))
      .where((uri) => uri != null)
      .cast<Uri>()
      .handleError((Object _) {});

  @override
  Future<Uri?> launchTap() async {
    final url = await _safely(
      () => _launch.invokeMethod<String>('takeLaunchUrl'),
    );
    return url == null ? null : Uri.tryParse(url);
  }
}
