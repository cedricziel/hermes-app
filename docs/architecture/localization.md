# Localization

The app's user-visible text comes from Flutter's `gen-l10n`. English (`en`) is
the template; German (`de`) is the first translation. Most of the app is still
English literals in widgets; they move into the ARB files directory by
directory (see [Extraction pull requests](#extraction-pull-requests)). The
settings area (`lib/src/settings/`) is the finished example.

## Files

| Path                             | What it is                                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------ |
| `l10n.yaml`                      | gen-l10n settings: ARB directory, output directory, class name.                            |
| `lib/l10n/arb/app_en.arb`        | The template: every English message and its `@metadata`.                                   |
| `lib/l10n/arb/app_de.arb`        | German. Messages only, no metadata.                                                        |
| `lib/l10n/l10n.dart`             | `context.l10n`, and re-exports `AppLocalizations`. Import this, never the generated files. |
| `lib/l10n/generated/`            | gen-l10n output. **Not checked in** (`.gitignore`).                                        |
| `test/l10n/arb_layout_test.dart` | Checks the layout rules below.                                                             |

`pubspec.yaml` sets `flutter: generate: true`, so `flutter pub get`, `flutter
run` and every `flutter build` regenerate `lib/l10n/generated/`. CI runs
`flutter pub get` before format, analyze and tests, so the generated code is
always there. After editing an ARB file, run `flutter pub get` (or
`flutter gen-l10n`) before analyzing or testing; a fresh clone needs the same
before the IDE stops reporting a missing import.

The generated code is not committed because every extraction PR would
otherwise change the same three generated Dart files, and those would conflict
between any two PRs.

## Reading a string

```dart
import '../../l10n/l10n.dart';

Text(context.l10n.settingsTitle)
```

Read `context.l10n` in `build` (or anything that has a `BuildContext` below
the app). Bind it once when a build uses several strings:
`final l10n = context.l10n;`. Pass `AppLocalizations l10n` into helper
functions instead of passing a context, as `themeModeLabel(l10n, mode)` in
`lib/src/settings/appearance_dialog.dart` does.

`MaterialApp` in `lib/src/app.dart`, the conversation window
(`lib/src/windows/conversation_window_app.dart`) and the quick panel
(`lib/src/quick_panel/quick_panel_app.dart`) set
`localizationsDelegates: AppLocalizations.localizationsDelegates` and
`supportedLocales: AppLocalizations.supportedLocales`. A new top-level app
must do the same.

When no `AppLocalizations` delegate is above the context, `context.l10n`
returns English instead of throwing. That keeps the many tests and catalog
entries that build a bare `MaterialApp` working while strings move. Do not
call `AppLocalizations.of(context)` directly; it has no such fallback.

A `const` widget cannot hold a localized string. Drop the `const` from the
widget that reads it (for example `const Text('Retry')` becomes
`Text(l10n.commonRetry)`), and keep `const` on its children where it still
applies.

## Where a string goes: one ARB file, one block per area

gen-l10n reads exactly one ARB file per locale. To let many PRs add strings at
the same time without touching the same lines, each file is split into
blocks, one per directory under `lib/src/`, each opened by an anchor:

```json
{
  "@@locale": "en",

  "@@x-area-common": "",
  "commonOff": "Off",
  "@commonOff": {
    "description": "A setting or slot that is switched off."
  },

  "@@x-area-agent_messages": "",

  "@@x-area-api": "",

  ...

  "@@x-area-settings": "",
  "settingsAboutHermes": "About Hermes",
  ...

  "@@x-end": ""
}
```

- `@@x-area-<directory>` is an ARB global attribute that gen-l10n ignores.
  The anchors are already there for every directory under `lib/src/`, in the
  same order in every locale: `common` first, then the directories
  alphabetically. Never move or remove one.
- An area's keys sit between its anchor and the blank line before the next
  anchor, sorted alphabetically (by code unit, as Dart's `sort` does, so
  `settingsAppLock` comes before `settingsAppearanceTitle`).
- In the template, each message is followed directly by its `@key` metadata.
- Every entry line ends with a comma. The file ends with `"@@x-end": ""`,
  which never changes, so no PR edits the last entry to add a comma.

Git merges two changes cleanly when at least one unchanged line separates
them. Two PRs that add keys to different areas change different blocks, and
the anchor and blank lines between those blocks never change, so the PRs do
not conflict however many run in parallel. (Per-area source files merged by a
script were considered and rejected: the merged `app_en.arb` would have to be
committed, because `flutter pub get` runs gen-l10n before any script could
merge, so every PR would still change the one merged file.)

A new directory under `lib/src/` gets its anchor, in alphabetical position, in
every ARB file, in the PR that first adds strings for it.

### `common`

`common` holds a few words that many areas use the same way (`commonOn`,
`commonOff`, `commonRetry`). Reuse a `common` key that exists when it means
the same thing in your area. Extraction PRs do not add to the `common` block,
since two PRs adding to it at once would conflict: add an area key instead
(`kanbanArchive`, even if another area has the same word), and ask for a new
`common` key in a small PR of its own if several areas need it.

Material and Cupertino already translate their own labels
(`MaterialLocalizations.of(context).cancelButtonLabel`, `okButtonLabel`,
`backButtonTooltip`, …). Prefer those over a new key where the meaning is the
same.

## Key names

`<area><Thing>` in lowerCamelCase:

- `<area>` is the directory under `lib/src/` in camel case: `settings`,
  `kanban`, `botMode` (for `bot_mode`), `appLock` (for `app_lock`). The layout
  test fails when a key under an anchor does not start with its area followed
  by a capital letter.
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

## Adding a string

1. Add the key under its area's anchor in `app_en.arb`, in alphabetical
   position, with a `description` saying where it appears and what it means.
   Translators see only the ARB file.
2. Add the same key, at the same position under the same anchor, to
   `app_de.arb` with the German text. A key missing from `app_de.arb` shows
   in English and fails `test/l10n/arb_layout_test.dart`.
3. `flutter pub get`, then use `context.l10n.<key>` in the widget.
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
is fine, as `HelperModelList` does for its footer.

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
and `other`); other languages may add `few` and `many`, which is why the
choice belongs in the ARB file.

Where a server value picks the wording, use a `select` with an `other` branch
for values the app does not know:

```json
"chatToolStatus": "{status, select, running{Running} failed{Failed} other{Done}}",
"@chatToolStatus": {"placeholders": {"status": {"type": "String"}}},
```

## Writing German

- Address the user as „du“, consistently.
- Use the platform's own words where there is one: „Einstellungen“,
  „Abmelden“, „Erscheinungsbild“, „Benachrichtigungen“.
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
  `test/widgetbook_test.dart`) set the delegates. A test with its own bare
  `MaterialApp` gets English through the `context.l10n` fallback.
- To check a translation, pump with `locale: const Locale('de')` and the
  delegates, as `test/settings/settings_l10n_test.dart` does. One German test
  per extracted area is enough to catch a string that was not wired.
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

Text the system shows outside a widget tree (local notifications, Live
Activities, widgets, App Intents, the Mac menu bar) is out of scope for the
first extraction PRs. It needs `lookupAppLocalizations(locale)` with a locale
resolved from the platform, and native strings for the parts Swift draws.

## Extraction pull requests

The rest of the app moves in PRs split by directory, so they can run in
parallel:

1. One PR per directory under `lib/src/` (or per sub-directory of a large one,
   such as `chat/widgets/`; the keys still use the top-level area prefix and
   go under the top-level anchor, sorted). Touch only your area's blocks in
   `app_en.arb` and `app_de.arb` and the Dart files of that directory.
2. Extract every user-visible string of those files in the PR, with German.
   Leave nothing half-done in a file: a reader should be able to trust that a
   file with `context.l10n` has no English literals left.
3. Keep English identical. If a test fails because of a text, the extraction
   changed the text; fix the ARB, not the test.
4. Do not edit `common`, another area's block, `l10n.yaml`, `lib/l10n/l10n.dart`
   or the shared test harnesses in an extraction PR.
5. Widgets shared by several areas (`lib/src/widgets/`) belong to the
   `widgets` area. A widget that takes its texts as parameters stays that
   way; its callers pass localized strings.
6. On a rebase conflict in an ARB file (only possible when two PRs touched the
   same area), keep both sides' keys in alphabetical order and run
   `flutter test test/l10n`.
7. PR title: `feat(l10n): localize <area>`.

## Platform notes

On iOS and macOS, Flutter's documentation asks for the supported languages in
`CFBundleLocalizations` in each Runner's `Info.plist` so the system offers the
app in those languages. That entry is not there yet; until it is, Apple
platforms may keep showing the app in English.
