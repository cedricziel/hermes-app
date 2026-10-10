# Tasks

One PR, `feat(watch): add complications and a Smart Stack widget`. No API routes change.

## 1. Status in Dart

- [x] 1.1 Failing tests, then `WatchComplicationStatus`: states from events, which turn is shown, a payload without text, App Lock and unnamed chats, dedupe, clear.
- [x] 1.2 Feed it from `ChatController` (begin, events, deleted chat) and `WatchRequestHandler` (watch turns, including failures); provide it in `lib/main.dart` (iOS only) and clear it on sign-out.
- [x] 1.3 Breadcrumbs `watch.complication.sent` and `watch.complication.failed`.

## 2. Native

- [x] 2.1 `WatchRelay.swift`: the `complication` call, `transferCurrentComplicationUserInfo` with `updateApplicationContext` as the fallback.
- [x] 2.2 Core: `ComplicationStatus` (decode, store, timeline plan) with `swift test` tests.
- [x] 2.3 Watch app: receive in `WCSessionTransport`, reload timelines, `onOpenURL`, a thread launch request.
- [x] 2.4 Extension target `HermesComplication` and its widgets; entitlements, project, Release platform settings, fastlane, CI check.

## 3. Docs

- [x] 3.1 CLAUDE.md native pieces and the `watch-simulator` skill.

## 4. Verify

- [x] 4.1 `dart format`, `flutter analyze`, the touched Dart tests, `swift test`, `xcodebuild` of both watch targets, `flutter build ios --simulator`, a watch-simulator screenshot of the rectangular view (a harness shows it; the simulator cannot put a widget on a face).
- [ ] 4.2 On a paired watch (not available here): the complication updates when a reply starts, waits and ends.
