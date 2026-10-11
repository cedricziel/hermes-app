import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:home_widget/home_widget.dart';

import '../live_activities/live_activity_service.dart'
    show kLiveActivityAppGroup;
import 'surface_snapshot.dart';
import 'widget_kinds.dart';

export 'widget_kinds.dart';

/// The App Group the Runner and its extensions share.
const kSurfaceAppGroup = kLiveActivityAppGroup;

/// Where the snapshot's JSON lives: the shared storage the widgets read.
abstract interface class SurfaceStorage {
  Future<void> save(String json);
  Future<String?> load();

  /// Asks the system to reload the widgets of this [kind].
  Future<void> reload(String kind);
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
  Future<void> reload(String kind) async {
    await HomeWidget.updateWidget(iOSName: kind);
  }
}

/// Writes the [SurfaceSnapshot] to the shared storage and tells listeners in
/// the app about each change.
class SurfaceSnapshotStore {
  SurfaceSnapshotStore({
    SurfaceStorage? storage,
    this.events = noopAppEventLogger,
    this.widgetKinds = kSurfaceWidgetKinds,
    this.signedInOnlyKinds = kSignedInOnlyWidgetKinds,
  }) : _storage = storage ?? HomeWidgetSurfaceStorage();

  final SurfaceStorage _storage;
  final AppEventLogger events;
  final List<String> widgetKinds;
  final Set<String> signedInOnlyKinds;

  final _writes = StreamController<SurfaceSnapshot>.broadcast();
  SurfaceSnapshot? _written;

  /// The `updatedAt` of the snapshot the widgets were last reloaded for. The
  /// widgets hold that snapshot's stale entry, due six hours after it, until
  /// the next reload; null before this run reloaded any.
  DateTime? _reloadedFor;
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

  /// Stores [snapshot] and reloads the widgets. Content the last write
  /// already held is stored again only to move its time forward, so the
  /// widgets do not call it out of date after the user opened the app. That
  /// reloads them (their stale entry is due six hours after the snapshot they
  /// last loaded) at most once per `kSurfaceRefreshReloadEvery`. A storage
  /// that fails is logged and never throws.
  Future<void> write(SurfaceSnapshot snapshot) {
    final done = _tail.then((_) => _write(snapshot));
    _tail = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  Future<void> _write(SurfaceSnapshot snapshot) async {
    if (!_seeded) {
      _seeded = true;
      _written = await read();
    }
    final written = _written;
    final unchanged = written != null && written.sameContent(snapshot);
    if (unchanged && !snapshot.updatedAt.isAfter(written.updatedAt)) return;
    final signedInChanged =
        written == null || written.signedIn != snapshot.signedIn;
    final reloadedFor = _reloadedFor;
    final reload =
        !unchanged ||
        reloadedFor == null ||
        snapshot.updatedAt.difference(reloadedFor) >=
            kSurfaceRefreshReloadEvery;
    try {
      await _storage.save(snapshot.encode());
      _written = snapshot;
    } on Object catch (error) {
      if (!unchanged) _written = null;
      _log('surface.snapshot.write_failed', error);
      if (unchanged) return;
    }
    if (_written != null && reload) {
      _reloadedFor = snapshot.updatedAt;
      await Future.wait([
        for (final kind in widgetKinds)
          if (signedInChanged || !signedInOnlyKinds.contains(kind))
            _reload(kind),
      ]);
    }
    if (!unchanged && !_writes.isClosed) _writes.add(snapshot);
  }

  /// A widget that cannot be reloaded must not keep the others stale, and
  /// the snapshot is stored either way.
  Future<void> _reload(String kind) async {
    try {
      await _storage.reload(kind);
    } on Object catch (error) {
      _log('widgets.reload_failed', error, {'widget.kind': kind});
    }
  }

  void _log(String name, Object error, [Map<String, Object> extra = const {}]) {
    try {
      events(name, {...extra, 'error.type': error.runtimeType.toString()});
    } on Object {
      // Telemetry must not break the app.
    }
  }

  /// Stores the signed-out form.
  Future<void> clear({DateTime? now}) =>
      write(SurfaceSnapshot.signedOut(now ?? DateTime.now()));

  Future<void> dispose() => _writes.close();
}
