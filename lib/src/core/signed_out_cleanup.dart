import 'dart:async';

/// Runs [clean] each time the session ends, until disposed. A cleanup that
/// fails is not retried: whatever it left is only ever data of the account
/// that signed out, which another account ignores.
class SignedOutCleanup {
  SignedOutCleanup(Stream<void> signedOut, Future<void> Function() clean)
    : _subscription = signedOut.listen((_) => unawaited(_run(clean)));

  final StreamSubscription<void> _subscription;

  static Future<void> _run(Future<void> Function() clean) async {
    try {
      await clean();
    } on Object {
      // Nothing to do about it here.
    }
  }

  Future<void> dispose() => _subscription.cancel();
}
