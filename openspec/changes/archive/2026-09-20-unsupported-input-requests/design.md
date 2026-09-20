## Context

`secret.request` and `sudo.request` are gateway events that ask the user for a value the agent needs: a secret such as an API key, or a sudo password. The gateway waits for the answer up to a timeout. The app dropped both events, so the turn waited behind a thinking indicator with nothing to act on. The approval and clarify requests (`openspec/changes/archive/2026-09-19-agent-input-requests/`) already show how a request rides the turn's event stream; this change reuses that path and only tells the user that the app cannot answer.

Wire format, as described in the follow-up plan `2026-09-19-chat-followups.md` (from the Hermes `tui_gateway` source). That plan was never merged to main; it lives in commit 97341f4 on the `docs/chat-followups-plan` branch. It was not re-checked against a Hermes checkout or a running gateway for this change:

| Event                          | Payload                                        |
| ------------------------------ | ---------------------------------------------- |
| `secret.request`               | `request_id`, `prompt`, `env_var`, `metadata?` |
| `sudo.request`                 | `request_id`                                   |
| `secret.expire`, `sudo.expire` | `request_id`                                   |

The app reads only `request_id`. The approval and clarify events carry `request_id` in the same place, and the transport already reads it there.

## Goals / Non-Goals

**Goals:**

- Do not leave the turn behind a thinking indicator when the agent waits on a secret or a sudo password.
- Say what was asked for and where to answer it.
- Lock the card when the request expires or the turn ends.
- Notify, generically.

**Non-Goals:**

- Answering in the app, showing the prompt or the variable name, replaying after a reconnect.

## Decisions

**A new request kind, not a new mechanism.** `UnsupportedRequest` extends the sealed `InputRequest` with a `kind` of `secret` or `sudo`. `ChatMessage.inputRequests`, `awaitingInput`, expiry on completion and on a broken stream, and the mapper's one message per request already work on `InputRequest`, so the thinking indicator hides and the card locks without new code. A new `UnsupportedRequested` event carries it, and `applyReplyEvent` appends it.

**Only the kind is kept.** The transport maps both events to `UnsupportedRequest(requestId, kind)`. `prompt`, `env_var` and `metadata` are dropped at the transport, so nothing a secret request carries can reach the model, the widget tree or a notification, even by mistake. The cost is that the card cannot say which key is wanted; the terminal or dashboard says that.

**Expiry reuses `InputRequestExpired`.** `secret.expire` and `sudo.expire` map to the same event as the other two expire events, and `expireInputRequests` locks the pending request with that id.

**No answer path.** `ChatTransport` gains no method and the app sends no `secret.respond` or `sudo.respond`. Unlike approval requests, the transport does not remember a session for these requests, since nothing is ever sent for them.

**Card.** `UnsupportedRequestCard` uses `InputCardFrame` like the approval and clarify cards, with a lock icon and the title "Hermes needs something else". The body is "Hermes asked for {a secret value, such as an API key | your sudo password}. This app cannot ask for it yet. Answer it in the Hermes terminal or dashboard." Once expired it shows "This request timed out" instead.

**Notification.** The attention policy maps `UnsupportedRequested` to the body "Waiting for you in Hermes" (`kNeedsYouBody`). It does not reuse the approval or question body, because the app cannot do what those imply, and it names nothing about the request. The foreground and enabled rules are unchanged.

**Testing.** Unit: reply folding and expiry, the gateway mapping of all four events, the policy. Widget: the card in each state, the builder, the chat screen (card shown, no thinking indicator, locks on expiry). The payloads are the ones from the plan. There is no real-backend test, because getting a model to ask for a secret or a sudo password on demand is nondeterministic and costs a model call.

## Platforms and invariants

- Platforms: iOS, Android, macOS, Windows and Linux. Notifications only post on Android, iOS and macOS, as before. watchOS is not affected. No entitlement, manifest or Xcode project change.
- Invariants touched: none of the auth, API-layering or telemetry invariants. The change adds no REST call and no telemetry. It touches the rule that nothing sensitive shows on a lock screen, and keeps it with a generic body.

## Risks / Trade-offs

- The wire shapes are not covered by a real-backend contract test and were not checked against the real gateway for this change.
- The card cannot name the secret that is wanted, by design.
- A request the user cannot answer here still holds the turn until the user answers it elsewhere or it times out. The card makes that visible; it does not end it.
- Mobile platforms suspend the socket shortly after the app goes to the background, so the notification only helps in that window there.
