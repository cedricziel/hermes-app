## Why

Since #115 the app sends the selected profile as `profile` on `session.create` and `session.resume`. When that profile was deleted or renamed on the server (another client, the CLI, the Profiles screen on another device), the gateway refuses the call. Current Hermes answers with the JSON-RPC error 4064 (upstream `hermes-agent#107829`). The app treats every failed create or resume as a generic failed reply, "Something went wrong. Try sending it again.", which is wrong: sending again fails the same way until the user picks another profile.

## What Changes

- Recognise the JSON-RPC error code 4064 on `session.create` and `session.resume` and surface it as a chat-level "profile unavailable" failure.
- A reply that failed this way shows "That profile is no longer available. Pick another one." instead of the generic message. The string lives in one place, `kProfileUnavailableMessage`.
- Nothing is retried. Other failures keep the generic message.
- Add a scenario to "Reply error handling" and one to "Backend contract" in the chat spec.

## Impact

- `lib/src/chat/chat_transport.dart` (a small exception type), `lib/src/chat/gateway/hermes_gateway_transport.dart` (map the code), `lib/src/chat/chat_reply.dart` (message), `lib/src/chat/chat_screen.dart` (pass the error to the failure path).
- Specs: modifies "Reply error handling" and "Backend contract" of `chat`.
- No change to the generated API client and no new REST routes.

## Non-goals

- Bumping `HERMES_REF` in `.github/workflows/real-backend-contract.yml`. That moves the whole contract test to a newer Hermes and is a separate, riskier change. Issue #118 stays open for it.
- Detecting the deleted profile before sending, resetting the selected profile automatically, or opening the profile picker. The user picks another profile from the existing picker.
- Handling the older gateway that drops the socket instead of answering 4064. That is indistinguishable from any socket drop and keeps the generic message.
- Showing the server's error message. It names the profile and is not needed.

## Security and privacy impact

None. The app reads only the numeric error code, and the fixed message contains no profile name or server text. No token, storage or notification change.

## Telemetry

None. No new spans, log events or attributes.
