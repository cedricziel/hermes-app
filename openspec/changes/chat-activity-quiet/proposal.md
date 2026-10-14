# Proposal

## Why

The activity strip above a chat shows rows that report nothing: "Plan unavailable" when the agent never made a plan, "Session usage is unavailable on this server", and "Billing verification unavailable". Together with real activity they can push the conversation 250 pt down. This is the first of four changes that sort activity into three tiers (Needs you, Working, For reference; design: https://claude.ai/artifact/JxjvcyRkd7YC9ajQSqvFXn). This one sets up the tiers and stops empty or unknown states from drawing anything.

Order of the series: `chat-activity-quiet` (this), `chat-activity-panel`, `chat-activity-needs-you`, `chat-activity-line`. Each later change builds on the `chat-activity` capability this one introduces.

## What Changes

- Every kind of chat activity the app shows outside the transcript is assigned one tier: Needs you, Working or For reference.
- A plan whose state is unknown (no `todo_state` on resume, no `todo.updated` yet) draws nothing instead of "Plan unavailable".
- Session usage that the server does not support (`session.usage` method not found) draws nothing instead of an "unavailable on this server" row.
- Billing verification that the server does not support draws nothing instead of "Billing verification unavailable".
- Stale or malformed values that were known before keep their current stale/unavailable labels; only a state that never had a value is hidden.

## Non-goals

- Moving any card. The strip keeps its order and layout until `chat-activity-panel` and `chat-activity-line`.
- Hiding the idle "Billing access" row with its Verify action. Its action moves into the Activity panel in `chat-activity-panel`; until then it stays where it is.
- Any backend change.

## Capabilities

### New Capabilities

- `chat-activity`: how the chat presents agent activity outside the transcript: the three tiers, and later the activity line, panel and docked Needs-you card.

### Modified Capabilities

- `agent-todo-state`: an unknown plan state is not presented at all.
- `session-usage`: unsupported usage is not presented at all.
- `agent-billing-verification`: unsupported billing verification is not presented at all.

## Impact

- `lib/src/chat/todo_plan/todo_plan_card.dart`, `lib/src/chat/session_usage/session_usage_card.dart`, `lib/src/chat/widgets/billing_verification_card.dart`, `lib/src/chat/widgets/chat_thread_view.dart` (skip empty entries so the strip collapses).
- A small tier enum next to the chat activity state, used by the later changes.
- Widgetbook use cases of the three cards gain their empty states; `test/widgetbook_test.dart` covers them.

## Security and privacy

None. Nothing new is stored, sent or logged.

## Observability

None. The change only stops drawing empty rows; the existing card events (details opened, billing outcomes) are unchanged and still fire when there is something to show.
