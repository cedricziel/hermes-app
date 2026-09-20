## Why

A secret or sudo request card tells the user to answer elsewhere, and offers nothing else. A Hermes gateway that sends these as server-to-client requests (since 2026-09-14) treats a client that announced the capability as able to answer, so an agent that asks for a sudo password or a secret now waits out the full deadline (two to five minutes) unless the user answers in the terminal or dashboard. A user who does not want to answer, or has no other client open, can only wait.

## What Changes

- The card for a secret or sudo request gets a "Skip" button. It tells Hermes to carry on without the value, by answering with an empty one, which the gateway defines as "skipped or declined".
- After skipping, the card reads "You skipped this request" and has no button. If the request has already ended, the card shows "This request timed out" as before.
- If the answer cannot be sent, the card says so and stays usable, like the approval card.

Non-goals: the app still never asks for, collects, stores or sends a secret or a password; the only value it ever sends is an empty one, and only when the user taps Skip. The prompt, variable name, metadata and command stay unread. No in-app entry of secrets. No change for other request kinds.

Security and privacy impact: an empty value is sent on the user's action; nothing typed is ever read. Answering with an empty value is the gateway's documented skip, not a refusal of the connection.

Telemetry: None.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: requests the app cannot answer (the Skip button and its outcomes) and the backend contract (the empty answers sent for a skip).

## Impact

`chat_transport.dart` (one new method), `hermes_gateway_transport.dart`, the unsupported-request card, `chat_builders.dart` and `chat_screen.dart`, and their tests. No native, route or generated-client change. All platforms.
