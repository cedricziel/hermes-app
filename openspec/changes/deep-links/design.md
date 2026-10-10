# Design

## Context

See proposal.md for motivation and specs/deep-links/spec.md for behaviour. The URL table is Contract 1 of the iOS surfaces rollout and is not reopened here.

What exists today:

- `AppShell` (`lib/src/shell/app_shell.dart`) opens chats through `ChatOpenRequests.request(NotificationTarget)`, which `ChatScreen._onOpenRequest` turns into `ChatController.open(target, fetchMissing: true)`. That path already switches profile, fetches a chat older than the loaded pages and shows "Could not open that chat." on failure.
- Scheduled jobs open through `AppShell._openJob`, which parks the target in `_pendingJob` until `_detect()` has answered whether the cron routes exist. Kanban availability comes from the same `_detect()`.
- `AppShell` exists only while signed in (`lib/src/app.dart` picks the screen from `AuthController.state`).
- On iOS, `SceneDelegate` hands `hermes-activity` launch URLs to `LiveActivityLaunch`; the `live_activities` plugin claims only its own scheme in `scene(_:openURLContexts:)`, and `home_widget` claims only URLs with a `homeWidget` query item, so a `hermes://` URL reaches other plugins.
- `ChatController.newThread()` starts a new chat in the current profile, `onPrefill` writes the composer, and `DictationController.start()` starts the microphone.

## Goals / Non-Goals

**Goals:** one parser, one builder, one place in the shell that acts on a target; cold and warm starts behave the same; testable without a platform.

**Non-Goals:** producers of links; universal links; macOS conversation windows as targets.

## Decisions

### `app_links` (7.2.2) for receiving links

Published 2026-10-06, 1300+ likes, about 3 million downloads a month, iOS, Android and macOS (plus desktop) from one API. 7.x supports the UIScene lifecycle this app uses (`FlutterSceneDelegate`), forwards custom-scheme URLs to other plugins on macOS, gives each engine its own stream (conversation windows do not register it), and delivers every link received before the first listen. It needs Flutter ≥ 3.44, which the app's SDK constraint already implies.

Alternatives: `uni_links` is discontinued; a hand-written `SceneDelegate` hook plus a channel (as for `hermes-activity`) would be about 60 lines of Swift and Kotlin per platform and still need a macOS path. Rejected per the dependency rule.

### Pure model in `lib/src/deep_links/`

- `deep_link_target.dart`: `sealed class DeepLinkTarget` with `OpenChat(profile?, threadId, prompt?)`, `NewChat(profile?, dictate, prompt?)`, `OpenRequests()`, `OpenKanban()`, `OpenSchedules(profile?, jobId?)`.
- `deep_link_parser.dart`: `DeepLinkTarget? parseDeepLink(Uri)`. Scheme must be `hermes`; the host is the kind (`hermes://chat?...` parses with the host `chat`; a path-style `hermes:chat` is not accepted). Query values come from `Uri.queryParameters`, so percent-encoding is undone once. Empty values count as absent. `chat` without `id` is malformed. `dictate` is true only for `1` or `true`. `prompt` (on `chat` and `new`) is trimmed and cut at 4000 characters so a link cannot flood the composer. Unknown query keys are ignored, so later producers can add some without breaking older apps.
- `deep_link_uri.dart`: `Uri deepLinkUri(DeepLinkTarget)` builds the same shapes with `Uri(scheme:, host:, queryParameters:)`, leaving out null parameters. Round trip `parse(build(t)) == t` is the core test.
- `deep_link_listener.dart`: `DeepLinks` (a `ChangeNotifier` provided in `main.dart`) wraps `AppLinks().uriLinkStream`, parses, records `deeplink.ignored` for nulls, and keeps the latest target in `pending` with a `cold` flag (true for the first link when it arrived before the first frame). A fake source stream replaces `AppLinks` in tests.

`DeepLinks` lives above `HermesApp`, so a link that arrives on the setup or login screen waits there. Sign-out clears `pending`, so a link does not leak into the next session.

### `AppShell` acts on targets

`AppShell` listens to `DeepLinks` and calls `take()` in `initState` (post-frame) and on each notify. `_openDeepLink(target)`:

- `OpenChat` → `_openRequests.request(NotificationTarget(threadId, profile), prompt:)` and `_showChat()`; once the chat is open, `ChatScreen` prefills the prompt into its composer without sending. Notification inline reply (`notification-inline-reply`) uses this to hand back text it could not send.
- `NewChat` → `_openRequests.requestNew(profile:, prompt:, dictate:)`; `ChatScreen` loads the profile if it differs, calls `newThread()`, prefills, and starts dictation when the microphone is offered for that profile. When it is not, dictation is skipped silently (the composer shows no microphone either).
- `OpenRequests` → `_openRequests.requestOldestPending()`; `ChatController` picks the loaded thread whose oldest pending `InputRequest` was raised first, opens it, or shows the chat list (phone: closes any open chat; wide layout: keeps the list visible and opens nothing). A later change makes it consult the surface snapshot first.
- `OpenKanban` → `_select(_Destination.kanban)` if `_kanban`; before `_detect()` has answered, kept in a `_pendingLink` like `_pendingJob`; after it answered false, ignored with `reason: unavailable`.
- `OpenSchedules` → with a job, `_openJob(NotificationTarget.job(jobId, profile))` (which already waits for detection); without, `_select(_Destination.schedules)` under the same wait.

Pushed routes are popped first (`popUntil(isFirst)`), as `_openJob` does. App Lock is not bypassed: the gate sits above the shell, so the target is applied underneath and shown after unlock.

### Native registration

`hermes` is added as a second `CFBundleURLTypes` entry in `ios/Runner/Info.plist` and `macos/Runner/Info.plist` (role Viewer, name `$(PRODUCT_BUNDLE_IDENTIFIER).deeplink`), and an `intent-filter` (`VIEW`, `DEFAULT`, `BROWSABLE`, `scheme="hermes"`) on the main activity, which is already `singleTop`. No entitlement change. `SceneDelegate` needs no change: app_links reads `connectionOptions.urlContexts` itself.

Platforms affected: iOS, macOS, Android. Windows and Linux would need registry and desktop-file work and are left out; the parser runs there harmlessly with no source.

### Invariants touched

- Auth: none. A link before sign-in waits; it never starts sign-in or touches tokens.
- Telemetry: two breadcrumbs through `Breadcrumbs`, recorded in `DeepLinks` (`deeplink.ignored`) and `AppShell._openDeepLink` (`deeplink.opened`). Attributes are the fixed `kind`, `reason`, `cold` and `waited` values; no URL, profile, id or prompt.
- API layering and generated client: untouched.

### Dependencies

None inside the iOS surfaces set; this is wave 1. `home-screen-widgets`, `app-intents` and `notification-inline-reply` build links with `deepLinkUri`.

## Risks / Trade-offs

- [Any app can fire `hermes://new?prompt=…`] → the prompt only fills the composer; the user reviews and sends. Cut at 4000 characters.
- [Another app may claim the `hermes` scheme] → iOS picks one app per scheme without telling either. Accepted; the name matches the product, and universal links would need a domain the self-hosted server does not provide.
- [A link to another profile while a reply streams] → the existing profile switch in `ChatController.open` handles it the same as a notification tap.
- [Detection never answers (server down)] → the pending Kanban/Schedules link stays until the next `_detect()`, as `_pendingJob` does today.

## Migration Plan

New scheme only; nothing to migrate. Rollback removes the scheme entries; no stored state.
