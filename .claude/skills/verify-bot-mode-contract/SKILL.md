---
name: verify-bot-mode-contract
description: Verify Hermes Bot Mode gateway and hosted group compatibility against an isolated real backend after a backend upgrade or Bot Mode protocol change.
---

# Verify Bot Mode contracts

Use `.claude/skills/verify-in-app/SKILL.md` for starting and stopping the throwaway backend and app. Confirm `/api/status` reports this checkout's `.dart_tool/hermes-dev/home` before any mutation. Never point Hermes or the app at the user's real Hermes home; never run `hermes dashboard --stop`. Keep the backend source revision and reported version in the verification result.

Run focused protocol tests and the existing ordinary chat reconnect tests first. Then run `test/bot_mode/group_protocol/real_groups_contract_test.dart` with `HERMES_DEV_URL` set to the isolated backend URL. The test refuses an unexpected home, creates disposable profiles, and checks durable idempotent send receipts, reconnect log replay, Stop and disband. This transport check alone does not prove interactive tool compatibility.

Hosted rooms are server-driven records returned by `groups.list`. Desktop's legacy metadata rooms have a client driver and cannot be adopted or presented as hosted rooms. Discover `groups.capabilities`: require protocol 2, all repository-required methods, `idempotent_send`, `monotonic_log`, and a ready `driver` for execution. Driver downtime preserves readable history. Local members do not need RoomLink support.

Verify interactive execution with disposable profiles and a local scripted model, using the fixture pattern in `test/real_backend_contract_test.dart`. Test a pending approval and exact once/deny coordinates. Force clarify, sudo and secret requests and inspect both durable room logs and `groups.state` until each either completes with an observable refusal or exposes a supported explicit action. Stop unfinished work and clean up the profiles. Do not change an existing profile's tools to make verification pass.

The current hosted contract only projects pending approvals and retry actions. Ordinary session clarify/sudo/secret requests have no advertised hosted input RPC or room action mapping. Keep `HermesGroupsRepository.interactionContractVerified` false unless all affected interactions pass the isolated conformance check. Record an execution incompatibility when a request can hang without a visible refusal. The upstream contract needed is a durable unsupported-input outcome or an exact hosted pending action and response method, including room, member, task and execution generation; Flutter must not invent one.

A lost send receipt is reconciled against `user:` plus SHA-256 of the UTF-8 client operation ID; the raw UUID is not the log event ID. Retry with the same operation ID only after replay establishes no accepted event. Refresh room state on malformed replay or authority change. Verify ordinary chat still reconnects using the shared authenticated gateway, and report skipped checks separately from passing checks.
