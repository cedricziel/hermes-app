# Answering agent input requests in the chat

Date: 2026-09-19

## Problem

While it works on a turn, the agent can stop and ask the user something. The Hermes gateway sends this as an event on the `/api/ws` socket and waits for an answer, up to a timeout. The app ignores these events and has no way to answer, so the chat looks stuck until the backend gives up.

This is the first of two features. The second, local notifications for finished replies and input requests, depends on this one and gets its own spec.

## Scope

In scope:

- `approval.request`: allow once, for the session, always, or deny.
- `clarify.request`: a single question with choices, multiple choices, or free text, and a batch of several questions.
- `approval.expire` and `clarify.expire`, which end a request that timed out.

Out of scope:

- `secret.request` and `sudo.request`. Typing a password into a chat needs its own design. These stay ignored, as they are today.
- Replaying a pending request after a reconnect (`approval.pending`, `session.resume`).
- Notifications. See the follow-up spec.

## Wire format

Checked against the Hermes source (`tui_gateway/server.py`, `methods_prompt.py`).

Events, all carrying the gateway session id and a `request_id` in the payload:

| Event                               | Payload                                                                                                                   |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `approval.request`                  | `command` (redacted), `description`, `choices` (a subset of `once`, `session`, `always`, plus `deny`)                     |
| `clarify.request`                   | either `question`, `choices`, optional `multi_select`, or `questions`: a list of `{qid, question, choices, multi_select}` |
| `approval.expire`, `clarify.expire` | `request_id`                                                                                                              |

Answers, as JSON-RPC requests:

- `approval.respond {session_id, request_id, choice}`
- `clarify.respond {session_id, request_id, answer, question_id?}`

A batch clarify is answered one question at a time with `question_id`. Answers stay editable until every `qid` has one. Responding without a `question_id` cancels the whole request. A late `clarify.respond` for a request that already timed out returns `{status: "expired"}` rather than an error.

## Approach

The request is part of the turn that raised it, so it rides the existing event stream and is shown inline in the assistant message, next to tool calls.

### Events and state

New `ChatEvent` types in `chat_transport.dart`:

- `ApprovalRequested`: `requestId`, `command`, `description`, `choices`.
- `ClarifyRequested`: `requestId` and a list of `ClarifyQuestion` (`qid`, `question`, `choices`, `multiSelect`). A single-question payload becomes a one-item list, so the UI has one code path.
- `InputRequestExpired`: `requestId`.

`HermesGatewayTransport._toChatEvent` maps the four gateway events. The transport records the live gateway session id per thread, so the UI never handles it.

`ChatMessage` gets a nullable `inputRequest` with a status of `pending`, `answered` or `expired`, plus the submitted answer. `applyReplyEvent` sets and settles it. `ReplyCompleted` and `failReply` mark a still-pending request `expired`, so a card for a dead request cannot be answered.

`chatMessageToFlyer` emits one extra `CustomMessage` per request with a new `kKindInputRequest` and the id `<message id>-input`.

### Cards

Approval card:

- Shows the description and the command in a monospace block.
- One button per entry in `choices`: Allow once, Allow for session, Always allow, Deny. Deny is the quiet button. Always allow asks for a confirming tap because it is permanent.
- After a tap the card locks and shows the outcome.

Clarify card:

- Each question shows its text and either a radio group (single choice), checkboxes (`multi_select`) or a text field (no choices).
- A single question submits with one button.
- A batch locks each answer as it is made. A Confirm button stays disabled until every `qid` has an answer.
- Skip sends an empty answer, which the backend treats as a cancel.

Controls disable on the first tap, before the RPC returns, so a double tap cannot send two answers.

### Transport

`ChatTransport` gains `answerApproval(threadId, requestId, choice)` and `answerClarify(threadId, requestId, answer, {questionId})`. The gateway implementation sends the RPCs on the open client. The fake transports in tests get the same two methods.

### Errors and expiry

- A failed answer (socket error, or a JSON-RPC error such as `4009`) returns the card to `pending` with a short inline error and a retry.
- A `{status: "expired"}` answer, or an expire event, locks the card with "This request timed out".
- If the socket drops while a request is pending, the turn's stream errors, `failReply` runs and the request becomes `expired`.

## Testing

- Unit: `_toChatEvent` for each new event, including single and batch clarify payloads. `applyReplyEvent` transitions: requested, answered, expired, failed turn. Same style as `test/hermes_gateway_transport_test.dart`.
- Widget: both cards render their choices, send the right RPC, lock after a tap, keep Confirm disabled until every `qid` is answered, and return to pending on error.
- Contract: extend `test/real_backend_contract_test.dart` to check the shape of `approval.request` and `clarify.request` against the pinned Hermes. Provoking a real request costs a model call, so it sits behind `HERMES_DEV_MODEL_CALLS=1`.

## Follow-up

Local notifications: notify when a reply finishes, or when an input request arrives, while the app is not focused; tapping the notification opens the thread. Mobile platforms suspend the socket shortly after the app goes to the background, so the notification only fires in that window. Desktop is not limited.
