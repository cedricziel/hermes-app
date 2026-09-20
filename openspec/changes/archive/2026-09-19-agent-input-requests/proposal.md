## Why

While it works on a turn, the agent can stop and ask the user something. The Hermes gateway sends this as an event on the `/api/ws` socket and waits for an answer, up to a timeout. The app ignored these events and had no way to answer, so the chat looked stuck until the backend gave up.

This change was imported from the former `docs/superpowers/` directory (design and plan dated 2026-09-19; the directory is gone, git history keeps it) and is already implemented and shipped in #55 (`feat(chat): answer agent approval and clarify requests`). It is archived here to keep the design history in OpenSpec.

## What Changes

- Handle `approval.request` (allow once, for the session, always, or deny), `clarify.request` (one question with choices, multiple choices or free text, or a batch of questions), and the `approval.expire` and `clarify.expire` events.
- Show each request inline in the assistant message, next to tool calls, as an approval card or a clarify card.
- Add `answerApproval` and `answerClarify` to `ChatTransport`, sent over the gateway as `approval.respond` and `clarify.respond`.
- Mark requests that timed out, or that belong to a turn that ended or failed, as expired so a dead card cannot be answered.

## Impact

- Chat: `lib/src/chat/` (models, transport interface, reply folding, message mapper, gateway transport, chat screen) and two new cards under `lib/src/chat/widgets/`.
- Tests: `FakeChatTransport` records answers; new unit and widget tests for the reply folding, the gateway mapping, both cards and the chat screen.
- No change to the generated API client (`packages/hermes_api`).

## Non-goals

- `secret.request` and `sudo.request`. Typing a password into a chat needs its own design. These stay ignored.
- Replaying a pending request after a reconnect (`approval.pending`, `session.resume`).
- Notifications. These are a follow-up (local notifications when a reply finishes or an input request arrives).
