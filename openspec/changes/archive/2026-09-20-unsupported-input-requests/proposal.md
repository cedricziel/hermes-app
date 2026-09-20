## Why

The agent can ask for a secret value (an API key or similar, `secret.request`) or a sudo password (`sudo.request`) while it works on a turn. The app ignores both events, so the reply sits behind a thinking indicator until the backend gives up, and the chat looks broken. The app cannot answer these requests yet, but it can say so and say where to answer them.

## What Changes

- Handle `secret.request` and `sudo.request` by showing a card in the reply: "Hermes needs something else", saying what Hermes asked for, that this app cannot ask for it yet, and that it can be answered in the Hermes terminal or dashboard.
- Handle `secret.expire` and `sudo.expire` like the existing expire events: the card locks and reads "This request timed out". A turn that completes or breaks locks it too.
- Hide the thinking indicator while such a request is pending, as for approval and clarify requests.
- Post a local notification for these requests with the generic body "Waiting for you in Hermes", under the existing attention policy.

## Impact

- Chat: `lib/src/chat/` (request model, transport event, reply folding, gateway mapping, message builders, chat screen) and one new card under `lib/src/chat/widgets/`.
- Notifications: `lib/src/notifications/attention_policy.dart`.
- Specs: adds a requirement to `chat`, extends the "Backend contract" requirement of `chat`, and modifies "Notifiable events" and "Notification body" in `notifications`. `PRIVACY.md` says what notifications show and is updated.
- No change to the generated API client (`packages/hermes_api`) and no new REST routes.

## Non-goals

- Answering a secret or a sudo request in the app. There is no input field, no `secret.respond` or `sudo.respond` call, and no way to send a value from the app. Collecting a secret needs its own design.
- Showing the prompt text, the environment variable name or the metadata of a secret request. The card is generic.
- Replaying a pending request after a reconnect.

## Security and privacy impact

- The app never asks for, collects, stores or sends a secret or password. The card is read-only and the request model keeps only the request id and the kind, so nothing the gateway attached to the request (`prompt`, `env_var`, `metadata`) is kept in memory or shown.
- The notification body is generic on purpose, so nothing sensitive shows on a lock screen. The notification title is the chat's title, as for every notification.
- No token or secure-storage change.

## Telemetry

None. No new spans, log events or attributes.
