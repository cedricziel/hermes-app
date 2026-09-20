import 'package:hermes_app/src/auth/token_store.dart';
import 'package:hermes_app/src/models/hermes_session.dart';

/// A [TokenStore] that keeps the session in memory instead of the keychain.
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore([this.session]);

  HermesSession? session;

  @override
  Future<HermesSession?> read() async => session;

  @override
  Future<void> write(HermesSession next) async => session = next;

  @override
  Future<void> clear() async => session = null;
}
