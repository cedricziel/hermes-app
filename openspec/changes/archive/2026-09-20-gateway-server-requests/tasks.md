## 1. RPC client

- [x] 1.1 Test first: a frame with a string id and a method is reported as a server request, `respond` and `respondError` write response frames, and events and integer-id responses still work
- [x] 1.2 Report server-to-client requests from `GatewayRpcClient`, and add `respond` and `respondError`

## 2. Transport

- [x] 2.1 Test first: the capability is announced once per connection before the session call, and an error from it is ignored
- [x] 2.2 Test first: `approval`, `clarify`, `secret` and `sudo` requests become the same events as their event forms, keyed by the frame id, and requests of other sessions are left alone
- [x] 2.3 Test first: any other method is answered with -32601, `request.cancel` expires the card, and the event forms still work
- [x] 2.4 Test first: answering an approval, a single clarify question and one question of a batch uses a response frame or `clarify.lock` as designed, and a secret or sudo request is never answered
- [x] 2.5 Implement the announcement, the request handling, the answers and `request.cancel` in `HermesGatewayTransport`

## 3. Wrap up

- [x] 3.1 Telemetry: none, nothing to add
- [x] 3.2 No `.claude/skills` entry is made stale by this
- [x] 3.3 Sync the delta into `openspec/specs/chat/spec.md` and archive the change
- [x] 3.4 Verify: dart format, flutter analyze, flutter test, `openspec validate --strict`; the new form is not checked against a running gateway (see design.md), and no verify-in-app run was made
