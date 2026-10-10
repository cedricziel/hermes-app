import 'package:hermes_app/src/auth/token_store.dart';
import 'package:hermes_app/src/models/hermes_session.dart';

/// A [TokenStore] that keeps the session in memory instead of the keychain.
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore([this.session, this.copyOnRead = false]);

  HermesSession? session;

  /// Makes [write] fail, like a keychain that cannot be written.
  bool failWrites = false;

  /// Makes [read] hand out a copy, like a keychain does, instead of the
  /// stored object.
  final bool copyOnRead;

  @override
  Future<HermesSession?> read() async {
    final stored = session;
    if (stored == null || !copyOnRead) return stored;
    return HermesSession.fromStorageJson(stored.toStorageJson());
  }

  @override
  Future<void> write(HermesSession next) async {
    if (failWrites) throw UnsupportedError('keychain unavailable');
    session = next;
  }

  @override
  Future<void> clear() async => session = null;
}
