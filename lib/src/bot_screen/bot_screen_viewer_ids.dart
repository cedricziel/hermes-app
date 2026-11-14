import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The viewer ids the server minted for this app in this run, and their lease
/// hashes.
///
/// A viewer id is a capability: whoever presents it takes or releases the
/// lease. The server shows the holder only as a hash, the first 12 hex
/// characters of the id's SHA-256, so a lease names this device exactly when
/// its hash is one of these. The ids live in memory for the app's run, are
/// never stored or logged, and a printed object shows none. A lease held by an
/// id minted before the app restarted matches nothing, which is how a stranded
/// lease shows.
class BotScreenViewerIds {
  final _hashes = <String>{};
  String? _latest;

  /// The first 12 hex characters of the SHA-256 of [id], which is how the
  /// server's `viewer_hash` names a holder.
  static String hashOf(String id) =>
      sha256.convert(utf8.encode(id)).toString().substring(0, 12);

  /// Remembers [id] and makes it the latest.
  void add(String id) {
    _hashes.add(hashOf(id));
    _latest = id;
  }

  final _users = <String, int>{};

  /// Counts a live viewer as using [id], so that another viewer's [letGo] does
  /// not forget an id this one holds a stream for.
  void retain(String id) =>
      _users.update(hashOf(id), (count) => count + 1, ifAbsent: () => 1);

  /// How many live viewers use the id whose lease hash is [hash].
  int usersOf(String hash) => _users[hash] ?? 0;

  /// Ends a viewer's use of [id]. With [forget], for a release that did not get
  /// through, the id is dropped once no other viewer uses it: the lease it may
  /// still hold then names no id of this app, so it reads as someone else's and
  /// the card offers Hand back to Hermes instead of the next viewer resuming it
  /// without asking. Nothing is stored.
  void letGo(String id, {bool forget = false}) {
    final hash = hashOf(id);
    final left = (_users[hash] ?? 1) - 1;
    if (left > 0) {
      _users[hash] = left;
      return;
    }
    _users.remove(hash);
    if (!forget) return;
    _hashes.remove(hash);
    if (_latest == id) _latest = null;
    _retired.remove(hash);
  }

  /// Marks [id] as being given back by a viewer that is shutting down, so that
  /// [latest] no longer offers it: a viewer opened meanwhile would share it, and
  /// the closing viewer's release would then free the lease that viewer took.
  void retire(String id) => _retired.add(hashOf(id));

  /// Offers [id] as the latest again, once its release was answered.
  void unretire(String id) => _retired.remove(hashOf(id));

  final _retired = <String>{};

  /// The id added last, for the next observe to ask for: the server keeps it
  /// when the same connection minted it and mints another otherwise. Null when
  /// that id is being given back (see [retire]).
  String? get latest {
    final id = _latest;
    return id == null || _retired.contains(hashOf(id)) ? null : id;
  }

  /// Whether [hash], a lease's `viewer_hash`, names an id held here.
  bool holds(String? hash) => hash != null && _hashes.contains(hash);

  /// The hashes of every id held, for the card's "You're in control". A view
  /// of the live set, made once, since the card model reads it on each frame.
  late final Set<String> hashes = UnmodifiableSetView(_hashes);

  @override
  String toString() => 'BotScreenViewerIds(${_hashes.length})';
}
