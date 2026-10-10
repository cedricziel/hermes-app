import 'dart:async';

import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';

/// A [SurfaceStorage] that keeps every JSON saved and counts the widget
/// reloads.
class FakeSurfaceStorage implements SurfaceStorage {
  final saved = <String>[];
  var reloads = 0;

  /// Thrown by [save] while set.
  Error? failure;

  /// Thrown by [reload] while set.
  Error? reloadFailure;

  @override
  Future<void> save(String json) async {
    if (failure case final error?) throw error;
    saved.add(json);
  }

  /// Holds back the answer of the next [load] until it completes; the answer
  /// is what was stored when it was asked.
  Completer<void>? loadGate;

  @override
  Future<String?> load() async {
    final stored = saved.lastOrNull;
    final gate = loadGate;
    loadGate = null;
    if (gate != null) await gate.future;
    return stored;
  }

  @override
  Future<void> reload(List<String> kinds) async {
    if (reloadFailure case final error?) throw error;
    reloads++;
  }
}
