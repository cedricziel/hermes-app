# Tasks

One PR, `feat(app): open hermes:// links`. About 450 changed lines with tests. No API routes change, so no OpenAPI regeneration. No UI is added, so no Widgetbook use case.

## 1. Model, parser and builder (TDD)

- [ ] 1.1 Write failing tests in `test/deep_links/deep_link_parser_test.dart` for every row of the URL table, percent-encoded profile, id and prompt (spaces, `&`, emoji), empty values as absent, `chat` without `id`, `prompt` on `chat` and on `new`, unknown host, other scheme, path-style `hermes:chat`, `dictate` values, prompt cut at 4000 characters, and unknown query keys ignored; implement `deep_link_target.dart` and `deep_link_parser.dart`; verify the tests pass.
- [ ] 1.2 Write failing round-trip tests (`parseDeepLink(deepLinkUri(t)) == t` for each target, null parameters left out of the URL); implement `deep_link_uri.dart`; verify.

## 2. Receiving links

- [ ] 2.1 Add `app_links: ^7.2.2` to `pubspec.yaml`, run `flutter pub get`, verify `flutter analyze`.
- [ ] 2.2 Write failing tests for `DeepLinks` with a fake link stream: the latest target wins, `take()` empties it, a link before the first frame is `cold`, a malformed link is not kept, sign-out clears the pending target; implement `deep_link_listener.dart` and provide it in `lib/main.dart`; verify.

## 3. Shell and chat

- [ ] 3.1 Write failing `AppShell` tests (FakeHermesServer for `/api/dashboard/plugins` and `/api/cron/delivery-targets`): `chat` opens the chat through `ChatOpenRequests` with `fetchMissing` and passes its `prompt`, `kanban` and `schedules` wait for detection and then select the tab, a job link opens the job, `kanban` on a server without it is ignored, a link that arrived before sign-in is applied once the shell mounts; implement `_openDeepLink`; verify.
- [ ] 3.2 Write failing `ChatScreen`/`ChatController` tests: `new` in another profile switches profile and starts a new chat, `prompt` fills the composer and nothing is sent, a `chat` link's `prompt` fills that chat's composer once it is open and is dropped when it cannot be opened, `dictate=1` starts dictation when the microphone is offered and is skipped otherwise, `requests` opens the loaded chat with the oldest pending request and otherwise shows the chat list; add `requestNew` and `requestOldestPending` to `ChatOpenRequests` and implement; verify.

## 4. Native registration

- [ ] 4.1 Add the `hermes` scheme to `ios/Runner/Info.plist`, `macos/Runner/Info.plist` and an `intent-filter` to `android/app/src/main/AndroidManifest.xml`; verify `flutter build ios --simulator -d <udid>`, `flutter build macos` and `flutter build apk --debug` succeed, then restore the Xcode files the builds rewrite.

## 5. Telemetry, docs and skills

- [ ] 5.1 Record `deeplink.opened` (`kind`, `cold`, `waited`) and `deeplink.ignored` (`reason`) through `Breadcrumbs`, with a test using a recording trail that no URL, profile, id or prompt is added; verify.
- [ ] 5.2 Add a "Deep links" paragraph to CLAUDE.md (the scheme, the builder every producer must use) and a step to the `verify-in-app` skill for opening a link (`xcrun simctl openurl booted 'hermes://…'`, `open 'hermes://…'` on macOS).

## 6. Verify

- [ ] 6.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all pass.
- [ ] 6.2 verify-in-app on macOS against `scripts/dev-backend.sh`: `open 'hermes://chat?...'` with the app running and with it quit, `hermes://new?prompt=Hello%20there` (composer filled, nothing sent), `hermes://schedules`, and a malformed link (nothing happens). Repeat `chat` and `new&dictate=1` in the iOS simulator with `xcrun simctl openurl`. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
