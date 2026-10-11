/// The steps of a background run that keep the app icon's badge and Siri's
/// list of chats in step with the snapshot the run just stored.
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../intents/intent_shortcuts.dart';
import '../notifications/badge_controller.dart';
import '../notifications/notification_settings.dart';
import '../surfaces/surface_snapshot.dart';
import 'background_refresh.dart';

/// The snapshot [step] stored, or null when it was dropped or failed. A step
/// that cannot say within [wait] (by default what is left of the step budget)
/// fails, so the run counts it instead of reporting a skip as done.
Future<SurfaceSnapshot?> _storedBy(
  SnapshotStep step,
  BackgroundContext context,
  Duration? wait,
) => step.written.timeout(
  wait ?? context.remainingStepBudget(),
  onTimeout: () => throw TimeoutException('snapshot step did not finish'),
);

/// Sets the icon's badge to the open requests of the stored snapshot, once the
/// snapshot step has stored its own. A dropped one means someone else wrote
/// newer, which this reads as well: the badge may be stale when that writer
/// ran in another engine.
class BadgeRefreshStep extends BackgroundStep {
  BadgeRefreshStep(
    this._snapshot, {
    this.badge = const PluginBadgeService(),
    this.settings,
    TargetPlatform? platform,
    this.snapshotWait,
  }) : _platform = platform ?? defaultTargetPlatform;

  final SnapshotStep _snapshot;
  final BadgeService badge;
  final NotificationSettings? settings;
  final TargetPlatform _platform;

  /// How long to wait for the snapshot step; the rest of the step budget by
  /// default.
  final Duration? snapshotWait;

  @override
  Future<StepCounts> run(BackgroundContext context) async {
    await _storedBy(_snapshot, context, snapshotWait);
    final settings = this.settings ?? NotificationSettings();
    if (!settings.loaded) await settings.load();
    final controller = BadgeController.forPlatform(
      platform: _platform,
      store: context.hermes.snapshotStore,
      settings: settings,
      badge: badge,
    );
    try {
      await controller?.start();
    } finally {
      await controller?.dispose();
      if (this.settings == null) settings.dispose();
    }
    return const StepCounts();
  }
}

/// Asks iOS to re-read the chats Siri can open when the run changed what the
/// snapshot holds. Nothing happens on other platforms, and a refresh that
/// fails is not a failed step.
class ShortcutsRefreshStep extends BackgroundStep {
  ShortcutsRefreshStep(
    this._snapshot, {
    this.refresh = refreshAppShortcuts,
    TargetPlatform? platform,
    this.snapshotWait,
  }) : _platform = platform ?? defaultTargetPlatform;

  final SnapshotStep _snapshot;
  final Future<void> Function() refresh;
  final TargetPlatform _platform;
  final Duration? snapshotWait;

  @override
  Future<StepCounts> run(BackgroundContext context) async {
    if (_platform != TargetPlatform.iOS) return const StepCounts();
    // The store only announces a write whose content differs from the
    // stored one, so a quiet run asks nothing of Siri.
    var changed = false;
    final writes = context.hermes.snapshotStore.writes.listen(
      (_) => changed = true,
    );
    try {
      final written = await _storedBy(_snapshot, context, snapshotWait);
      if (written != null && changed) await refresh();
    } finally {
      await writes.cancel();
    }
    return const StepCounts();
  }
}
