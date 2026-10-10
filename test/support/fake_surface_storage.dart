import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';

/// A [SurfaceStorage] that keeps every JSON saved and counts the widget
/// reloads.
class FakeSurfaceStorage implements SurfaceStorage {
  final saved = <String>[];
  var reloads = 0;

  /// Thrown by [save] while set.
  Error? failure;

  @override
  Future<void> save(String json) async {
    if (failure case final error?) throw error;
    saved.add(json);
  }

  @override
  Future<String?> load() async => saved.lastOrNull;

  @override
  Future<void> reload(List<String> kinds) async => reloads++;
}
