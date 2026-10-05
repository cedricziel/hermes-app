## 1. Hosted contracts

- [x] 1.1 Start with failing fake-RPC tests for protocol 2, required methods/features, driver readiness, permissions/offline distinctions, strict identity parsing and unknown event kinds; implement typed capabilities, room/member/event/status parsing and shared RPC repository.
- [x] 1.2 Start with failing request-shape tests for list/create/send/rename/stop/disband, frozen 2–6 roster validation and text-only payloads; implement stable operation identities and parse exact receipts/tombstones.

## 2. Replay and controls

- [x] 2.1 Start with failing replay tests for multi-page logs, duplicate events, malformed identities, authority changes, old-room responses and ambiguous send acknowledgements using the server SHA-256 event-ID mapping; implement cursor advancement after incorporation and reconciliation before explicit retry.
- [x] 2.2 Start with failing approval/retry tests for exact coordinates, stale generation, once/deny and server-advertised indeterminate/deferred actions and refused retries; implement pending-action parsing and request matching without invented input RPCs.
- [ ] 2.3 Add isolated real-backend conformance tests for durable sends, reconnect replay, stop, and pending approval. Use disposable profiles and a scripted local model to force a hosted clarify request. Record the Hermes 0.21.4 reproduction: an open member clarify request left `groups.state.pending_actions` empty and the room log unchanged for more than seven seconds. Verify `groups.stop` cancels the waiting task and replay remains coherent. Do not silently modify profile tools.
- [x] 2.4 Reuse existing opt-in method/status tracing with no content attributes; this RPC-only change needs no OpenAPI regeneration. If a REST extension becomes necessary, update OpenAPI and regenerate the client before using it.
- [x] 2.5 Remove the app-only interaction conformance gate. Keep create, send, and Allow once restricted to a ready protocol 2 driver with the advertised transport methods and features. Test that ordinary protocol 2 capabilities enable execution while missing methods, features, or driver readiness still disable it.

## 3. Verification

- [x] 3.1 Update CLAUDE.md and the recurring Bot Mode contract verification skill with hosted/legacy room distinctions and isolated-home checks. Keep the protocol layer separate from group UI within the combined Bot Mode PR.
- [ ] 3.2 Run `dart format`, `flutter analyze`, `flutter test`, and isolated real-server connection/contract verification using the verify-in-app rules; verify ordinary chat still reconnects through the shared gateway. Verify hosted creation, send, replay, Stop, and the visible interactive-input limitation against the supported server release.
