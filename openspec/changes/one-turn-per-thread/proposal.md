## Why

The chat lets the user send a second prompt on a thread while the first reply is still streaming. Both turns then run on one gateway session and both listen to the same runtime session, so both see every event. A request raised later can land in both replies as duplicate cards, and one turn ending can clear the other's bookkeeping.

## What Changes

- Sending on a thread that has a pending reply is refused, and the chat says why: "Hermes is still replying. Wait for it to finish, or answer its request."
- A reply that waits for an approval or clarify answer counts as pending, because the user answers the card instead of sending.
- The composer keeps its text and attachments when a send is refused.
- Other threads are not affected. Sending works again once the reply completes or its stream breaks.
- The "Overlapping sends" scenario of the "Sending a message" requirement now applies to several threads only.

## Impact

- Chat: `_send` in `lib/src/chat/chat_screen.dart`.
- Tests: new `test/chat_one_turn_test.dart`. Existing tests that sent twice on one thread while the first reply was pending now complete the first reply first.
- No change to the generated API client (`packages/hermes_api`) and no new backend route or RPC method.

## Non-goals

- Queueing the second prompt to send it when the reply ends.
- Cancelling or interrupting a running reply from the composer.
- Disabling the send button while a reply is pending. The composer stays editable so the user can prepare the next prompt.
- Serialising turns in the transport or gateway layer.
- Requests the app cannot answer yet (`secret.request`, `sudo.request`).

## Security and privacy impact

None. No token, storage or network behaviour changes, and the refused text stays in the composer on the device.

## Telemetry

None. No span, log event or attribute is added.
