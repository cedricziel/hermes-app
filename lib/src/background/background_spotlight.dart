/// The step of a background run that keeps Spotlight in step with the
/// snapshot the run just stored.
library;

import '../spotlight/chat_spotlight_indexer.dart';
import '../spotlight/spotlight_index.dart';
import '../spotlight/spotlight_settings.dart';
import 'background_refresh.dart';

/// Indexes the recent chats of the snapshot [_snapshot] stored, with the
/// rules of the app in front: only when the user turned Spotlight on, never
/// while App Lock is on, and not while the device is locked. The Runner's tap
/// handling is not involved: the index here only receives items.
class SpotlightRefreshStep extends BackgroundStep {
  SpotlightRefreshStep(
    this._snapshot, {
    this._index,
    this._settings,
    this.snapshotWait = const Duration(seconds: 15),
  });

  final SnapshotStep _snapshot;
  final SpotlightIndex? _index;
  final SpotlightSettings? _settings;

  /// How long to wait for the snapshot step; after that the index is left as
  /// it is.
  final Duration snapshotWait;

  @override
  Future<StepCounts> run(BackgroundContext context) async {
    final injected = _index;
    if (injected == null && !SpotlightSettings.offered) {
      return const StepCounts();
    }
    // The app in front indexes by itself, and two indexers would race.
    if (await context.isAppInFront()) return const StepCounts();
    // A dropped snapshot means someone newer wrote, and that writer indexes.
    final written = await _snapshot.written.timeout(
      snapshotWait,
      onTimeout: () => null,
    );
    if (written == null) return const StepCounts();

    final settings = _settings ?? SpotlightSettings();
    if (!settings.loaded) await settings.load();
    final lockOn = await context.appLockOn();
    final index =
        injected ??
        SpotlightIndex.forPlatform(events: context.events, indexOnly: true);
    final indexer = ChatSpotlightIndexer(
      index: index,
      settings: settings,
      store: context.hermes.snapshotStore,
      locked: () => lockOn,
      events: context.events,
    );
    try {
      await indexer.start();
      await indexer.settled();
    } finally {
      indexer.dispose();
      if (injected == null) index.dispose();
      if (_settings == null) settings.dispose();
    }
    return const StepCounts();
  }
}
