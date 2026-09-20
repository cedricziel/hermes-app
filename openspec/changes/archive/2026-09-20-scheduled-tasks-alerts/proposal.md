## Why

A scheduled task runs while the user is away. The point of a failing task list is lost if the user has to open the tab to find that the morning brief broke three days ago. The app already posts local notifications for chat replies; scheduled runs deserve the same, and the user asked for both failures and completions, with a way to silence the noisy jobs.

## What Changes

- While the app is in the foreground the app checks the server's jobs every minute, whatever destination is open, and once when it returns to the foreground.
- When a job has run since the app last saw it, a local notification is posted: "Finished" when it succeeded, "Failed" when it did not, "Result could not be delivered" when the run worked but delivery did not.
- Each job can be muted from its detail. A muted job posts nothing. Mutes are kept on the phone.
- Notifications settings gain a switch for scheduled task results.
- Tapping a notification opens the job's detail in Schedules.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: adds the scheduled task events, their body, the per-job mute and the setting, the tap target, and how they interact with the attention policy.

## Impact

- `lib/src/schedules/` gains a watcher over the repository, and `lib/src/notifications/` learns a second kind of target (a job) next to a chat. The notification settings gain a switch and a set of muted jobs; the job detail gains a mute toggle.
- The shell starts and stops the watcher with the app's lifecycle and the cron destination.
- Tests against `FakeHermesServer` and the fake notification service.
- No change to `openapi/`, `packages/hermes_api`, entitlements or native code. The notification permission the chat already asks for covers these.

## Non-goals

- Notifications while the app is closed or in the background. Hermes has no push channel to the app, and background fetch is unreliable enough to promise nothing. A job that ran while the app was closed is announced the next time the app is in front, but only if the app was already running (see the design).
- Showing the run's output in the notification. The lock screen shows only that the job finished or failed.
- Per-profile or per-target muting.
- A schedule of quiet hours.

## Security and privacy impact

Notification text carries the job's name and the words "Finished", "Failed" or "Result could not be delivered", never the prompt, the output or the error text. A mute is stored as the job's profile and id, in the same preferences as the other notification settings; no token or content is stored.

## Telemetry

None.
