# Localization

The app's user-visible text comes from Flutter's `gen-l10n`. English (`en`) is
the template. German (`de`) is the first translation, but it is not released
yet (see [Released locales](#released-locales)). Most of the app is still
English literals in widgets. They move into the ARB files directory by
directory (see [Extraction pull requests](#extraction-pull-requests)). The
settings area (`lib/src/settings/`) is the finished example.

## Files

| Path                              | What it is                                                                                                                              |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `l10n.yaml`                       | gen-l10n settings: ARB directory, output directory, class name.                                                                         |
| `lib/l10n/arb/app_en.arb`         | The template: every English message and its `@metadata`.                                                                                |
| `lib/l10n/arb/app_de.arb`         | German. Messages only, no metadata.                                                                                                     |
| `lib/l10n/l10n.dart`              | `context.l10n`, `kReleasedLocales`, `l10nForPlatformLocale`, and re-exports `AppLocalizations`. Import this, never the generated files. |
| `lib/l10n/generated/`             | gen-l10n output. **Not checked in** (`.gitignore`).                                                                                     |
| `test/l10n/arb_layout_test.dart`  | Checks the layout rules below, translation completeness and placeholders.                                                               |
| `test/l10n/l10n_lookup_test.dart` | Checks `l10nForPlatformLocale`.                                                                                                         |

## Generated code and when to regenerate

`pubspec.yaml` sets `flutter: generate: true`, so `flutter pub get`, `flutter
run` and every `flutter build` regenerate `lib/l10n/generated/`. CI runs
`flutter pub get` before format, analyze and tests, so the generated code is
always there in CI.

`flutter test`, `flutter analyze` and the pre-commit hook do **not**
regenerate. The generated code goes stale, and you see "The getter
'settingsFoo' isn't defined for the type 'AppLocalizations'", whenever an ARB
file changes under you:

- after you edit an ARB file;
- after a `git pull`, rebase or merge that brings someone else's new keys;
- on a fresh clone, before the first `flutter pub get`.

Run `flutter gen-l10n` (fast, only the strings) or `flutter pub get` then.

The generated code is not committed because every extraction PR would
otherwise change the same three generated Dart files, and those would conflict
between any two PRs.

## Reading a string in a widget

```dart
import '../../l10n/l10n.dart';

Text(context.l10n.settingsTitle)
```

Read `context.l10n` in `build`, or anywhere else with a `BuildContext` below
the app. Bind it once when a build uses several strings:
`final l10n = context.l10n;`. Pass `AppLocalizations l10n` into helper
functions instead of a context, as `themeModeLabel(l10n, mode)` in
`lib/src/settings/appearance_dialog.dart` does.

When no `AppLocalizations` delegate is above the context, `context.l10n`
returns English instead of throwing. That keeps the many tests and catalog
entries that build a bare `MaterialApp` working while strings move. In a debug
build outside tests it prints one line saying so, because in the app it means
a `MaterialApp` without the delegates. Do not call
`AppLocalizations.of(context)` directly; it has no such fallback.

A `const` widget cannot hold a localized string. Drop the `const` from the
widget that reads it (for example `const Text('Retry')` becomes
`Text(l10n.commonRetry)`), and keep `const` on its children where it still
applies.

## Released locales

`AppLocalizations.supportedLocales` (generated) lists every ARB file.
`kReleasedLocales` in `lib/l10n/l10n.dart` lists the locales the app offers
its users, and it is what the apps pass as `supportedLocales`:
`lib/src/app.dart`, the conversation window
(`lib/src/windows/conversation_window_app.dart`) and the quick panel
(`lib/src/quick_panel/quick_panel_app.dart`). All three still pass
`AppLocalizations.localizationsDelegates`, so every translation loads where a
locale is passed explicitly. A new top-level app must do the same.

German does not ship half-translated. `de` is added to `kReleasedLocales` in
one small PR once chat, auth and setup, settings and the shell are extracted.
Until then a German system shows the app, including Flutter's own Material
labels, in English. The ARB files, tests and the catalog use German already.
`test/l10n/arb_layout_test.dart` checks that every released locale has an ARB
file.

## Where a string goes: one ARB file, one block per area

gen-l10n reads exactly one ARB file per locale. Each file is split into
blocks, one per area, each opened by an anchor, so many PRs can add strings at
the same time without touching the same lines:

```json
{
  "@@locale": "en",

  "@@x-area-common": "",
  "commonOff": "Off",
  "@commonOff": {
    "description": "A setting or slot that is switched off."
  },

  "@@x-area-agent_messages": "",

  ...

  "@@x-area-chat": "",

  "@@x-area-chat/activity": "",

  ...

  "@@x-area-settings": "",
  "settingsAboutHermes": "About Hermes",
  ...

  "@@x-end": ""
}
```

- `@@x-area-<area>` is an ARB global attribute that gen-l10n ignores. The
  anchors are already there, in the same order in every locale: `common`
  first, then the areas alphabetically. Never move or remove one.
- An area is a directory under `lib/src/`. `lib/src/chat/` is split further:
  its own files are `chat`, and each of its sub-directories has its own area
  (`chat/activity`, `chat/attachments`, `chat/gateway`, `chat/invalidation`,
  `chat/media`, `chat/memory`, `chat/queue_storage`, `chat/reactions`,
  `chat/session_usage`, `chat/side_results`, `chat/todo_plan`,
  `chat/widgets`), so those can be extracted in parallel.
- Files directly in `lib/src/` (`app.dart`) belong to the `shell` area.
- An area's keys sit between its anchor and the blank line before the next
  anchor, sorted alphabetically (by code unit, as Dart's `sort` does, so
  `settingsAppLock` comes before `settingsAppearanceTitle`).
- In the template, each message is followed directly by its `@key` metadata.
- Every entry line ends with a comma. The file ends with `"@@x-end": ""`,
  which never changes, so no PR edits the last entry to add a comma.

Git merges two changes cleanly when at least one unchanged line separates
them. Two PRs that add keys to different areas change different blocks, and
the anchor and blank lines between those blocks never change, so the PRs do
not conflict however many run in parallel. Per-area source files merged by a
script were considered and rejected. `flutter pub get` runs gen-l10n before
any script could merge them, so the merged `app_en.arb` would have to be
committed, and every PR would still change that one file.

A directory added under `lib/src/` later gets its anchor, in alphabetical
position, in every ARB file, in the PR that first adds strings for it.

### `common`

`common` holds a few words that many areas use the same way (`commonOn`,
`commonOff`, `commonRetry`). Reuse a `common` key that exists when it means
the same thing in your area. Extraction PRs do not add to the `common` block,
since two PRs adding to it at once would conflict. Add an area key instead
(`kanbanArchive`, even if another area has the same word), and ask for a new
`common` key in a small PR of its own if several areas need it.

Material and Cupertino already translate their own labels
(`MaterialLocalizations.of(context).cancelButtonLabel`, `okButtonLabel`,
`backButtonTooltip`, …). Prefer those over a new key where the meaning is the
same.

## Key names

`<area><Thing>` in lowerCamelCase:

- `<area>` is the area in camel case: `settings`, `kanban`, `botMode` (for
  `bot_mode`), `chatWidgets` (for `chat/widgets`), `chatQueueStorage` (for
  `chat/queue_storage`). The layout test fails when a key under an anchor does
  not start with its area followed by a capital letter.
- `<Thing>` says where the text is and what it is for, from general to
  specific: `settingsHelperModelsTitle`, `settingsHelperModelsLoadFailed`,
  `settingsSignOutTitle`, `settingsSignOutMessage`. Keys that belong together
  then sort together.
- Name a key for its meaning, not its English words, so a later wording change
  does not mean a rename. `settingsSignOut` is the action;
  `settingsSignOutTitle` is the question asking about it.
- The same English word used for two different things gets two keys (German
  often needs two words). The same thing shown in two places shares one key
  (`settingsReportBug` is the About row and the link on the sign-in screen).
- Do not rename or delete another area's keys.

## Descriptions for translators

Translators see only the ARB file, not the screen. Every template message has
a `description` (the layout test checks), which says:

- where the text appears: "Title of the sign-out confirmation", "Settings row
  that …", "Snackbar when …", "Accessibility label of …";
- what it means when the English word is ambiguous: "Theme mode: always dark",
  "A setting or slot that is switched off";
- what each placeholder holds, with an `example` taken from a real value
  (`"example": "deepseek-v4-pro"`);
- length limits where they matter: "Menu item; keep it short", "Fits a 28 pt
  sidebar row".

Do not repeat the English text or describe the code.

## Adding a string

1. Add the key under its area's anchor in `app_en.arb`, in alphabetical
   position, with its `description`.
2. Add the same key, at the same position under the same anchor, to
   `app_de.arb` with the German text. A key missing from `app_de.arb` shows
   in English and fails `test/l10n/arb_layout_test.dart`.
3. `flutter gen-l10n`, then use `context.l10n.<key>` in the widget.
4. Run `flutter test test/l10n` and the tests of the widget you changed.

## Placeholders

Write placeholders in braces and declare them in the template's metadata:

```json
"settingsHelperModelsFooterMainModel": "Main model is {model}.",
"@settingsHelperModelsFooterMainModel": {
  "description": "Sentence below the helper model list naming the profile's main model.",
  "placeholders": {
    "model": {"type": "String", "example": "deepseek-v4-pro"}
  }
},
```

```json
"settingsHelperModelsFooterMainModel": "Das Hauptmodell ist {model}.",
```

The generated method takes the placeholders as positional arguments:
`l10n.settingsHelperModelsFooterMainModel(main)`. A translation may move the
placeholder anywhere in the sentence (`"{slot} konnte nicht geändert
werden"`), which is why a sentence is one message, never English fragments
joined in Dart. Joining whole sentences or list items with `' '` or `' · '`
is fine, as `HelperModelList` does for its footer. A translation must use the
same placeholders as the English (the layout test checks).

Give `int`, `num`, `double` and `DateTime` placeholders their type, and a
`format` where the number or date is shown (`"format": "compact"`,
`"format": "yMMMd"`), so German gets its own separators and order instead of
`toString()`.

## Plurals and selects

Anything that counts uses an ICU plural, never `count == 1 ? … : …` in Dart:

```json
"kanbanBlockedTasks": "{count, plural, =0{No blocked tasks} =1{1 blocked task} other{{count} blocked tasks}}",
"@kanbanBlockedTasks": {
  "description": "Count of blocked tasks above the board.",
  "placeholders": {"count": {"type": "int"}}
},
```

```json
"kanbanBlockedTasks": "{count, plural, =0{Keine blockierten Aufgaben} =1{1 blockierte Aufgabe} other{{count} blockierte Aufgaben}}",
```

`other` is required. German and English need only `=0`/`=1`/`other` (or `one`
and `other`). Other languages may add `few` and `many`, which is why the
choice belongs in the ARB file.

Where a server value picks the wording, use a `select` with an `other` branch
for values the app does not know:

```json
"chatToolStatus": "{status, select, running{Running} failed{Failed} other{Done}}",
"@chatToolStatus": {"placeholders": {"status": {"type": "String"}}},
```

## Strings from controllers and repositories

No user-visible string is made below the widget layer. A controller,
repository or transport returns what happened: an enum of error kinds, a
sealed result or the setting it concerns. The widget turns that into words
with `context.l10n`. Then the controller needs no context, its tests assert
on kinds rather than English, and the text follows the locale of the screen
that shows it.

`lib/src/memory/memory_settings_controller.dart` is the pattern to replace.
Today it builds the sentence itself:

```dart
// Before: the controller writes English.
} on MemoryWriteFailure {
  message = "Couldn't change ${setting.label}. Try again.";
```

After extraction it keeps the failure and the widget words it:

```dart
// Controller: what failed, no words.
} on MemoryWriteFailure {
  failedSetting = setting;

// Widget:
if (controller.failedSetting case final setting?)
  Text(l10n.memorySettingChangeFailed(memorySettingLabel(l10n, setting)));
```

`setting.label` is an English field on a model (`MemorySetting`). It goes too:
the widget maps the enum to a key (`memorySettingLabel(l10n, setting)`), as
`themeModeLabel` does for `ThemeMode`.

## Widgets that take texts as parameters

A shared widget that takes its text (`GroupedRow(title:)`,
`showConfirmDialog(title:, message:, confirmLabel:)`, `StateMessage(title:)`)
keeps taking a `String`. Its callers pass `context.l10n.…`, and the
strings belong to the caller's area. Only the text the shared widget writes
itself (a default label, a tooltip it adds) is extracted in its own area
(`widgets` for `lib/src/widgets/`). A default that callers rely on, such as a
Cancel button, comes from `MaterialLocalizations` or a `widgets…` key, never
from a parameter's English default value.

## Text outside a widget tree

Notifications, background runs, Live Activities, the Mac menu bar item, App
Intents and the surface snapshot make text without a `BuildContext`.

- **Which locale.** Call `l10nForPlatformLocale()` from `lib/l10n/l10n.dart`.
  It resolves `PlatformDispatcher.instance.locales` against
  `kReleasedLocales` with `basicLocaleListResolution`, the same rule
  `MaterialApp` uses, so a background isolate and the app in front pick the
  same language. Do not call `lookupAppLocalizations` with a platform locale:
  it throws for a locale without an ARB file. Read it per run (per
  notification, per background task), not once per process, because the user
  can change the system language while the app is suspended.
- **Native code gets finished text.** Swift and Kotlin never hold the app's
  strings. Dart localizes the text and sends it ready to show, over the
  platform channel (a notification's title and body, the menu bar item's
  rows, an intent's spoken answer) or in the surface snapshot (widget
  titles, labels). Fixed native UI that Dart never sees (widget gallery
  names, notification button titles set in Swift,
  `Info.plist` usage strings) needs native localization (`.xcstrings`,
  `strings.xml`). That is separate work, listed under
  [Platform notes](#platform-notes).
- **Text and payload agree.** A notification's text and its payload
  (target, ids) are built in the same call from the same data, with the same
  `AppLocalizations`. Ids, category ids and payload keys stay English
  identifiers (see [What not to localize](#what-not-to-localize)). Only what a
  person reads is localized.
- **Dates and numbers.** `MaterialApp`'s delegates load intl's date symbols.
  A background isolate has no `MaterialApp`, so before formatting a date
  there, through a `DateTime` placeholder or `DateFormat`, call
  `await initializeDateFormatting(l10n.localeName)` from
  `package:intl/date_symbol_data_local.dart` once per isolate. Without it
  `DateFormat` throws for any locale but `en_US`.

## Writing German

- Address the user as „du“, consistently.
- Use the platform's own words where there is one: „Einstellungen“,
  „Abmelden“, „Erscheinungsbild“, „Benachrichtigungen“, „Info“ for About,
  „aktiviert“/„deaktiviert“ rather than „an“/„aus“ in sentences.
- Keep the typographic characters of the English: `…` (one character) on a
  menu item that opens more, `’` and `·`.
- Product and feature names stay as they are: Hermes, Spotlight, Kanban,
  Dashboard.

## Tests

- English texts must stay exactly as they were. Existing tests find widgets by
  their English text, and the default test locale is `en_US`, so they keep
  passing without change.
- The shared harnesses (`test/support/pump_chat.dart`,
  `test/support/workflow_app.dart`, `test/support/pump_on_platform.dart`,
  `test/widgetbook_test.dart`) set the delegates and every generated locale.
  A test with its own bare `MaterialApp` gets English through the
  `context.l10n` fallback.
- To check a translation, pass the locale explicitly: pump with
  `locale: const Locale('de')`, the delegates and
  `AppLocalizations.supportedLocales`, as
  `test/settings/settings_l10n_test.dart` does. One German test per extracted
  area is enough to catch a string that was not wired.
- The catalog (Widgetbook) has a Locale addon (English, German). Look at the
  German use cases of the widgets you extracted: German words are longer, and
  a row that fit in English may now wrap or overflow.

## What not to localize

These stay plain strings in code:

- Telemetry: span, event and attribute names, breadcrumbs (`chat.reply.started`),
  log messages and log attribute values.
- Anything sent to or read from the server: RPC methods, JSON keys, ids,
  provider and model ids, preset names (`'default'`), slash commands
  (`/memory approve`), config keys (`memory.write_approval`).
- Deep-link words and schemes (`hermes://chat?profile=`), notification
  category and action ids, platform channel names and method names, shared
  preference keys, `Key`/`ValueKey` values.
- Text that comes from the server or the user: chat titles, profile names,
  model names, error text Hermes sends. Wrap it in a localized sentence with a
  placeholder when the app adds words around it.
- Keyboard shortcut glyphs (`⌘,`) and the product name „Hermes“ on its own.
- Exception messages meant for developers (`StateError`, `ArgumentError`).

## Extraction pull requests

The rest of the app moves in PRs split by area, so they can run in parallel:

1. One PR per area (one anchor). Touch only that area's blocks in
   `app_en.arb` and `app_de.arb` and the Dart files of that directory. Two
   PRs for the same area run one after the other.
2. Extract every user-visible string of those files in the PR, with German,
   including strings their controllers and models make (see
   [Strings from controllers and repositories](#strings-from-controllers-and-repositories)).
   Leave nothing half-done in a file: a reader should be able to trust that a
   file with `context.l10n` has no English literals left.
3. Keep English identical. If a test fails because of a text, the extraction
   changed the text; fix the ARB, not the test.
4. Do not edit `common`, another area's block, `kReleasedLocales`,
   `l10n.yaml`, `lib/l10n/l10n.dart` or the shared test harnesses in an
   extraction PR.
5. Prove the directory is done before opening the PR. This lists literals
   that are still user-visible candidates (run from the repo root, with your
   directory):

   ```bash
   rg -n --pcre2 \
     -e "\bText\(\s*['\"]" \
     -e "\b(title|label|tooltip|semanticLabel|semanticsLabel|hintText|labelText|helperText|errorText|message|confirmLabel|cancelLabel|subtitle|header|footer|value|caption):\s*['\"][^'\"]*[A-Za-z]" \
     -e "SnackBar\(\s*content:\s*(const\s+)?Text\(\s*['\"]" \
     -e "AdaptiveMenuItem\([^)]*child:\s*(const\s+)?Text\(\s*['\"]" \
     -e "(TextButton|FilledButton|ElevatedButton|OutlinedButton|CupertinoDialogAction)\([^)]*child:\s*(const\s+)?Text\(\s*['\"]" \
     -e "=\s*['\"][A-Z][a-z]+( [a-z]+)+[.?!…]?['\"]" \
     lib/src/<directory>/
   ```

   Every remaining hit must be on the [What not to localize](#what-not-to-localize)
   list. Multi-line widget calls slip past single-line patterns, so also look
   over `rg -n "'[A-Z][a-z]" lib/src/<directory>/` and
   `rg -n '"[A-Z][a-z]' lib/src/<directory>/`.

6. On a rebase conflict in an ARB file (only possible when two PRs touched the
   same area), keep both sides' keys in alphabetical order, run
   `flutter gen-l10n` and `flutter test test/l10n`.
7. PR title: `feat(l10n): localize <area>`.

## Platform notes

Not done yet, and needed before a translation is released:

- `CFBundleLocalizations` in `ios/Runner/Info.plist` and
  `macos/Runner/Info.plist` lists exactly the languages in `kReleasedLocales`
  (today `en`), so iOS and macOS offer the app in those languages and nothing
  else. Both lists must follow `kReleasedLocales`: releasing a locale means
  adding its tag to both plists in the same PR.
  `test/l10n/bundle_localizations_test.dart` parses both and fails on drift.
  Still open: the extension bundles (share extensions, `HermesLiveActivity`,
  the watch app and its complications), which need the same entry once they
  carry translated native strings.
- Android's per-app language setting (`android/app/src/main/res/xml/locales_config.xml`
  and `android:localeConfig` in the manifest).
- Native strings that Dart never sends: the Swift widgets' gallery names and
  fixed labels, notification button titles set in Swift (`AppDelegate.swift`), the Live Activity's
  fixed words, and `Info.plist` usage strings (microphone, speech
  recognition, Face ID, photos).
- A German (de-DE) App Store and Play Store listing (`fastlane/metadata/`).
