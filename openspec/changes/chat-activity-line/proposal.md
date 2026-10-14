# Proposal

## Why

After the first three changes, only Working items (status lines such as "recalled 5 memories", goal/loop/heartbeat, the plan, processes, mixture-of-agents and resume progress) still stack as cards above the transcript. They are live and short-lived and need a glance, not a card each. This last change of four (after `chat-activity-needs-you`; design: https://claude.ai/artifact/JxjvcyRkd7YC9ajQSqvFXn) folds them into one line and removes the strip.

## What Changes

- On iOS, Android, Windows, Linux and iPad, one activity line under the chat header shows the newest Working sentence and counter chips (plan done/total, running processes, mixture-of-agents references). Tapping it opens the Activity panel. It is gone when nothing is working.
- On macOS (main window and conversation windows) there is no line: the newest Working sentence, with a small progress indicator, joins the toolbar subtitle after profile and model. Details are in the inspector.
- The quick panel shows no Working status.
- The activity strip above the transcript is removed. Every Working item's details (status lines, control state, plan tasks, process output tails, mixture-of-agents references, resume progress) live in the Activity panel's Now and Plan sections.

## Non-goals

- New activity kinds or new server calls.
- Animating the line beyond the existing progress indicator.
- Any change to tool call, reasoning or subagent rows in the transcript.

## Capabilities

### New Capabilities

None (adds to `chat-activity`).

### Modified Capabilities

- `chat-activity`: the working line, the Mac toolbar subtitle, and no activity strip above the transcript.
- `agent-session-state`: control state and transient waits show in the line or subtitle and in the panel instead of a status card.
- `agent-todo-state`: the plan's summary is a counter; its tasks are listed in the panel.
- `agent-process-output`: expanded output is bounded inside the Activity panel.

## Impact

- New `ActivityLine` widget and a `WorkingSummary` model (newest sentence, counters) in `lib/src/chat/activity/`.
- `ChatThreadView` loses the strip and its activity parameters move to the panel source; `MacChatToolbar` gains the status part of the subtitle; `ConversationWindowScreen` the same.
- Card widgets for session status, process output and mixture-of-agents become panel rows; the strip-only wrappers are deleted.
- Widgetbook use cases for the line and the subtitle; chat workflow screenshots change.

## Security and privacy

None new. Status text from the server is shown as untrusted plain text, as today. Under App Lock the chat is covered; the line holds nothing the strip did not.

## Observability

- `chat.activity.opened` (from `chat-activity-panel`) gains `source: line` when the line opens the panel. No other new signal: the line does no I/O and its content comes from frames already logged by the gateway.
