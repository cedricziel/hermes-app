# Proposal

## Why

The watch app only helps once the user opens it. A wrist glance should say whether Hermes is still working, needs the user, or has a reply, and a tap on the watch face should start a voice message. watchOS offers complications and the Smart Stack for exactly this, both drawn by a WidgetKit extension.

## What Changes

- A new watchOS WidgetKit extension, `HermesComplication`, embedded in the watch app, with two widgets:
  - Voice Chat: `accessoryCircular` and `accessoryCorner`. A tap opens the watch app on a new voice message, the same screen as the Voice Chat shortcut.
  - Chat status: `accessoryRectangular`, which is also what the Smart Stack shows. It shows the latest chat's title and one state word: Working, Waiting for you, Reply ready or Failed. A tap opens that chat.
- The phone pushes a status to the watch whenever a turn starts, waits for the user, or ends. The status holds only the state, a timestamp, the chat title and the watch's thread id for that chat. It is sent with `transferCurrentComplicationUserInfo`, falling back to `updateApplicationContext` when the day's complication budget is spent. The watch app stores it in an App Group and reloads the widget timelines.
- The status covers every turn: replies sent from the phone, and turns sent from the watch (which run on the phone).
- The Smart Stack widget raises its relevance while the turn waits for the user, and for ten minutes after a reply ends. A working or waiting status the phone has not renewed for 30 minutes is dropped, because a suspended phone app cannot say the turn ended.
- While App Lock is on, the status carries the state only: no title and no thread id.
- The App Group `group.com.cedricziel.hermesApp` is added to the watch app and the new extension. Signing for the new bundle ID (`com.cedricziel.hermesApp.watchkitapp.Complication`) is added to fastlane and the CI checks.

Non-goals:

- No message, command, question or reply text in the status. No tool names.
- No answering a request from the complication. A tap opens the chat or the voice screen.
- No status while the phone app is not running. Hermes has no push channel, so a phone that iOS suspended mid-turn cannot report the end; the watch drops a stale status instead of showing it.
- No Control Center or Action button control. The Voice Chat shortcut already covers the Action button.
- Not a replacement for the Live Activity of `watch-live-activity`, which mirrors a phone-sent reply into the Smart Stack by itself. The complication also covers watch-sent turns, and works from the watch face.

Security and privacy impact: the status is visible on a watch face, which can be glanced at while the phone is locked. It carries the chat title, as the watch's thread list already does, plus the state, a timestamp and the thread id. With App Lock on, the phone sends the state and timestamp alone. It is written to the App Group's `UserDefaults` on the watch only. No token, server address or text is sent; the thread id is the opaque id the watch already holds for the chat. Signing out on the phone clears the status.

Observability: breadcrumbs only, because the work is a local hand-over and its failures are quiet: `watch.complication.sent` with `via` (`complication`, `context`) and `watch.complication.failed`, recorded on the phone through `Breadcrumbs`. No titles, ids or text.

## Capabilities

### Modified Capabilities

- `watch`: gains the requirement "Complications and Smart Stack widget".

## Impact

- Dart: a new `lib/src/watch/watch_complication.dart` fed from `ChatController` (phone replies) and `WatchRequestHandler` (watch turns), provided in `lib/main.dart`.
- iOS native: `WatchRelay.swift` gets a `complication` call on the existing `app.hermes/watch` channel.
- watchOS: a new target `HermesComplication` (`ios/HermesComplication/`), shared `Core/ComplicationStatus.swift`, a receiver in `WCSessionTransport.swift`, a URL handler in `HermesWatchApp.swift`, an entitlements file for the watch app, project and signing changes.
- Backend: none.
