# Design

## Context

iOS only (the Live Activity); the shared controller code also feeds the watch status, which already handles these cases. No platform, API or dependency change.

## Relation to open changes

- `live-activities` (open, unarchived) defines the states and end rules. This change adds a requirement to the same capability and modifies none of its requirements, so the two archive in either order.
- `watch-complications` (shipped in #599) fixed the same bugs for the watch status. This change reuses its decisions.

## Decisions

### Share the controller's hooks with the watch status

`ChatController._announce` already routes an event to the Live Activity, the watch status and the notifications. The folded prompt's failure now goes through it (without a notification, as before), the ahead-of-prompt completion is left out of both, and `_abandon` ends or drops a turn on both. `_announcedTurns` (formerly `_watchTurns`) is the set of threads either was told about, so closing the chat reaches a profile that is out of view.

### Abandon ends a running activity, a finished one lingers

`LiveActivities.abandon` mirrors `WatchComplicationStatus.abandon`. A "Working" nothing can finish is worse than no activity, while a finished one has its own 15-minute end already.

### A thread with a send in flight is not abandoned

Every selected remote thread is followed, so a reply sent here runs next to its follow-up listener. Leaving the profile cancels that listener, not the send, which goes on to finish the reply. `_sending` counts the sends of a thread so only turns nobody but the follow-up listener fed are abandoned. The watch status benefits too: it no longer drops and restarts for such a reply.

### The activity does not restart on a follow-up turn

The complication restarts a finished status on a new turn or request. The activity cannot: "Activity states" keeps a finished activity as it is until the next send, "Starting an activity" forbids one for a turn the user did not submit, and ActivityKit neither updates an ended activity nor starts one outside the foreground. A test records this.

## Invariants

Touches none of auth, API layering or telemetry beyond the existing crumbs.

## Risks

- A thread followed with its own send running is no longer abandoned on a profile switch for the watch either. The send keeps both fed, so the status ends with it.
