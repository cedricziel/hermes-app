# Renderings of the watch rollout features (origin/main a17b3186)

How each kind was made:

- "harness": the real SwiftUI views from `ios/HermesLiveActivity/HermesLiveActivity.swift` (`ReplyActivity`, `SmallView`, `LockScreenView`, `ElapsedTime`, copied verbatim by a script), rendered with `ImageRenderer` in a throwaway command-line binary run inside a simulator (`simctl spawn`). The backdrop (rounded card, black or grey surround) is added by the harness; the system draws the real card chrome, so treat the card edges and the light variants as approximate. The real watch Smart Stack is dark; the light variants only show the view's own colours (the default accent shows white on watchOS, so the Working icon vanishes on the light card). Timer reads 2:14.
- "simulator": the real app in a simulator, captured with `simctl io screenshot`.
- "real system UI": a real iOS 26.5 simulator, the real Runner app built from main with a throwaway entry point that builds each notification with the app's own `attentionFor` and posts it through `LocalNotificationService` (categories registered through the Runner's `NotificationCategories` channel). A temporary XCUITest accepted the permission prompt, long-pressed the banner and took the screenshots. The page behind the notification is the harness's own placeholder.

## Watch Live Activity, Smart Stack card (`SmallView`), harness on a watchOS simulator

- `watch-smartstack-working-dark.png` / `-light.png`: Working, with the elapsed timer.
- `watch-smartstack-waiting-approval-dark.png` / `-light.png`: Waiting for you (approval, orange hand).
- `watch-smartstack-done-dark.png` / `-light.png`: Done (green check).
- `watch-smartstack-failed-dark.png` / `-light.png`: Failed (red).
- `watch-smartstack-stale-open-hermes-dark.png` / `-light.png`: stale, shows "Open Hermes" instead of the state and timer.

## iPhone Lock Screen view (`LockScreenView`), for comparison, harness on an iOS simulator

- `iphone-lockscreen-working-dark.png` / `-light.png`, `iphone-lockscreen-waiting-approval-*.png`, `iphone-lockscreen-done-*.png`, `iphone-lockscreen-failed-*.png`: the same four states, label text as the app writes it ("Working", "Waiting for your approval", "Reply ready", "Reply failed").
- `iphone-lockscreen-stale-open-hermes-dark.png` / `-light.png`: stale, adds "Open Hermes for the latest".

## Watch conversation screen, real HermesWatch app in a watchOS 26.5 simulator (46 mm), demo client

- `watch-chat-quick-replies-dark.png`: quick-reply chips (Continue, Yes, No, Summarize) above the reply field. Dark only: watchOS ignores a light colour scheme in the app.
- `watch-chat-waiting-for-approval-dark.png`: "Waiting for your approval" row and the "Stop waiting" button, with the chips below. Made by a temporary patch to `DemoClient` that answers every send with `waiting: .approval`, and an automatic send on open; the patch is reverted.

## Actionable notifications on iOS, real system UI (iPhone 17 Pro, iOS 26.5 simulator, light and dark system appearance)

- `ios-notification-approval-banner-light.png` / `-dark.png`: banner for an approval; body is the command (`rsync -a --exclude=cache ~/Media /Volumes/Backup`).
- `ios-notification-approval-expanded-actions-light.png` / `-dark.png`: the same notification long-pressed: Allow once, Allow for session, Always allow, Deny (the last two are destructive, so red).
- `ios-notification-question-banner-light.png` / `-dark.png`: banner for a question with three choices.
- `ios-notification-question-expanded-actions-light.png` / `-dark.png`: expanded: "At 02:00", "At 04:30", "On the weekend" and Reply (text input).

## Not rendered

- Actionable notifications on macOS: the debug app has no notification permission on this Mac (no entry in `com.apple.ncprefs`), so a harness would have raised the system permission prompt and needed a system setting changed. Skipped as instructed.
- Handoff: no app UI of its own. It shows as the system Handoff icon on the iPhone app switcher or the Mac Dock, which needs real paired devices.
- Watch complications (PR #599): renderings exist already; not touched.
- A mirrored Live Activity on a real Smart Stack, and the watch's own mirrored notification: the simulator cannot show either.
