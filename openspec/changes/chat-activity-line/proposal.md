# Proposal

## Why

After `chat-activity-panel` Working items (status lines such as "recalled 5 memories", goal/loop/heartbeat, the plan, processes, mixture-of-agents and resume progress) are visible only inside the Activity panel, which the user has to open to learn whether Hermes is still busy. They are live and short-lived and need a glance, not a card each. This last change of four (after `chat-activity-needs-you`; design: `docs/design-briefs/chat-activity.md`) adds one line that says what Hermes is doing and opens the panel.

## What Changes

- On iOS, Android, Windows, Linux and iPad, one activity line under the chat header shows the newest Working sentence and counter chips (plan done/total, running processes, mixture-of-agents references). Tapping it opens the Activity panel. It is gone when nothing is working, and while the inspector beside the chat is open (which lists the same items).
- On macOS (main window and conversation windows) there is no line: the newest Working sentence, with a small progress indicator, joins the toolbar subtitle after profile and model. Details are in the inspector.
- The quick panel shows no Working status.
- Process output moves from This session to Now in the Activity panel, where the `chat-activity` spec already puts it; today `BoundActivityPanel` lists every process card under This session.
- Nothing is removed: the strip is deleted by `chat-activity-needs-you`, so this change only adds the line.

## Non-goals

- New activity kinds or new server calls.
- Animating the line beyond the existing progress indicator.
- Any change to tool call, reasoning or subagent rows in the transcript, or to the Bot screen card, which keeps its place in Now and does not feed the line.
- Showing Needs-you items in the line (they dock above the composer).

## Capabilities

### New Capabilities

None (adds to `chat-activity`).

### Modified Capabilities

- `chat-activity`: the working line, the Mac toolbar subtitle, process output in Now.
- `agent-session-state`: control state and transient waits feed the line or subtitle as well as the panel.
- `agent-todo-state`: the plan's summary is a counter of the line; its tasks stay in the panel.
- `agent-process-output`: process output is listed in Now.

## Impact

- New `WorkingSummary` model (newest sentence, counters) in `lib/src/chat/activity/` and `ActivityLine` widget in `lib/src/chat/activity/widgets/`.
- `ChatThreadView` draws the line below the header; `MacChatToolbar` and `ConversationWindowToolbar` gain a status part of the subtitle (`MacToolbarSubtitle`); `ChatScreen` and `ConversationWindowScreen` pass it.
- `BoundActivityPanel` lists live process cards under Now.
- Widgetbook use cases for the line and the subtitle; chat workflow screenshots change.

## Security and privacy

None new. Status text from the server is shown as untrusted plain text, as in the panel. Under App Lock the chat is covered; the line holds nothing the panel does not. The accessible name repeats only the sentence and the counters.

## Observability

- `chat.activity.opened` (from `chat-activity-panel`) gains `source: line` when the line opens the panel. No other new signal: the line does no I/O and its content comes from frames already logged by the gateway.
