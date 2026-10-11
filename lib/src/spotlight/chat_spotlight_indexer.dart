import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_lock/app_lock_controller.dart';
import '../surfaces/chat_hints.dart' show kUnnamedChatLabel;
import '../surfaces/surface_snapshot.dart';
import '../surfaces/surface_snapshot_store.dart';
import 'spotlight_index.dart';
import 'spotlight_settings.dart';

/// The domain the chats are indexed in.
const kChatSpotlightDomain = 'chat';

// True from the first index call until a removal of everything worked, so a
// removal that failed (or never ran because the app was killed) is retried
// at the next start.
const _prefsHoldingKey = 'hermes.spotlight.dirty';

/// Keeps Spotlight in step with the recent chats of the surface snapshot
/// while the user lets it, and empties it as soon as they do not: switch
/// off, signed out, or App Lock on.
///
/// Index calls run one at a time. The state wanted is worked out again after
/// each one, so a burst of changes ends on the latest. While the device is
/// locked the index cannot be used, so nothing is called until it can again.
class ChatSpotlightIndexer {
  ChatSpotlightIndexer({
    required this.index,
    required this.settings,
    required this.store,
    this.appLock,
    this.locked,
    Stream<void>? signedOut,
    SharedPreferencesAsync? prefs,
    this.events = noopAppEventLogger,
  }) : _prefs = prefs ?? SharedPreferencesAsync() {
    settings.addListener(_changed);
    appLock?.addListener(_changed);
    _available = index.becameAvailable.listen((_) => _changed());
    _writes = store.writes.listen((snapshot) {
      _generation++;
      _latest = snapshot;
      _changed();
    });
    _signedOut = signedOut?.listen((_) {
      _generation++;
      _latest = null;
      _changed();
    });
  }

  final SpotlightIndex index;
  final SpotlightSettings settings;
  final SurfaceSnapshotStore store;
  final AppLockController? appLock;

  /// Whether App Lock is on, for an isolate that has no [appLock] controller
  /// and only looks once, such as a background run.
  final bool Function()? locked;
  final AppEventLogger events;
  final SharedPreferencesAsync _prefs;

  late final StreamSubscription<void> _available;
  late final StreamSubscription<SurfaceSnapshot> _writes;
  StreamSubscription<void>? _signedOut;

  SurfaceSnapshot? _latest;
  List<SpotlightItem>? _indexed;
  var _holding = false;

  /// The flag as last saved, so a save that failed is tried again.
  var _persisted = false;

  /// Bumped by every change of [_latest], so a stored snapshot that was read
  /// while the user signed out is not taken for the current one.
  var _generation = 0;
  var _started = false;
  var _disposed = false;
  var _running = false;
  var _again = false;
  Future<void>? _draining;

  /// Reads what the last run left behind, then starts following changes.
  Future<void> start() async {
    final generation = _generation;
    _holding = _persisted = await _prefs.getBool(_prefsHoldingKey) ?? false;
    final stored = await store.read();
    if (generation == _generation) _latest = stored;
    _started = true;
    _changed();
  }

  bool get _ready =>
      _started && settings.loaded && (appLock?.loaded ?? true) && !_disposed;

  /// The items Spotlight should hold, or null for none at all.
  List<SpotlightItem>? _wanted() {
    final snapshot = _latest;
    if (!settings.enabled ||
        (appLock?.enabled ?? locked?.call() ?? false) ||
        snapshot == null ||
        !snapshot.signedIn) {
      return null;
    }
    return [
      for (final chat in snapshot.recentChats)
        // Redacted by App Lock, or named after the prompt: nothing to show.
        if (chat.title.isNotEmpty && chat.title != kUnnamedChatLabel)
          SpotlightItem(
            domain: kChatSpotlightDomain,
            id: '${chat.profile}/${chat.id}',
            title: chat.title,
            text: chat.snippet ?? '',
            url: chat.url,
          ),
    ];
  }

  void _changed() {
    if (!_ready) return;
    if (_running) {
      _again = true;
      return;
    }
    _draining = _drain();
  }

  /// Completes when the changes seen so far are in the index.
  Future<void> settled() => _draining ?? Future.value();

  Future<void> _drain() async {
    _running = true;
    try {
      do {
        _again = false;
        await _apply();
      } while (_again && !_disposed);
    } finally {
      _running = false;
    }
  }

  Future<void> _apply() async {
    await _saveFlag();
    final wanted = _wanted();
    if (wanted == null) {
      if (!_holding || !await index.isAvailable()) return;
      _indexed = null;
      if (await index.deleteAll()) {
        _holding = false;
        await _saveFlag();
      }
      return;
    }
    final previous = _indexed;
    if (previous != null && listEquals(previous, wanted)) return;
    if (!await index.isAvailable()) return;
    _holding = true;
    await _saveFlag();
    _indexed = await _put(previous, wanted) ? wanted : null;
  }

  /// Puts [wanted] in the index: all of it when what is there is unknown,
  /// else only the items that changed, and removes the ones that left.
  Future<bool> _put(List<SpotlightItem>? previous, List<SpotlightItem> wanted) {
    if (previous == null) return index.replace(kChatSpotlightDomain, wanted);
    final before = {for (final item in previous) item.url: item};
    final urls = {for (final item in wanted) item.url};
    final changed = [
      for (final item in wanted)
        if (before[item.url] != item) item,
    ];
    final dropped = [
      for (final url in before.keys)
        if (!urls.contains(url)) url,
    ];
    if (changed.isEmpty && dropped.isEmpty) return Future.value(true);
    return index.update(kChatSpotlightDomain, upsert: changed, remove: dropped);
  }

  /// Saves [_holding] unless it is saved already. A save that fails is logged
  /// and tried again with the next change; the flag is in memory meanwhile.
  Future<void> _saveFlag() async {
    final value = _holding;
    if (_persisted == value) return;
    try {
      await _prefs.setBool(_prefsHoldingKey, value);
      _persisted = value;
    } on Object catch (error) {
      try {
        events('spotlight.index_failed', {
          'operation': 'save_flag',
          'spotlight.domain': 'all',
          'error.type': error.runtimeType.toString(),
        });
      } on Object {
        // Telemetry must not break the app.
      }
    }
  }

  void dispose() {
    _disposed = true;
    settings.removeListener(_changed);
    appLock?.removeListener(_changed);
    unawaited(_available.cancel());
    unawaited(_writes.cancel());
    unawaited(_signedOut?.cancel());
  }
}
