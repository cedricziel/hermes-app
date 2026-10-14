# Proposal

## Why

A reply's Live Activity is moved only by the events the chat controller announces. Four ways a turn can end never reach it, so the Lock Screen keeps saying "Working" with nothing left to finish it: a stop the server had nothing left to stop, a folded prompt whose connection breaks, a turn that was being followed when the chat's profile went out of view, and a chat closed mid-reply. The opposite also happens: the turn Hermes runs on a resume ahead of the prompt completes as "Reply ready" or "Reply failed" while the prompt itself still waits for its own turn. The watch complication (`watch-complications`) fixed the same two bugs for its status; the Live Activity has to agree with it.

## What Changes

- A stop the server had nothing left to stop ends the activity, as a stopped reply does.
- A folded prompt whose connection breaks shows "Reply failed".
- Leaving the profile of a followed turn, or closing the chat, ends an activity that is still running. A finished one lingers as usual.
- A reply sent from the app keeps its activity when its profile goes out of view, since the send still feeds it.
- The completion of the turn Hermes ran ahead of the prompt no longer finishes the prompt's activity. A request inside that turn still shows the activity waiting.

Non-goals:

- No new activity for a turn the user did not submit. A follow-up turn on a chat whose activity finished leaves it as it is, where the complication restarts: "Activity states" already freezes a finished activity until the next send, and ActivityKit cannot update an ended activity or start one from the background.
- No change to the activity's data, layout or privacy rule.

Security and privacy impact: None. No new data reaches the activity.

Observability: A running activity ended by one of these paths records the existing `live_activity.ended` crumb with outcome `stopped` (stale stop) or `abandoned` (profile switch, closed chat). No text, title or id is added.

## Capabilities

### Modified Capabilities

- `live-activities`: gains a requirement for turns that end unseen and for the turn ahead of a prompt. The capability is introduced by the open change `live-activities`, so the delta is an ADDED requirement on top of it.

## Impact

- `lib/src/chat/chat_controller.dart`, `lib/src/live_activities/live_activities.dart`.
- Backend: none.
