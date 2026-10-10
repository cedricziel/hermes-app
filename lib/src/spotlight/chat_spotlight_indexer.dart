import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_lock/app_lock_controller.dart';
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
/// each one, so a burst of changes ends on the latest.
class ChatSpotlightIndexer {
  ChatSpotlightIndexer({
    required this.index,
    required this.settings,
    required this.store,
    this.appLock,
    Stream<void>? signedOut,
    SharedPreferencesAsync? prefs,
  }) : _prefs = prefs ?? SharedPreferencesAsync() {
    settings.addListener(_changed);
    appLock?.addListener(_changed);
    _writes = store.writes.listen((snapshot) {
      _latest = snapshot;
      _changed();
    });
    _signedOut = signedOut?.listen((_) {
      _latest = null;
      _changed();
    });
  }

  final SpotlightIndex index;
  final SpotlightSettings settings;
  final SurfaceSnapshotStore store;
  final AppLockController? appLock;
  final SharedPreferencesAsync _prefs;

  late final StreamSubscription<SurfaceSnapshot> _writes;
  StreamSubscription<void>? _signedOut;

  SurfaceSnapshot? _latest;
  List<SpotlightItem>? _indexed;
  var _holding = false;
  var _started = false;
  var _disposed = false;
  var _running = false;
  var _again = false;

  /// Reads what the last run left behind, then starts following changes.
  Future<void> start() async {
    _holding = await _prefs.getBool(_prefsHoldingKey) ?? false;
    _latest ??= await store.read();
    _started = true;
    _changed();
  }

  bool get _ready =>
      _started && settings.loaded && (appLock?.loaded ?? true) && !_disposed;

  /// The items Spotlight should hold, or null for none at all.
  List<SpotlightItem>? _wanted() {
    final snapshot = _latest;
    if (!settings.enabled ||
        (appLock?.enabled ?? false) ||
        snapshot == null ||
        !snapshot.signedIn) {
      return null;
    }
    return [
      for (final chat in snapshot.recentChats)
        if (chat.title.isNotEmpty)
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
    unawaited(_drain());
  }

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
    final wanted = _wanted();
    if (wanted == null) {
      if (!_holding) return;
      _indexed = null;
      if (await index.deleteAll()) await _setHolding(false);
      return;
    }
    if (_indexed != null && listEquals(_indexed, wanted)) return;
    await _setHolding(true);
    _indexed = await index.replace(kChatSpotlightDomain, wanted)
        ? wanted
        : null;
  }

  Future<void> _setHolding(bool value) async {
    if (_holding == value) return;
    _holding = value;
    try {
      await _prefs.setBool(_prefsHoldingKey, value);
    } on Object {
      // The flag only speeds up a retry; the next change tries again anyway.
    }
  }

  void dispose() {
    _disposed = true;
    settings.removeListener(_changed);
    appLock?.removeListener(_changed);
    unawaited(_writes.cancel());
    unawaited(_signedOut?.cancel());
  }
}
