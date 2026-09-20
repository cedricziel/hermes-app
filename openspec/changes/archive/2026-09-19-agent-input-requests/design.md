## Context

While it works on a turn, the agent can stop and ask the user something. The Hermes gateway sends this as an event on the `/api/ws` socket and waits for an answer, up to a timeout. The app ignored these events, so the chat looked stuck until the backend gave up.

This was the first of two features. The second, local notifications for finished replies and input requests, depends on this one and has its own design.

Wire format, checked against the Hermes source (`tui_gateway/server.py`, `methods_prompt.py`):

| Event                               | Payload                                                                                                                   |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `approval.request`                  | `command` (redacted), `description`, `choices` (a subset of `once`, `session`, `always`, plus `deny`)                     |
| `clarify.request`                   | either `question`, `choices`, optional `multi_select`, or `questions`: a list of `{qid, question, choices, multi_select}` |
| `approval.expire`, `clarify.expire` | `request_id`                                                                                                              |

All events carry the gateway session id and a `request_id` in the payload. Answers are JSON-RPC requests:

- `approval.respond {session_id, request_id, choice}`
- `clarify.respond {request_id, answer, question_id?}` (no session id). A multi-select answer is a JSON array in a string.

A batch clarify is answered one question at a time with `question_id` and stays editable until every `qid` has an answer. Responding without a `question_id` cancels the whole request. A late `clarify.respond` for a request that already timed out returns `{status: "expired"}` rather than an error.

## Goals / Non-Goals

**Goals:**

- Answer `approval.request` with allow once, for the session, always, or deny.
- Answer `clarify.request`: a single question with choices, multiple choices or free text, and a batch of several questions.
- End a request on `approval.expire` and `clarify.expire`.

**Non-Goals:**

- `secret.request` and `sudo.request` (unchanged: ignored).
- Replaying a pending request after a reconnect (`approval.pending`, `session.resume`).
- Notifications (separate design).

## Decisions

**The request rides the turn's event stream and is shown inline.** The request is part of the turn that raised it, so it is shown in the assistant message, next to tool calls.

**Events and state.**

- New `ChatEvent` types in `chat_transport.dart`: `ApprovalRequested` (`requestId`, `command`, `description`, `choices`), `ClarifyRequested` (`requestId` and a list of `ClarifyQuestion` with `qid`, `question`, `choices`, `multiSelect`) and `InputRequestExpired` (`requestId`). A single-question clarify payload becomes a one-item list, so the UI has one code path. The events carry the request model itself (`ApprovalRequest`, `ClarifyRequest`, defined in `chat_models.dart`).
- `HermesGatewayTransport._toChatEvent` maps the four gateway events. The transport remembers which gateway session each approval belongs to, so the UI never handles session ids.
- `ChatMessage` gets a list `inputRequests`, because one turn can raise several approvals. Each request has a status of `pending`, `answered` or `expired`, plus the submitted answer. `applyReplyEvent` adds and expires them. `ReplyCompleted` and `failReply` mark every still-pending request `expired`, so a card for a dead request cannot be answered. While a request is pending, the thinking indicator is hidden: the agent is waiting on the user, not working.
- `chatMessageToFlyer` emits one `CustomMessage` per request with a new `kKindInputRequest` and the id `<message id>-input-<n>`.

**Approval card.** It shows the description and the command in a monospace block, with one button per entry in `choices`: Allow once, Allow for session, Always allow, Deny. Deny is the quiet button. Always allow asks for a confirming tap because it is permanent. After a tap the card locks and shows the outcome.

**Clarify card.**

- Each question shows its text and either choice chips (one selectable, or several when `multi_select` is set) or a text field (no choices).
- A single question submits with a Send button.
- A batch keeps the answers on the card. A Confirm button stays disabled until every `qid` has an answer, then sends them one `question_id` at a time. Sending on each tap would make Confirm meaningless, because the last answer already ends the request.
- Skip cancels the whole request (a response with no `question_id` and an empty answer).

Controls disable on the first tap, before the RPC returns, so a double tap cannot send two answers.

**Transport.** `ChatTransport` gains `answerApproval(requestId, choice)` and `answerClarify(requestId, values, {questionId, multiSelect})`. Both return `false` when the backend says the request is no longer pending, and throw when the call fails. Requests are keyed by `requestId` alone, because a new thread's id changes when it is bound. The gateway implementation sends the RPCs on the open client. The fake transport in tests gets the same two methods.

**Errors and expiry.**

- A failed answer (socket error, or a JSON-RPC error such as `4009`) returns the card to `pending` with a short inline error and a retry.
- A `{status: "expired"}` answer, or an expire event, locks the card with "This request timed out".
- If the socket drops while a request is pending, the turn's stream errors, `failReply` runs and the request becomes `expired`.

**Testing.**

- Unit: `_toChatEvent` for each new event, including single and batch clarify payloads; `applyReplyEvent` transitions (requested, answered, expired, failed turn), in the style of `test/hermes_gateway_transport_test.dart`.
- Widget: both cards render their choices, send the right RPC, lock after a tap, keep Confirm disabled until every `qid` is answered, and return to pending on error.
- Payload shapes: the unit tests use payloads copied from the Hermes source. There is no real-backend contract test, because getting a real model to raise an approval or a clarify question on demand is nondeterministic and each try costs a model call.

## Risks / Trade-offs

- Mobile platforms suspend the socket shortly after the app goes to the background, so a request raised then can expire before the user sees it. Notifications (the follow-up design) only fire in that window on mobile. Desktop is not limited.
- A pending request is not replayed after a reconnect, so it shows as expired if the socket drops (accepted, see Non-Goals).
- The wire shapes are copied from the Hermes source, not covered by a real-backend contract test.
