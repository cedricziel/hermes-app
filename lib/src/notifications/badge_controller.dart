import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

import '../surfaces/surface_snapshot.dart';
import '../surfaces/surface_snapshot_store.dart';
import '../telemetry/breadcrumbs.dart';
import 'notification_settings.dart';

/// Where the number goes: the app icon's badge on iOS and Android launchers
/// that have one, the Dock tile on macOS.
abstract interface class BadgeService {
  /// Shows [count] on the icon; zero removes the badge.
  Future<void> update(int count);
}

/// [BadgeService] on `app_badge_plus`.
class PluginBadgeService implements BadgeService {
  const PluginBadgeService();

  @override
  Future<void> update(int count) => AppBadgePlus.updateBadge(count);
}

/// Keeps the app icon's badge at the number of requests waiting for the user,
/// as the latest [SurfaceSnapshot] lists them.
///
/// The badge is removed while nobody is signed in and while Hermes
/// notifications are off, and is only touched when the number changes.
class BadgeController {
  BadgeController({
    required this.badge,
    required this.store,
    required this.settings,
    Stream<void>? signedOut,
    this.breadcrumbs = Breadcrumbs.none,
    DateTime Function()? now,
  }) : _signedOutEvents = signedOut,
       _now = now ?? DateTime.now;

  /// The controller for [platform], or null where the icon has no badge or
  /// there is no snapshot to follow.
  static BadgeController? forPlatform({
    required TargetPlatform platform,
    required SurfaceSnapshotStore? store,
    required NotificationSettings settings,
    Stream<void>? signedOut,
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
    BadgeService badge = const PluginBadgeService(),
  }) {
    if (store == null ||
        (platform != TargetPlatform.iOS &&
            platform != TargetPlatform.macOS &&
            platform != TargetPlatform.android)) {
      return null;
    }
    return BadgeController(
      badge: badge,
      store: store,
      settings: settings,
      signedOut: signedOut,
      breadcrumbs: breadcrumbs,
    );
  }

  final BadgeService badge;
  final SurfaceSnapshotStore store;
  final NotificationSettings settings;
  final Breadcrumbs breadcrumbs;
  final Stream<void>? _signedOutEvents;
  final DateTime Function() _now;

  StreamSubscription<SurfaceSnapshot>? _writes;
  StreamSubscription<void>? _signedOut;
  Future<void> _applying = Future.value();
  SurfaceSnapshot? _snapshot;
  int? _shown;
  var _bucket = _bucketOf(0);

  /// Follows the snapshot, the setting and sign-out.
  Future<void> start() async {
    settings.addListener(_changed);
    _signedOut = _signedOutEvents?.listen((_) {
      _snapshot = SurfaceSnapshot.signedOut(_now());
      _changed();
    });
    var written = false;
    _writes = store.writes.listen((snapshot) {
      written = true;
      _snapshot = snapshot;
      _changed();
    });
    final stored = await store.read();
    // A write that arrived while reading is newer than what was read.
    if (stored != null && !written) _snapshot = stored;
    _changed();
  }

  void _changed() {
    _applying = _applying.then((_) => _apply());
  }

  /// The number the badge should show, or null while it is not known.
  int? get _target {
    if (!settings.loaded) return null;
    final snapshot = _snapshot;
    if (!settings.enabled || (snapshot != null && !snapshot.signedIn)) {
      return 0;
    }
    return snapshot?.pending.length;
  }

  Future<void> _apply() async {
    final count = _target;
    if (count == null || count == _shown) return;
    try {
      await badge.update(count);
    } on Object {
      // A launcher without badges is no reason to tell the user; the next
      // change tries again.
      return;
    }
    _shown = count;
    final bucket = _bucketOf(count);
    if (bucket != _bucket) {
      _bucket = bucket;
      breadcrumbs('notification.badge', {'count': bucket});
    }
  }

  static String _bucketOf(int count) => switch (count) {
    0 => '0',
    1 => '1',
    <= 5 => '2-5',
    _ => '6+',
  };

  Future<void> dispose() async {
    settings.removeListener(_changed);
    await _writes?.cancel();
    await _signedOut?.cancel();
    await _applying;
  }
}
