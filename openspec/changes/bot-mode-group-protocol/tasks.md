## 1. Hosted contracts

- [x] 1.1 Start with failing fake-RPC tests for protocol 2, required methods/features, driver readiness, permissions/offline distinctions, strict identity parsing and unknown event kinds; implement typed capabilities, room/member/event/status parsing and shared RPC repository.
- [x] 1.2 Start with failing request-shape tests for list/create/send/rename/stop/disband, frozen 2–6 roster validation and text-only payloads; implement stable operation identities and parse exact receipts/tombstones.

## 2. Replay and controls

- [x] 2.1 Start with failing replay tests for multi-page logs, duplicate events, malformed identities, authority changes, old-room responses and ambiguous send acknowledgements using the server SHA-256 event-ID mapping; implement cursor advancement after incorporation and reconciliation before explicit retry.
- [x] 2.2 Start with failing approval/retry tests for exact coordinates, stale generation, once/deny and server-advertised indeterminate/deferred actions and refused retries; implement pending-action parsing and request matching without invented input RPCs.
- [ ] 2.3 Add isolated real-backend conformance tests for durable sends, reconnect replay, stop, and pending approval. Use disposable profiles and a scripted local model to force hosted clarify, sudo, and secret requests. Assert clarify remains answerable across reconnect through a room action, and sudo/secret produce attributed, non-sensitive durable failures within 10 seconds. Record the Hermes 0.21.4 reproduction: an open member clarify request left `groups.state.pending_actions` empty and the room log unchanged for more than seven seconds. Keep execution unavailable until the new contract passes; do not silently modify profile tools.
- [x] 2.4 Reuse existing opt-in method/status tracing with no content attributes; this RPC-only change needs no OpenAPI regeneration. If a REST extension becomes necessary, update OpenAPI and regenerate the client before using it.
- [ ] 2.5 After the upstream gateway advertises `hosted_interactions_v1` and `groups.respond`, add typed clarify pending actions and exact task-fenced answer/skip requests. Test stale request, generation change, Stop, duplicate answer, local-member routing, and reconnect. Reject executable group creation and send on servers without the advertised method and feature.

## 3. Verification

- [x] 3.1 Update CLAUDE.md and the recurring Bot Mode contract verification skill with hosted/legacy room distinctions and isolated-home checks. Keep `feat(bots)` near 500 changed lines; group UI belongs to the next change.
- [ ] 3.2 Run `dart format`, `flutter analyze`, `flutter test`, and isolated real-server connection/contract verification using the verify-in-app rules; verify ordinary chat still reconnects through the shared gateway. Mark hosted execution ready only after all interaction cases in 2.3 and 2.5 pass against the supported server release.
