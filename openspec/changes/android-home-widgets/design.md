# Design

## Context

The surface snapshot (`lib/src/surfaces/`, spec `surface-snapshot`) is one JSON string under `hermes.surface.v1`, written by `SurfaceSnapshotStore` through the `home_widget` plugin. On iOS it lives in the App Group's `UserDefaults` and the three Home Screen widgets, built in `ios/HermesLiveActivity` over the pure models in `ios/HermesSurfaceKit/.../WidgetModels.swift`, read it (spec `home-screen-widgets`). On Android the same plugin keeps it in the `HomeWidgetPreferences` `SharedPreferences` file (`appGroupId` is ignored there), private to the app. Nothing on Android reads it yet.

What is in `android/` today: a single `MainActivity` (`singleTop`, `taskAffinity=""`, a `hermes` VIEW intent filter delivered by `app_links`), the notification plugin's `ActionBroadcastReceiver` (request actions, `android-request-actions`), quick-action icons kept by `res/raw/keep.xml`, Kotlin 2.4.21, AGP 9.5.1 with `android.builtInKotlin=false`, no `res/xml`, no `allowBackup` or backup rules (the default is on), no Compose, no unit tests.

Two facts found while reading the code:

- `HomeWidgetSurfaceStorage.reload` calls `HomeWidget.updateWidget(iOSName: kind)`. On Android the plugin resolves a provider class from `qualifiedAndroidName`, `androidName` or `name`, finds none and answers error `-3`. So on Android every write logs `widgets.reload_failed` for all six kinds, and because every kind failed the reload time is never recorded.
- `WidgetUsageReporter` filters on `iOSKind`, which is null on Android, so the installed-widgets event would count nothing.

## Goals / Non-Goals

**Goals:** widgets that render the snapshot as faithfully as the iPhone ones, never show a title the app would blank, match Android conventions (resizing, 48 dp targets, dark theme, wallpaper colours), cost no new Flutter dependency, and keep their logic testable without a device.

**Non-Goals:** see proposal.md. Chiefly: no large size, no Quick launch widget, no interactivity, no keyguard.

## Decisions

### Plugin: keep `home_widget`, write the widgets as Glance Kotlin

The Dependencies rule asks for a mature plugin before hand-written platform code. The question has two halves.

_Storage, reload, installed-widget report, launch intent._ `home_widget` already does all four and is already the snapshot's storage on iOS and Android. Judged as the rule says:

| Criterion                | `home_widget` 0.10.0                                                                                                               |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| Releases                 | Six from 12 April to 17 September 2026 (0.9.1 to 0.10.0); 0.10.0 is the latest                  |
| Publisher                | `antonborri.es`, verified                                                                                                          |
| Platforms                | Android and iOS (what we need)                                                                                                     |
| Popularity               | 2,222 likes, 160 of 160 pub points, about 356,000 downloads in 30 days                                                             |
| Open issues              | 32 issues and 14 pull requests on GitHub, active                                                                                   |
| Android surface it gives | `saveWidgetData`/`getWidgetData`, `updateWidget`, `getInstalledWidgets`, `HomeWidgetLaunchIntent`, Glance state, scheduled updates |

Other results of a pub.dev search for "home screen widget" are much smaller: `glance_widget` 54 and `flutter_homescreen_widget` 51 downloads in 30 days, `native_home_widgets` 15, `home_widget_generator` (a code generator for this plugin) 1,103. `flutter_widgetkit` is iOS only. None is a reason to replace the plugin.

_The widget views._ No Flutter plugin can draw them: an Android widget is `RemoteViews` rendered in the launcher's process, so Kotlin is needed whatever we pick. The plugin's own Android surface is helpers (`HomeWidgetProvider`, `HomeWidgetGlanceStateDefinition`, `actionStartActivity`) and it declares `api "androidx.glance:glance-appwidget:1.2.0"`, so Glance is already in the APK and nothing new is added.

Fit with the existing iOS mechanism: the snapshot key, the string payload, the `SurfaceStorage` seam, the hourly reload rule and `SurfaceReloadMarkStorage` all stay; only the reload call gains an Android name. `outdated` check: 0.10.0 is the latest release (published 17 September 2026), the constraint `^0.10.0` already allows it, and no dependency changes, so the pre-commit hook has nothing new to fail on. `home_widget` requires Flutter 3.38.1 and Dart 3.10; `.fvmrc` pins 3.47.9.

Rejected: a hand-written `AppWidgetProvider` plus our own `MethodChannel` for save, load and update. It replaces storage the iOS widgets and the snapshot store already use and gains nothing. Rejected: classic XML `RemoteViews` with a `RemoteViewsService` list. It needs no Compose compiler plugin but three adapters of boilerplate per widget, and dark theme, dynamic colour and responsive rows are all hand work. Glance gives them from one composable per widget.

### Glance, exact sizes, one provider per kind

Each kind is a `GlanceAppWidget` with `stateDefinition = HomeWidgetGlanceStateDefinition()` (the plugin's `SharedPreferences` view) and `SizeMode.Exact`, and a receiver subclass of `HomeWidgetGlanceWidgetReceiver`. `SizeMode.Exact` re-composes at the real size, so the view asks the model for what fits instead of picking one of two fixed layouts. The class names are the iOS kinds (`HermesRecentChats`, `HermesNeedsYou`, `HermesBoard`) in package `com.cedricziel.hermes_app`, so `HomeWidget.updateWidget(androidName: kind)` resolves them and the Dart kind list needs no second naming scheme.

Build changes in `android/app/build.gradle.kts`: the `org.jetbrains.kotlin.plugin.compose` plugin at the project's Kotlin version (2.4.21) and `buildFeatures { compose = true }`, `testImplementation` for JUnit and a real `org.json` for JVM tests. Whether Compose compiler 2.4.21 and AGP 9.5.1 with `builtInKotlin=false` build together is the first task to try; see risks.

### Pure models in Kotlin, a shared fixture

As on iOS (`WidgetModels.swift`), the decisions live in pure Kotlin with no Android imports beyond `org.json`: `SurfaceSnapshot` (lenient reader: bad JSON or unknown `version` is "signed out", a malformed row is skipped, a row without a `hermes://` link is skipped, a chat listed twice shows once, counts and flags must be of their own JSON type, an unknown request kind reads as `input`), `WidgetStatus` (signed out, stale after six hours), `RecentChatsModel`, `NeedsYouModel`, `BoardModel`, and a `RowBudget` that turns a height and a text scale into a row count. The Glance views only draw them. The tests decode the Dart-written fixture `test/fixtures/surface_snapshot_v1.json`, kept equal to a copy under `android/app/src/test/resources/`, the way the Swift package keeps its copy; the existing Dart fixture test is extended to check the copy. Ages use `DateUtils.getRelativeTimeSpanString` in the view (framework, localised); the models carry instants.

### Sizes, rows and targets

Two size classes by width: small below 250 dp (2x2 is about 110 to 160 dp), medium from 250 dp (4 cells). The provider's default sizes are 2x2 (Needs you, Board) and 4x3 (Recent chats, medium rows need 8 + 24 + 3 x 48 + 8 = 184 dp, about three cells); `minResizeWidth/Height` 110 dp, `resizeMode` horizontal and vertical. Rows: `RowBudget` returns `floor((height - 40 dp) / row)` where `row` is `max(48 dp, content height at the current text scale)`, clamped to 1 and the family's cap (1, 3 or 3). So a 4x2 widget (about 110 dp) shows one row with its snippet, a 4x3 three. This is why Android's medium is 4x3 where iOS's is 4x2: three 48 dp rows do not fit in two cells. Over a text scale of 1.3 the snippet goes first, then rows from the bottom; titles wrap to two lines. The design canvas covers 200%.

Needs you counts in the header on medium (rows need the height) and as a large numeral on small. Board's parts are ordered failed job, Kanban, next run, and dropped from the end, so a failure survives the smallest size.

### Redaction, lock screen and locked devices

iOS redacts `.privacySensitive()` views on a locked device. Android has no such flag for a widget: a launcher widget on a keyguard shows what it draws. So: (1) widgets declare `android:widgetCategory="home_screen"` and never `keyguard`, which keeps them off the lock screen of devices that offer lock screen widgets; (2) App Lock keeps working through the snapshot (empty titles, no snippets or job names), and the view draws placeholder bars with content description "Hidden"; (3) counts, ages and kind words are shown as on iOS. Row content descriptions are built from kind and count, never from a title while App Lock is on. Whether to add a "Show chat titles on widgets" setting is an open question.

Picker previews: `android:previewLayout` (API 31) and `android:previewImage` (below 31) are static resources with sample titles. They never read `HomeWidgetPreferences`. The previews are rendered from the design canvas's Picker artboard.

### Appearance

`GlanceTheme` with dynamic colour on Android 12 and newer and a fixed colour scheme built from the Hermes palette below it; light and dark follow the system. The canvas draws the fallback tokens. Corner radius is the system's widget radius (`system_app_widget_background_radius`) where the launcher supplies it, 24 dp otherwise. Failed is an icon, the word and the error colour; a request kind is an icon and a word; counts are numerals. Placeholder bars are decorative.

### Taps and deep links

A row's tap is `actionStartActivity<MainActivity>(context, Uri.parse(row.url))` from the plugin: an explicit intent for `MainActivity` with the link as data. `app_links` delivers any intent's data string except the SEND family and ignores `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`, so the existing `DeepLinks.open` path handles it, a cold start included (held until the shell is up) and App Lock asks before the chat shows. Links come from the snapshot verbatim (`deepLinkUri` is still the only producer); the reader skips a row whose scheme is not `hermes`. Signed out or no snapshot, the tap is a plain launcher intent. The `singleTop` and empty `taskAffinity` of `MainActivity` mean a tap while the app is open arrives in `onNewIntent`; whether a PendingIntent from a widget joins the existing task is a device check.

### Refresh and staleness

`SurfaceSnapshotStore` asks the three providers to redraw after each write (same hourly rule for an unchanged snapshot; Android has no WidgetKit budget but the rule keeps the redraws and wake-ups few). Between writes the system redraws on `updatePeriodMillis="1800000"`, the platform minimum, so ages, the six-hour note and "Due" move without the app. A redraw is a read of the preferences and a recomposition; no network, no Dart, no isolate. Alternative: `HomeWidget.scheduleWidgetUpdates` for the exact stale and next-run instants, which adds `RECEIVE_BOOT_COMPLETED`, a receiver and inexact alarms without the exact-alarm permission; not worth the manifest weight for a note that is allowed to be 30 minutes late. Doze and OEM battery savers can delay `updatePeriodMillis` further; the six-hour note is then late, never wrong content.

### Dart changes

- `surface_snapshot_store.dart`: `reload(kind)` calls `HomeWidget.updateWidget(iOSName: kind, androidName: kind)` so each platform uses its own name. The store's `widgetKinds` default becomes the platform's list.
- `widget_kinds.dart`: `kSurfaceWidgetKinds` keeps the iOS six; a new `kAndroidWidgetKinds` holds the three with an Android provider; `surfaceWidgetKindsFor(platform)` picks. The file's comment says a new kind joins `kSurfaceWidgetKinds` and, if it has an Android provider, `kAndroidWidgetKinds` too (the `surfaces-and-intents.md` rule is updated with it). `kSignedInOnlyWidgetKinds` stays iOS-only: no Android widget reads only the signed-in flag.
- `widget_usage_reporter.dart`: on Android the kind is `androidClassName` without its leading dot and the family is `android`.

### Backup

`android:allowBackup` is on by default, so the snapshot's preferences file would go to Google Drive backup and to a new phone, with chat titles in it. The manifest gets `android:dataExtractionRules` (Android 12+) and `android:fullBackupContent` (older), both excluding `HomeWidgetPreferences.xml` and `InternalHomeWidgetPreferences.xml` from the `sharedpref` domain. This also fixes the exposure for the existing snapshot on Android, which predates the widgets.

### Localization

The widgets' strings (kind words, empty and stale notes, "Hidden", picker labels and descriptions) are Android string resources in `values/` and `values-de/`, since a Glance widget runs outside the Flutter engine and cannot read the ARB files. The words are the iOS ones; the German is the existing app's German where it has the same phrase. `lib/l10n` is untouched. The iPhone widgets' strings are English literals in SwiftUI today, so the two platforms differ until those are localised (a finding for the roadmap); the Android ones are resources from the start so they can be.

### Platforms and native changes

Android only. `AndroidManifest.xml`: three exported `<receiver>` entries (`APPWIDGET_UPDATE`, `android.appwidget.provider` meta-data) and the two backup attributes on `<application>`. New: `res/xml/hermes_*_info.xml` (three), `res/xml/backup_rules.xml`, `res/xml/data_extraction_rules.xml`, `res/layout/hermes_widget_loading.xml` and preview layouts, `res/drawable` icons and preview images, `res/values` and `values-de` strings, `res/raw/keep.xml` additions for anything referenced only from XML. `build.gradle.kts`: Compose plugin and test dependencies. No permission, no entitlement, no iOS, macOS, Windows, Linux or watchOS change. The exported receivers read no extra from the broadcast, so a spoofed `APPWIDGET_UPDATE` can only redraw a widget.

### Invariants touched

- Auth and tokens: untouched; the widgets run no request and read no token, and the snapshot has none.
- API layering: untouched; no REST call, no generated-client change.
- Telemetry: `widgets.installed` and `widgets.reload_failed` only, both swallow their own failures; nothing the widgets draw enters a span, log or breadcrumb. A render problem inside the launcher cannot be reported; a snapshot the reader cannot parse draws the signed-out text.
- Privacy: no content beyond what a notification body allows; App Lock blanks titles and text; the snapshot leaves backups.

### Signals

| Signal                              | Where                                    | Attributes                                                     | Content |
| ----------------------------------- | ---------------------------------------- | -------------------------------------------------------------- | ------- |
| `widgets.installed` (log event)     | `WidgetUsageReporter.report`, once a day | `widgets.count`, `widgets.kinds` (`HermesBoard/android=2,...`) | None    |
| `widgets.reload_failed` (log event) | `SurfaceSnapshotStore._reload`           | `widget.kind`, `error.type`                                    | None    |

No span and no breadcrumb: the work happens outside the engine, and the reload's failure event already names the kind.

## Design pass (done)

Claude Design canvas "Hermes: Android home widgets", built on the Hermes App design system: https://claude.ai/artifact/A32jNXKc4gSovjGJidbLhB (private; ask its owner for access). Seven artboards, rendered headlessly; not looked at in the claude.ai viewer. Decisions and the list are in `docs/design-briefs/android-home-widgets.md`, "Design (done)". The ones that change behaviour are in the Sizes, rows and targets, Redaction and Appearance sections above: medium is 4x3 because 48 dp rows need the height, rows drop from the bottom, the snippet drops first at large text, Failed carries an icon, and nothing goes on the keyguard.

## Risks / Trade-offs

- [Build] Compose compiler plugin 2.4.21 with AGP 9.5.1 and `android.builtInKotlin=false`, plus Glance 1.2.0 and `compileSdk` 37, is untried here. First task builds an empty Glance widget before anything else; if it fails, fall back to XML `RemoteViews` (same models, same manifest) and update this file.
- [Not verified on a device] No emulator or phone ran. Rendering, resize rows, the 30 minute redraw, Doze delay, launcher differences (Pixel, Samsung One UI, Nothing, Fairphone), the tap into an open or cold app, the picker previews and the backup exclusion are all unchecked.
- [OEM redraw limits] Some launchers or battery savers delay `updatePeriodMillis` for hours. A widget then shows an old age or misses the stale note until the app next writes. Accepted; the content is the last snapshot, never wrong data.
- [Titles on the home screen] Anyone who sees an unlocked home screen sees chat titles when App Lock is off, as iOS Home Screen widgets do. Accepted, with the open question below.
- [Exported receivers] Required for `APPWIDGET_UPDATE`; they read nothing from the intent.
- [Plugin] `home_widget` is a one-maintainer project; Glance state and `updateWidget` are its public API, and Google's Glance is the real dependency.

## Migration Plan

Additive. Existing installs get new widget entries in the picker; no data migrates. The first run after update writes the snapshot as before; the backup exclusion applies to the next backup, and an already uploaded backup keeps its copy until it expires.

## Open questions

- A "Show chat titles on widgets" switch. Recommended no for now: Android home screens are as exposed as iOS ones and the snapshot rule is "nothing a notification body would not show". If wanted, it is one extra blank in the snapshot writer, shared with iOS.
- Should the Widgetbook catalog get a Flutter replica of the three widgets? Recommended no: it would duplicate the Glance drawing and could drift; the Kotlin models are tested against the shared fixture and the design canvas is the visual reference.
- Large size and a Quick launch widget as follow-ups once the first two PRs are verified on a device.
