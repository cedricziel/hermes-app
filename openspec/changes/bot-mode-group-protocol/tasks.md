## 1. Hosted contracts

- [ ] 1.1 Start with failing fake-RPC tests for protocol 2, required methods/features, driver readiness, permissions/offline distinctions, strict identity parsing and unknown event kinds; implement typed capabilities, room/member/event/status parsing and shared RPC repository.
- [ ] 1.2 Start with failing request-shape tests for list/create/send/rename/stop/disband, frozen 2–6 roster validation and text-only payloads; implement stable operation identities and parse exact receipts/tombstones.

## 2. Replay and controls

- [ ] 2.1 Start with failing replay tests for multi-page logs, duplicate events, malformed identities, authority changes, old-room responses and ambiguous send acknowledgements using the server SHA-256 event-ID mapping; implement cursor advancement after incorporation and reconciliation before explicit retry.
- [ ] 2.2 Start with failing approval/retry tests for exact coordinates, stale generation, once/deny and server-advertised indeterminate/deferred actions and refused retries; implement pending-action parsing and request matching without invented input RPCs.
- [ ] 2.3 Add isolated real-backend conformance tests for durable sends, reconnect replay, stop, pending approval, and unsupported clarify/sudo/secret outcomes. If unsupported inputs can hang without an observable refusal, keep affected execution unavailable with a specific compatibility result and record the upstream contract needed; do not silently modify profile tools.
- [ ] 2.4 Reuse existing opt-in method/status tracing with no content attributes; this RPC-only change needs no OpenAPI regeneration. If a REST extension becomes necessary, update OpenAPI and regenerate the client before using it.

## 3. Verification

- [ ] 3.1 Update CLAUDE.md and the recurring Bot Mode contract verification skill with hosted/legacy room distinctions and isolated-home checks. Keep `feat(bots)` near 500 changed lines; group UI belongs to the next change.
- [ ] 3.2 Run `dart format`, `flutter analyze`, `flutter test`, and isolated real-server connection/contract verification using the verify-in-app rules; verify ordinary chat still reconnects through the shared gateway before marking connection tasks done.
