# Auth session restoration and refresh

Run the focused checks serially before native verification:

```bash
flutter test --concurrency=1 test/session_mutex_test.dart test/auth_controller_session_recovery_test.dart test/auth_controller_bootstrap_test.dart test/token_store_test.dart test/auth_controller_refresh_test.dart test/auth_controller_sign_in_test.dart test/auth_controller_network_test.dart test/window_auth_interceptor_test.dart
```

Check these boundaries with synthetic credentials:

- Make secure storage temporarily unreadable during startup. Confirm a connection
  error preserves the stored session, then restore readability and retry. The
  verified identity must load without another sign-in. Check
  `auth.session.restore_failed` contains only the fixed reason and locked flag.
- Hold a retried request's 401, rotate the session through another request, then
  release the held response. The request may fail, but the newer session must
  survive and a subsequent request must succeed.
- Reject a retried request using the current access token. Confirm the session
  expires and the stored tokens are cleared.

Memory stores and injected failures verify controller behavior, not native
Keychain persistence. Test app relaunch and device restart only in a disposable
client environment with isolated preferences, caches, routing, and Keychain
service. Confirm stored credentials survive both, and search chats after access
expiry. Record native checks as unobserved when that isolation is unavailable.

Token-store reads must remain side-effect free, including malformed snapshots:
another engine can rotate tokens or sign out before a read returns. Secure-store
mutations use the SQLite connection lock in `session_mutex_native.dart`; the
database holds no tokens. Do not replace it with a Dart-isolate mutex or a
process-scoped POSIX file lock. Conditional refresh writes and expiry deletes
must compare the stored pair while holding this same lock.

Verify rotation overlapping startup, sign-out and replacement sign-in with
independent store connections. `session_mutex_test.dart` also checks contention
from a separate Dart isolate. This establishes native SQLite lock behavior on
the test host, not iOS Keychain/plugin behavior. On a disposable iPhone install,
verify the lock-file directory remains accessible during locked background work.

A successful refresh whose persistence fails remains pending in the foreground:
retry before another request and while idle, without another HTTP refresh; cancel
pending work on departure/disposal. Background persistence retries are bounded
and share the existing shutdown grace. Persistent keychain failures or process
termination before a successful write can still lose a rotated pair; never log
or put those tokens in the lock database to work around that limitation.
