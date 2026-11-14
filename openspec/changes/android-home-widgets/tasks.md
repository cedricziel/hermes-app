# Tasks

Two PRs, each about 500 changed lines or fewer. Every behaviour task starts with a failing test. No OpenAPI change: no route is added or changed.

## 1. PR 1 — `feat(widgets): add the Android Recent chats widget`

Plumbing, the Kotlin models and one widget end to end.

- [x] 1.1 Claude Design pass: https://claude.ai/artifact/A32jNXKc4gSovjGJidbLhB; decisions in `docs/design-briefs/android-home-widgets.md`, "Design (done)".
- [ ] 1.2 Prove the build first: an empty Glance widget (receiver, `res/xml` provider info, manifest entry) with the Compose compiler plugin at the Kotlin version and `buildFeatures { compose = true }`, then `flutter build apk --debug`. If it does not build with AGP 9.5.1 and `android.builtInKotlin=false`, switch to XML `RemoteViews` and update `design.md` before going on.
- [ ] 1.3 Write failing Dart tests, then implement: `SurfaceSnapshotStore` reloads with the Android class name on Android and only the Android kinds (`kAndroidWidgetKinds`, `surfaceWidgetKindsFor`), a failing kind is still logged as `widgets.reload_failed` and the others still reload, the reload time is recorded once at least one kind succeeded; `WidgetUsageReporter` reports Android class names (`.HermesBoard` and `HermesBoard` forms) as `HermesBoard/android=N`.
- [ ] 1.4 Android unit-test setup (`testImplementation` JUnit and a real `org.json`), a CI step running `./gradlew testDebugUnitTest` in the Android job after `flutter pub get`, and the path filter in `ci.yml` so a change under `android/` runs it.
- [ ] 1.5 Write failing Kotlin tests, then implement `SurfaceSnapshot` (lenient reader), `WidgetStatus`, `RowBudget` and `RecentChatsModel`: decode `test/fixtures/surface_snapshot_v1.json` (a copy under `android/app/src/test/resources/`, kept equal by the Dart fixture test); bad JSON and unknown `version` read as signed out; a malformed row, a duplicate chat and a non-`hermes` link are skipped; stale after six hours; small shows one chat, medium three; profile only with several profiles; redacted rows when titles are empty; `RowBudget` at 110, 184 and 250 dp and at text scales 1.0, 1.3 and 2.0.
- [ ] 1.6 Build the Recent chats widget from the design canvas (`HermesRecentChats`: Glance composable, receiver, `res/xml/hermes_recent_chats_info.xml` with `widgetCategory="home_screen"`, `updatePeriodMillis="1800000"`, `previewLayout` and `previewImage` with sample content, strings in `values` and `values-de`), tap targets through `actionStartActivity<MainActivity>` with the snapshot link, the exported receiver in `AndroidManifest.xml`. There is no Widgetbook use case: a Glance widget is not a Flutter widget (see design.md, open questions).
- [ ] 1.7 Backup exclusion: `res/xml/backup_rules.xml` and `data_extraction_rules.xml` excluding `HomeWidgetPreferences.xml` and `InternalHomeWidgetPreferences.xml`, referenced from `<application>`. Verify with `./gradlew lintDebug` and the merged manifest.
- [ ] 1.8 Keep resources only XML references from shrinking (`res/raw/keep.xml`); check the release APK keeps the receiver and previews.
- [ ] 1.9 Update `docs/architecture/surfaces-and-intents.md` (Android widgets, the Android kind list rule, the reload fix) and `docs/architecture/native.md` (Android widget files and build changes), the `verify-in-app` skill (how to add the widget on an emulator with `adb` and take a screenshot), and the `surfaces` rule in `CLAUDE.md` only if its text becomes wrong.
- [ ] 1.10 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `./gradlew testDebugUnitTest`, and `flutter build apk --release`.

## 2. PR 2 — `feat(widgets): add the Android Needs you and Board widgets`

- [ ] 2.1 Write failing Kotlin tests, then implement `NeedsYouModel` (count across profiles, oldest first, one row per chat, up to three, kind words, redacted titles, small has no rows, URL of the oldest or the chat list) and `BoardModel` (parts ordered failed job, Kanban, next run; two in small, three in medium; `emptyText`; "Due" once the time has passed; the small widget's tap goes to a failed job first; redacted names), from the same fixture and a Kanban-less and a schedules-less snapshot.
- [ ] 2.2 Build `HermesNeedsYou` and `HermesBoard` from the canvas (composables, receivers, provider infos, previews, strings en and de, manifest entries, tap links), reusing the shared frame, placeholder bar and row composables from PR 1.
- [ ] 2.3 Append nothing to `kSurfaceWidgetKinds` (the names exist); add both kinds to `kAndroidWidgetKinds` with a test that the lists agree with the manifest's receiver class names (parse `AndroidManifest.xml` in the test, so a rename in one place fails).
- [ ] 2.4 Update `docs/architecture/surfaces-and-intents.md` for the two widgets.
- [ ] 2.5 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `./gradlew testDebugUnitTest`, and `flutter build apk --release`.

## 3. Archive

- [ ] 3.1 Sync the deltas into `openspec/specs/` (`android-home-widgets` new, `surface-snapshot` extended) and archive the change once the device checks below are done or moved to the roadmap.

## Not verified on a device

An emulator or phone (Pixel launcher and at least one other, Android 12 or newer and one older than 12) is needed for:

- 4.1 Adding each widget from the picker; the previews show sample content, not chats; no widget appears among lock screen widgets on a device that lists them.
- 4.2 Resizing between 2x2, 4x2 and 4x3: rows appear and drop from the bottom, nothing is under 48 dp, no clipped text.
- 4.3 Light, dark and wallpaper colours on Android 12 and newer, and the fallback palette on Android 11 or older.
- 4.4 Largest system text size and the largest display size: snippet gone, titles on two lines, no overlap.
- 4.5 Taps: a chat opens from a running app, from a cold start and while App Lock is on; signed out opens the app; the Needs you count opens the oldest request's chat.
- 4.6 Refresh: a finished reply updates the widget within seconds; the stale note and "Due" appear within about 30 minutes without the app; behaviour under Doze and a battery saver.
- 4.7 App Lock on and off: placeholder bars appear and disappear at once; TalkBack reads "Hidden" and no title.
- 4.8 Backup: after `adb shell bmgr backupnow` and a restore, a widget added before opening the app says "Open Hermes to sign in".
- 4.9 Sign-out and Change Server: widgets show "Open Hermes to sign in" at once.
