# Tasks

One PR, `feat(surfaces): keep a snapshot for widgets and system surfaces`. About 500 changed lines with tests (model ~110, builder ~110, store ~50, updater and wiring ~90, tests ~150 beyond fixtures). If review shows it above 600, split sections 1–3 (`feat(surfaces): snapshot model, builder and store`) from section 4 (`feat(surfaces): write the snapshot from the app`) as two changes before merging. No API routes change, so no OpenAPI regeneration. No UI.

## 0. Check the backend first

- [ ] 0.1 Against `scripts/dev-backend.sh`, add a case to `test/real_backend_contract_test.dart` and run it before building on these questions:
  - Do `GET /api/sessions?order=recent` rows carry a `preview` field, and is it the first or the latest message?
  - Does `last_active` change when a reply ends?

  Record the answers in design.md. If `preview` is the latest message, use it as the snippet for chats the app has not loaded. Otherwise leave their snippet out, as designed.

## 1. Model (TDD)

- [ ] 1.1 Write failing tests in `test/surfaces/surface_snapshot_test.dart`: `toJson` matches the Contract 2 example exactly; `fromJson(toJson(s)) == s`; at most 10 recent chats, newest first; snippets cut by `replyPreview`; null Kanban and schedules; `profiles` lists the server's profile names; `signedOut()` has empty lists (`profiles` included) and null sections; malformed JSON and an unknown version read as null; the JSON never contains a token, URL other than `hermes://`, or `@`. Implement `surface_snapshot.dart`; verify.

## 2. Builder (TDD)

- [ ] 2.1 Write failing tests in `test/surfaces/surface_snapshot_builder_test.dart` with `FakeHermesServer`: recent chats merged across two profiles; Kanban counts from `blocked` and `review`; next run and last failed job from `/api/cron/jobs?profile=all`; Kanban disabled and cron missing give null sections; a failing or slow (> 5 s, fake clock) source keeps the previous section; chat hints override the open profile's rows and pending entries without a request; other profiles' pending entries are kept; `profiles` filled from `GET /api/profiles` and kept from `previous` when it fails; `redact` empties chat and thread titles, drops snippets and the job name, and keeps counts, ids and links. Implement `surface_snapshot_builder.dart`; verify.

## 3. Store

- [ ] 3.1 Add `home_widget: ^0.10.0` to `pubspec.yaml`, run `flutter pub get`, verify `flutter analyze`.
- [ ] 3.2 Write failing tests in `test/surfaces/surface_snapshot_store_test.dart` with a fake `home_widget` method channel: the App Group id is set, the JSON is saved under `hermes.surface.v1`, each kind in `kSurfaceWidgetKinds` is reloaded, an unchanged snapshot is not written again, a channel error is swallowed and still reaches listeners, `clear()` writes the signed-out form. Implement `surface_snapshot_store.dart`; verify.

## 4. Writing from the app

- [ ] 4.1 Write failing tests for `SurfaceSnapshots`: chat changes are debounced 2 s; remote sources are re-read only after 5 minutes or on pause; pause builds at once; `signedOut` clears; App Lock on passes `redact`, and turning it off writes titles again on the next build; a build requested during a build runs once after it. Implement `surface_snapshots.dart` and provide it in `lib/main.dart`; verify.
- [ ] 4.2 Write failing `ChatController` tests (with `FakeChatTransport`) that `onSurfaceChange` fires after threads load, on reply completion, failure and stop, and on a request opening and being answered, with the reply's `replyPreview`; wire it from `ChatScreen` (conversation windows pass none); verify.

## 5. Telemetry, docs and skills

- [ ] 5.1 Record the `surface.snapshot.build` span (`trigger`, `sources_failed`, `hermes.*`) and the `surface.snapshot.write_failed` log, with tests using a recording tracer and logger that no title, id or profile name is recorded; verify.
- [ ] 5.2 Add a "Surface snapshot" paragraph to CLAUDE.md (what it holds, who writes it, the privacy rules every reader must keep) and a `verify-in-app` step to read the snapshot in the iOS simulator (`xcrun simctl spawn booted defaults read group.com.cedricziel.hermesApp hermes.surface.v1`).

## 6. Verify

- [ ] 6.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all pass.
- [ ] 6.2 In the iOS simulator against `scripts/dev-backend.sh`: sign in, send a prompt, background the app, read the key and check recent chats, snippet and schedules; turn App Lock on, background again and see titles gone; sign out and see the signed-out form. Restore the Xcode files the build rewrites, staging files by name.
