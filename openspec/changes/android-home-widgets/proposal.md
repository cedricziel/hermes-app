# Proposal

## Why

iPhone and iPad users can put Recent chats, Needs you and Board on the Home Screen: the newest chats, the approvals and questions that wait for them, and the state of the Kanban board and scheduled jobs, one tap from the launcher. Android users get none of it. The app already writes the same surface snapshot on Android (the `home_widget` plugin keeps it in app-private preferences) and the quick-action menu and request notifications already work there, but no widget reads it. A person who runs Hermes for their own chores is likely to carry an Android phone, and "is anything waiting for me?" is exactly what a home screen answers.

Roadmap item 5.1. Visual design: https://claude.ai/artifact/A32jNXKc4gSovjGJidbLhB (decisions in `docs/design-briefs/android-home-widgets.md`, "Design (done)").

## What Changes

Three Android home screen widgets that read the surface snapshot and nothing else, in two sizes:

- **Recent chats**: the newest chats across profiles. Small (2x2) shows the newest chat; medium (4x3) shows three rows with title, age and a snippet. A row opens that chat in its profile.
- **Needs you**: the number of open approvals, questions and input requests. Small shows the count and the kind of the oldest; medium also lists up to three chats with a fixed kind word. A tap opens the chat of the oldest request.
- **Board**: Kanban blocked and in-review counts, the last failed scheduled job and the next run, each part only when the server offers it.

They match the iPhone widgets' words, rules and links (`hermes://` URLs from the snapshot, "Open Hermes to sign in", "Open Hermes to refresh" after six hours, redacted placeholders while App Lock is on), and add what Android needs: light and dark, wallpaper colours on Android 12 and newer, 48 dp rows that drop from the bottom as the widget shrinks or the text grows, and a picker preview that shows sample content.

Plumbing in the Dart app so the snapshot's reload reaches Android: each write reloads the Android providers by class name (today the store passes only the iOS kind, which the plugin rejects on Android, so every kind logs `widgets.reload_failed`), the installed-widgets report reads Android class names, and the snapshot is left out of Android backups.

Delivery: two PRs (see tasks.md), the first with the plumbing and Recent chats, the second Needs you and Board. The widgets are native Kotlin (Jetpack Glance, which the `home_widget` plugin already depends on); the Flutter side changes a few lines.

## Non-goals

- A large (4x4) size, a Quick launch widget (New Chat, Dictate), widget configuration, interactive widgets that call Dart (answering an approval from a widget), Lock Screen or keyguard widgets, and Wear OS tiles. Android already has the icon's long-press menu and answer buttons on request notifications.
- Live data. Widgets draw the last snapshot and never contact the server, as on iOS.
- A new Flutter dependency, or replacing `home_widget`.
- A setting to hide titles from widgets. App Lock already blanks them (see design.md, open questions).
- Changing the iPhone widgets or the snapshot's content.

## Capabilities

### New Capabilities

- `android-home-widgets`: what the Android Recent chats, Needs you and Board widgets show, their sizes, states, redaction, taps, refresh and telemetry.

### Modified Capabilities

- `surface-snapshot`: Android storage and widget reload by provider class, and the snapshot kept out of Android backups.

## Impact

- Code (Dart): `lib/src/surfaces/surface_snapshot_store.dart` (reload by platform name), `widget_kinds.dart` (the kinds that have an Android provider), `widget_usage_reporter.dart` (Android class names). Tests in `test/surfaces/`.
- Native (Android): new Kotlin widgets and pure models under `android/app/src/main/kotlin/com/cedricziel/hermes_app/widgets/`, three `<receiver>` entries and `res/xml`, `res/layout`, `res/values` (en and de strings) resources, backup rule files, the Compose compiler plugin and unit-test setup in `android/app/build.gradle.kts`. No new permission. No iOS, macOS, Windows, Linux or watchOS change.
- Dependencies: none new. `home_widget` 0.10.0 is already a direct dependency and the latest release.
- CI: a step that runs the Android JVM unit tests (`./gradlew testDebugUnitTest`).
- Backend: none. Widgets read the snapshot, which is built from routes the app already uses.
- Security and privacy: the snapshot has no token, server address or identity, and stays that way. Titles, snippets and job names are drawn on the home screen when App Lock is off, as on iOS, and are blanked while it is on. Android cannot hide a view on a locked device, so the widgets are declared `home_screen` only and never offered for the keyguard. The snapshot file is excluded from Android Auto Backup and device transfer, so chat titles never leave the device through a backup. The widgets' receivers are exported (the system requires it) but read no extra from the intent.
- Observability: `widgets.installed` now also counts Android widgets (kinds and counts, family `android`), and `widgets.reload_failed` becomes meaningful on Android because the reload now names a real class. No span, breadcrumb or new event: the widgets run in the launcher's request, outside the Flutter engine, with no telemetry of their own (as the iPhone extension), and a widget's render cannot be observed from Dart. The signals hold kinds, counts and error types only.
- Verification: no Android device or emulator ran in this PR (docs only). Visuals, taps, resizing, Doze behaviour and the picker need one; see tasks.md, "Not verified on a device".
