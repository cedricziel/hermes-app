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

/// Where a [SurfaceStorage] shared between processes keeps the snapshot time
/// the widgets were last reloaded for (an ISO 8601 time, nothing else), so a
/// background run keeps to the hourly reload rule the app keeps.
abstract interface class SurfaceReloadMarkStorage {
  Future<void> saveReloadedFor(String value);
  Future<String?> loadReloadedFor();
}

/// The key of the time the widgets were last reloaded for.
const kSurfaceReloadedForKey = 'hermes.surface.reloaded.v1';

/// [SurfaceStorage] on the `home_widget` plugin: the App Group's
/// `UserDefaults` on iOS, the plugin's preferences on Android.
class HomeWidgetSurfaceStorage
    implements SurfaceStorage, SurfaceReloadMarkStorage {
  @override
  Future<void> saveReloadedFor(String value) async {
    await HomeWidget.saveWidgetData<String>(
      kSurfaceReloadedForKey,
      value,
      appGroupId: kSurfaceAppGroup,
    );
  }

  @override
  Future<String?> loadReloadedFor() => HomeWidget.getWidgetData<String>(
    kSurfaceReloadedForKey,
    appGroupId: kSurfaceAppGroup,
  );

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

/// [SurfaceStorage] that keeps the JSON in memory, for a platform with no
/// widgets or extensions to share it with, where in-app readers still follow
/// the snapshot.
class MemorySurfaceStorage implements SurfaceStorage {
  String? _json;

  @override
  Future<void> save(String json) async => _json = json;

  @override
  Future<String?> load() async => _json;

  @override
  Future<void> reload(String kind) async {}
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
  /// the next reload; null before this store reloaded any. A storage that is
  /// a [SurfaceReloadMarkStorage] also keeps it for other stores.
  DateTime? _reloadedFor;

  /// The widget kinds whose last reload failed; only these are tried again by
  /// a refresh inside the hour. Kept in memory only.
  Set<String> _failedKinds = {};

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

  /// The stored snapshot and whether it could be read: nothing stored is
  /// readable, a failing storage or a snapshot that cannot be understood is
  /// not.
  Future<({SurfaceSnapshot? snapshot, bool readable})> _readChecked() async {
    try {
      final json = await _storage.load();
      final snapshot = SurfaceSnapshot.fromJson(json);
      return (snapshot: snapshot, readable: json == null || snapshot != null);
    } on Object {
      return (snapshot: null, readable: false);
    }
  }

  /// Stores [snapshot] as the next revision and reloads the widgets. Content
  /// the last write already held is stored again only to move its time
  /// forward, so the widgets do not call it out of date after the user opened
  /// the app. That reloads them (their stale entry is due six hours after the
  /// snapshot they last loaded) at most once per `kSurfaceRefreshReloadEvery`.
  /// A storage that fails is logged and never throws. Returns what is stored.
  Future<SurfaceSnapshot> write(SurfaceSnapshot snapshot) =>
      _queue(() async => _save(snapshot, await read()));

  /// Stores [snapshot] only if the stored snapshot is still the revision it
  /// was built from ([SurfaceSnapshot.revision]), and not a signed-out one.
  /// Someone else having written since means this build is out of date as a
  /// whole, so it is dropped (`surface.snapshot.write_skipped`, with the
  /// reason) and null returned; there is no merging. A stored snapshot that
  /// cannot be read counts as not having been seen, and is not replaced. App Lock is asked
  /// before the stored snapshot is read, so that nothing but that read and
  /// the save lies between the check and the write. A snapshot saved while
  /// App Lock is on carries no titles. [cancelled] says the run it belongs
  /// to is over.
  Future<SurfaceSnapshot?> writeIfCurrent(
    SurfaceSnapshot snapshot, {
    required Future<bool> Function() appLockOn,
    bool Function()? cancelled,
  }) => _queue(() async {
    if (cancelled?.call() ?? false) return _skipped('cancelled');
    final lockOn = await appLockOn();
    if (cancelled?.call() ?? false) return _skipped('cancelled');
    final (snapshot: stored, :readable) = await _readChecked();
    // Never save without having seen what is stored.
    if (!readable) return _skipped('unreadable');
    if (stored != null && !stored.signedIn) return _skipped('signed_out');
    if ((stored?.revision ?? 0) != snapshot.revision) {
      return _skipped('revision_changed');
    }
    return _save(lockOn ? snapshot.redacted() : snapshot, stored);
  });

  Future<T> _queue<T>(Future<T> Function() write) {
    final done = _tail.then((_) => write());
    _tail = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  SurfaceSnapshot? _skipped(String reason) {
    try {
      events('surface.snapshot.write_skipped', {'reason': reason});
    } on Object {
      // Telemetry must not break the app.
    }
    return null;
  }

  /// Saves [snapshot] as the revision after [stored]'s, the snapshot in
  /// storage a moment ago (null when there is none or it could not be read).
  Future<SurfaceSnapshot> _save(
    SurfaceSnapshot snapshot,
    SurfaceSnapshot? stored,
  ) async {
    final written = stored ?? _written;
    final next = snapshot.atRevision((written?.revision ?? 0) + 1);
    final unchanged = written != null && written.sameContent(next);
    if (unchanged && !next.updatedAt.isAfter(written.updatedAt)) return written;
    final signedInChanged =
        written == null || written.signedIn != next.signedIn;
    final reloadedFor = unchanged ? await _lastReloadedFor() : null;
    final reload =
        !unchanged ||
        reloadedFor == null ||
        // A mark from the future (a clock set back) must not hold reloads
        // back for good.
        next.updatedAt.isBefore(reloadedFor) ||
        next.updatedAt.difference(reloadedFor) >= kSurfaceRefreshReloadEvery;
    try {
      await _storage.save(next.encode());
      _written = next;
    } on Object catch (error) {
      if (!unchanged) _written = null;
      _log('surface.snapshot.write_failed', error);
      if (unchanged) return written;
    }
    if (_written != null) {
      // Past the hourly rule every kind reloads; otherwise only the kinds
      // that failed last time are tried again.
      final kinds = reload
          ? {
              for (final kind in widgetKinds)
                if (signedInChanged || !signedInOnlyKinds.contains(kind)) kind,
              // A signed-in-only kind that failed is not left out again.
              ..._failedKinds,
            }.toList()
          : _failedKinds.toList();
      if (kinds.isNotEmpty) {
        final results = await Future.wait([for (final k in kinds) _reload(k)]);
        _failedKinds = {
          ..._failedKinds.difference(kinds.toSet()),
          for (var i = 0; i < kinds.length; i++)
            if (!results[i]) kinds[i],
        };
        // The mark is left unsaved when every kind failed, so the next
        // refresh reloads them all again.
        if (reload && results.any((ok) => ok)) {
          _reloadedFor = next.updatedAt;
          await _saveReloadedFor(next.updatedAt);
        }
      }
    }
    if (!unchanged && !_writes.isClosed) _writes.add(next);
    return next;
  }

  /// The later of this store's last reload and the one stored by any store
  /// (a background run's included); null when neither is known.
  Future<DateTime?> _lastReloadedFor() async {
    final inMemory = _reloadedFor;
    DateTime? stored;
    if (_storage case final SurfaceReloadMarkStorage marks) {
      try {
        stored = DateTime.tryParse(await marks.loadReloadedFor() ?? '');
      } on Object {
        // An unreadable mark only costs a reload.
      }
    }
    if (inMemory == null || stored == null) return inMemory ?? stored;
    return stored.isAfter(inMemory) ? stored : inMemory;
  }

  Future<void> _saveReloadedFor(DateTime updatedAt) async {
    if (_storage case final SurfaceReloadMarkStorage marks) {
      try {
        await marks.saveReloadedFor(updatedAt.toUtc().toIso8601String());
      } on Object {
        // An unstored mark only costs a reload in the next process.
      }
    }
  }

  /// A widget that cannot be reloaded must not keep the others stale, and
  /// the snapshot is stored either way.
  Future<bool> _reload(String kind) async {
    try {
      await _storage.reload(kind);
      return true;
    } on Object catch (error) {
      _log('widgets.reload_failed', error, {'widget.kind': kind});
      return false;
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
  Future<SurfaceSnapshot> clear({DateTime? now}) =>
      write(SurfaceSnapshot.signedOut(now ?? DateTime.now()));

  Future<void> dispose() => _writes.close();
}
