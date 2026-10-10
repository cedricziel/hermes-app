import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:home_widget/home_widget.dart';

import '../live_activities/live_activity_service.dart'
    show kLiveActivityAppGroup;
import 'surface_snapshot.dart';

/// The App Group the Runner and its extensions share.
const kSurfaceAppGroup = kLiveActivityAppGroup;

/// The WidgetKit kinds that read the snapshot and are reloaded after each
/// write. The widget changes add theirs.
const kSurfaceWidgetKinds = <String>[];

/// Where the snapshot's JSON lives: the shared storage the widgets read.
abstract interface class SurfaceStorage {
  Future<void> save(String json);
  Future<String?> load();

  /// Asks the system to reload the widgets of these [kinds].
  Future<void> reload(List<String> kinds);
}

/// [SurfaceStorage] on the `home_widget` plugin: the App Group's
/// `UserDefaults` on iOS, the plugin's preferences on Android.
class HomeWidgetSurfaceStorage implements SurfaceStorage {
  @override
  Future<void> save(String json) async {
    await HomeWidget.saveWidgetData<String>(
      kSurfaceSnapshotKey,
      json,
      appGroupId: kSurfaceAppGroup,
    );
  }

  @override
  Future<String?> load() => HomeWidget.getWidgetData<String>(
    kSurfaceSnapshotKey,
    appGroupId: kSurfaceAppGroup,
  );

  @override
  Future<void> reload(List<String> kinds) async {
    for (final kind in kinds) {
      await HomeWidget.updateWidget(iOSName: kind);
    }
  }
}

/// Writes the [SurfaceSnapshot] to the shared storage and tells listeners in
/// the app about each change.
class SurfaceSnapshotStore {
  SurfaceSnapshotStore({
    SurfaceStorage? storage,
    this.events = noopAppEventLogger,
    this.widgetKinds = kSurfaceWidgetKinds,
  }) : _storage = storage ?? HomeWidgetSurfaceStorage();

  final SurfaceStorage _storage;
  final AppEventLogger events;
  final List<String> widgetKinds;

  final _writes = StreamController<SurfaceSnapshot>.broadcast();
  SurfaceSnapshot? _written;
  var _seeded = false;

  /// Writes run one after another, in the order they were asked for, so an
  /// older snapshot is never stored over a newer one.
  Future<void> _tail = Future.value();

  /// Each snapshot that changed what is stored, also when storing failed, so
  /// in-app readers stay current without the App Group.
  Stream<SurfaceSnapshot> get writes => _writes.stream;

  /// The stored snapshot, or null when there is none or it is unreadable.
  Future<SurfaceSnapshot?> read() async {
    try {
      return SurfaceSnapshot.fromJson(await _storage.load());
    } on Object {
      return null;
    }
  }

  /// Stores [snapshot] unless it says what the last one did, then reloads
  /// the widgets. A storage that fails is logged and never throws.
  Future<void> write(SurfaceSnapshot snapshot) {
    final done = _tail.then((_) => _write(snapshot));
    _tail = done;
    return done;
  }

  Future<void> _write(SurfaceSnapshot snapshot) async {
    if (!_seeded) {
      _seeded = true;
      _written = await read();
    }
    final written = _written;
    if (written != null && written.sameContent(snapshot)) return;
    try {
      await _storage.save(snapshot.encode());
      _written = snapshot;
    } on Object catch (error) {
      _written = null;
      _log('surface.snapshot.write_failed', error);
    }
    if (_written != null) {
      try {
        await _storage.reload(widgetKinds);
      } on Object catch (error) {
        _log('surface.snapshot.reload_failed', error);
      }
    }
    if (!_writes.isClosed) _writes.add(snapshot);
  }

  void _log(String name, Object error) {
    try {
      events(name, {'error.type': error.runtimeType.toString()});
    } on Object {
      // Telemetry must not break the app.
    }
  }

  /// Stores the signed-out form.
  Future<void> clear({DateTime? now}) =>
      write(SurfaceSnapshot.signedOut(now ?? DateTime.now()));

  Future<void> dispose() => _writes.close();
}
