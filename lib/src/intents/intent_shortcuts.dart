import 'dart:async';

import 'package:flutter/services.dart';

import '../surfaces/surface_snapshot.dart';
import '../surfaces/surface_snapshot_store.dart';

/// The Runner's channel for App Intents (`HermesAppShortcuts.swift`).
const kIntentsChannel = 'hermes_app/intents';

/// Tells iOS to re-read the chats Siri can open by name each time the surface
/// snapshot changes, since a phrase only knows the chats iOS last asked for.
class IntentShortcuts {
  IntentShortcuts({required this.store});

  /// The instance for the app, or null where there are no App Intents or no
  /// snapshot to follow.
  static IntentShortcuts? forPlatform({
    required SurfaceSnapshotStore? store,
    required TargetPlatform platform,
  }) => store == null || platform != TargetPlatform.iOS
      ? null
      : IntentShortcuts(store: store);

  final SurfaceSnapshotStore store;
  static const _channel = MethodChannel(kIntentsChannel);
  StreamSubscription<SurfaceSnapshot>? _writes;

  void start() {
    _writes ??= store.writes.listen((_) => unawaited(_refresh()));
  }

  /// A refresh that fails leaves Siri with the chats it already knows.
  Future<void> _refresh() async {
    try {
      await _channel.invokeMethod<void>('refreshShortcuts');
    } on Object {
      // The shortcuts catch up at the next write.
    }
  }

  Future<void> dispose() async {
    await _writes?.cancel();
    _writes = null;
  }
}
