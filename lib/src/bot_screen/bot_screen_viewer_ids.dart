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

  /// The id added last, for the next observe to ask for: the server keeps it
  /// when the same connection minted it and mints another otherwise.
  String? get latest => _latest;

  /// Whether [hash], a lease's `viewer_hash`, names an id held here.
  bool holds(String? hash) => hash != null && _hashes.contains(hash);

  /// The hashes of every id held, for the card's "You're in control". A view
  /// of the live set, made once, since the card model reads it on each frame.
  late final Set<String> hashes = UnmodifiableSetView(_hashes);

  @override
  String toString() => 'BotScreenViewerIds(${_hashes.length})';
}
