## 1. Profile through the transport

- [x] 1.1 Failing tests: the gateway transport sends `profile` on `session.create` and `session.resume`, and omits it when null
- [x] 1.2 Add `profile` to `ChatTransport.send` and send it as a param of both calls in `HermesGatewayTransport`
- [x] 1.3 Record the profile in `FakeChatTransport`

## 2. Callers

- [x] 2.1 Failing tests: the chat screen sends under the shown profile, follows a profile switch, and sends unscoped when the profile is unknown
- [x] 2.2 Pass the profile from `ChatScreen`
- [x] 2.3 Failing test and change: the watch request handler passes the active profile

## 3. Contract

- [x] 3.1 Real-backend contract case (skipped without `HERMES_DEV_URL`): a session created and resumed under the active profile is listed under it
- [x] 3.2 No API route change: `openapi/` and `packages/hermes_api` are untouched, so no client regeneration
- [x] 3.3 Telemetry: none; no skill under `.claude/skills` is made stale

## 4. Verify

- [x] 4.1 `dart format`, `flutter analyze` and `flutter test` pass
- [x] 4.2 verify-in-app not run: no Hermes on PATH here; the behaviour is covered by the transport and screen tests and the contract case
