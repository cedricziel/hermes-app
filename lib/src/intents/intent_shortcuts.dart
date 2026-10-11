import 'dart:async';

import 'package:flutter/services.dart';

import '../surfaces/surface_snapshot.dart';
import '../surfaces/surface_snapshot_store.dart';

/// The Runner's channel for App Intents (`HermesAppShortcuts.swift`).
const kIntentsChannel = 'hermes_app/intents';

/// Tells iOS to re-read the chats Siri can open by name. A refresh that fails
/// leaves Siri with the chats it already knows, so nothing is thrown.
Future<void> refreshAppShortcuts() async {
  try {
    await const MethodChannel(kIntentsChannel)
        .invokeMethod<void>('refreshShortcuts');
  } on Object {
    // The shortcuts catch up at the next write.
  }
}

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
  StreamSubscription<SurfaceSnapshot>? _writes;

  void start() {
    _writes ??= store.writes.listen((_) => unawaited(refreshAppShortcuts()));
  }

  Future<void> dispose() async {
    await _writes?.cancel();
    _writes = null;
  }
}
