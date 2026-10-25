# Auth session restoration and refresh

Run the focused checks serially before native verification:

```bash
flutter test --concurrency=1 test/auth_controller_session_recovery_test.dart test/auth_controller_bootstrap_test.dart test/token_store_test.dart test/auth_controller_refresh_test.dart test/auth_controller_sign_in_test.dart test/auth_controller_network_test.dart test/window_auth_interceptor_test.dart
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
