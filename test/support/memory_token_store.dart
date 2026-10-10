import 'package:hermes_app/src/auth/token_store.dart';
import 'package:hermes_app/src/models/hermes_session.dart';

/// A [TokenStore] that keeps the session in memory instead of the keychain.
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore([this.session, this.copyOnRead = false]);

  HermesSession? session;

  /// Makes [write] fail, like a keychain that cannot be written.
  bool failWrites = false;

  /// Makes [readState] report a keychain that cannot be read, like one that
  /// is locked before the first unlock.
  bool unreadable = false;

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
  Future<SessionRead> readState({bool repair = true}) async {
    if (unreadable) return const SessionUnreadable();
    return switch (await read()) {
      final session? => SessionFound(session),
      null => const SessionEmpty(),
    };
  }

  @override
  Future<void> write(HermesSession next) async {
    if (failWrites) throw UnsupportedError('keychain unavailable');
    session = next;
  }

  @override
  Future<void> clear() async => session = null;
}
