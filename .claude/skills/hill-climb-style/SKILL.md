---
name: hill-climb-style
description: Use when measuring or lowering the hermes-app style score S (hand-written colours, off-scale spacing and radii, literal font sizes, elevation, dialogs built outside the shared helpers, non-adaptive controls, English strings in widgets) or the tap-target count T, when adding an exception to tool/style_score_allowlist.yaml, or when a style ratchet check fails.
---

# Hill-climb: style score S and tap targets T

Two tools that measure. They change no app code. The style score S is also ratcheted (see Ratchet below); tap targets T are not.

## Style score S: `tool/style_score.dart`

```bash
dart run tool/style_score.dart                       # summary, then every hit as path:line  category  snippet
dart run tool/style_score.dart --no-list --top 20    # summary only
dart run tool/style_score.dart --category a.color --area chat
dart run tool/style_score.dart --json                # same data, plus per-rule per-file counts
dart run tool/style_score.dart --ratchet-yaml        # rule -> path: count, the shape of a baseline file
```

Pure Dart on `package:analyzer` syntax trees (no resolution), about 10 s, sorted and
deterministic. It scans `lib/**/*.dart` except `lib/src/theme/**`, `lib/l10n/**`,
`*.g.dart` and `*.freezed.dart`. Colour tokens live in
`lib/src/theme/hermes_theme.dart` (`HermesColors`, `HermesChatColors`, the `ColorScheme`).

S is the total of the categories below. Each has a stable rule id (the key in the
JSON `rules` and in `--ratchet-yaml`, so a later ratchet baseline can use it):

| Category | Rule id | Counts |
| --- | --- | --- |
| `a.color` | `style.color` | `Color(0x..)`, `Color.fromARGB/fromRGBO/from`, and `Colors.<x>` except `Colors.transparent` |
| `a.spacing` | `style.spacing` | an off-scale numeric literal in any `EdgeInsets`/`EdgeInsetsDirectional` constructor, in `Gap(..)`, in `spacing:`/`runSpacing:`, and as `width:`/`height:` of a childless `SizedBox`, or `dimension:` of a childless `SizedBox.square`, that is an element of a children list or the widget a `separatorBuilder:` closure returns (a gap). A `SizedBox` with a child, or returned or chosen on its own, is a size, not a gap |
| `a.radius` | `style.radius` | an off-token literal in `BorderRadius.circular`, `Radius.circular/elliptical`, `borderRadius: <number>`. Tokens: 0, 6, 10, 14, 20, 28, and any value from 999 up as the pill (`--h-radius*` in `design/web/src/styles/tokens.css`, `kHermesRadius`, overlay 28) |
| `a.font` | `style.font.role`, `style.font.offRole` | any numeric `fontSize:`. Role sizes are 34, 28, 22, 17, 15, 13, 12; any other (12.5, 11.5, 13.5) is off-role. Both count |
| `a.elevation` | `style.elevation` | `elevation:` with a non-zero literal, and `BoxShadow(`. The theme draws no shadows |
| `b.dialog` | `style.dialog` | `showDialog`, `showCupertinoDialog`, `showModalBottomSheet`, `showCupertinoModalPopup`, `showGeneralDialog`, `showAdaptiveDialog`, `AlertDialog(`, `CupertinoAlertDialog(` outside `dialog_presentation.dart` and `adaptive_sheet.dart`. Use `showAppDialog` or `showAdaptiveSheet` |
| `c.adaptive` | `style.adaptive` | plain `Switch`, `Slider`, `Checkbox`, `CircularProgressIndicator`, `Radio`, `SwitchListTile`, `CheckboxListTile`, `RadioListTile`. `.adaptive` constructors do not count |
| `d.string` | `style.string` | user-visible English in a file that imports flutter material, widgets or cupertino: the first argument of `Text`/`SelectableText`, `TextSpan(text:)`, `Tooltip(message:)`, and `label:`, `tooltip:`, `hintText:`, `labelText:`, `helperText:`, `semanticLabel:`, `semanticsLabel:`, `hint:`, `title:` given a string literal (a `Text` in a `title:` counts once, as the Text). The literal needs two characters and an ASCII letter outside interpolation. Use `context.l10n` |

Informational, not in S: `a.duration` (`style.duration`, `Duration(..)` literal given to a
`duration`-like argument; no duration tokens exist yet) and `a.iconSize`
(`style.iconSize`, literal `size:` of `Icon`/`AppIcon`, and `iconSize:`; no icon-size
token exists yet).

Decisions and limits:

- The spacing scale is provisional (no spacing token yet): 0, 2, 4, 6, 8, 12, 16, 20,
  24, 32, 40, 48, 56, 64. It is the const `spacingScale` in `tool/style_score/scanner.dart`;
  change it there when a token lands. 10 and 14 are off-scale on purpose.
- A plain `Switch` counts even though the theme has `_AppleSwitchAdaptation`: that
  adaptation only recolours the track and thumb of the Material switch (it does not make
  it a Cupertino switch), so on iOS and macOS a plain `Switch` still draws Material.
- `showAdaptiveDialog` counts as a bypass of `showAppDialog` (it skips the macOS path).
- Syntactic only: constants (`kGap`, `kHermesRadius`), computed values (`base * 2`) and dot
  shorthands (`.all(8)`) are not seen. A `SizedBox` used as a fixed-size box inside a
  list still counts as a gap if it is childless. `d.string` also counts non-UI strings that
  happen to sit in a `label:` or `title:` argument; a brand name such as the app title is
  a candidate for the allowlist.
- A call through an import prefix (`import '...' as material;`, then
  `material.showDialog(..)`) is read as the plain call, for every rule. A prefix is
  recognised only when the same file declares it.
- `BoxShadow(` stays counted in `a.elevation` even when its blur and offset are zero, and
  `Colors.primaries` / `Colors.accents` stay counted in `a.color`: both are hard-coded
  values. Two kanban empty-state offsets (`kanban_screen.dart`, `kanban_workers_screen.dart`)
  are real off-scale literals and stay counted.
- Brand-name-only strings (`'Hermes'` as the app title, the sidebar and navigation header,
  the quick panel title, the dictation engine option) are allowlisted with a reason; a
  sentence that merely contains a product name is not.
- Contrast: a contrast-violation count over the catalog is planned and will join the
  rule list here.

### Adding an exception

Edit `tool/style_score_allowlist.yaml`. A reason is required (the tool exits with an error
without one). Match by file, category and a part of the printed snippet, not a line number:

```yaml
allow:
  - path: lib/src/app.dart
    category: d.string
    match: "title: 'Hermes'"
    count: 1            # hits the entry silences; default 1
    reason: The product name is not translated.
```

An entry that matches fewer hits than its `count` is printed as an unused warning. Remove
it. Prefer fixing the code to adding an entry.

## Tap targets T: `scripts/tap-report.sh`

```bash
scripts/tap-report.sh              # workflow screens, then the Widgetbook catalog
WORKFLOWS=0 scripts/tap-report.sh  # catalog only (deletes build/tap_targets first)
WORKFLOWS=0 KEEP_WORKFLOWS=1 scripts/tap-report.sh  # catalog only, reusing (KEEP_WORKFLOWS=1 without WORKFLOWS=0 is an error) the last workflow data
```

A failing workflow test does not abort the run: the script prints a warning that some
workflow tests failed (their screens may be missing), still measures the catalog, and
exits non-zero at the end only in that case.

`test/tap_targets/tap_target_report.dart` is named without `_test`, so `flutter test` and
the CI shards skip it. It never fails on a violation. It writes
`build/tap_targets/report.json` and prints per-platform totals and the top offenders.
Every violation is listed as `platform  source  label  WxH`, collected by
`test/support/tap_targets.dart`, which walks the semantics tree like flutter_test's tap
guidelines but does not stop at the first failure.

- A use case that wraps its content in a `Theme` with a fixed `platform` (names like
  "/ Android", "(iPhone)", "(Mac)") is judged only by the pass whose platform matches; the
  other passes are recorded as skipped (a use case showing several platforms side by side is measured in each matching pass) with the reason `pins <platform>` and listed under
  `passesSkipped`. Desktop platforms count as macOS. A phone-sized pass of a desktop layout
  is not special-cased.
- Every Widgetbook use case, light theme, three passes: Android (48 dp) and iOS (44 pt) on
  390x844, macOS (28 pt) on 1280x800. Use cases that throw are skipped (the catalog test
  owns them).
- Workflow screens: with `HERMES_TAP_REPORT=1`, `ScreenshotRecorder.capture` measures the
  screen and appends it to `build/tap_targets/workflows/<flow>.jsonl`; the script runs all
  of `test/workflows`. A screen is judged by the macOS minimum when its window is 700
  logical pixels wide or more, else by the platform its theme was built for (the test's
  `platform:`, `WORKFLOW_PLATFORM`, or Android when neither is set); a phone-sized screen
  built for another platform is skipped and listed under `screensSkipped`.
- Headline numbers: `totals` counts distinct (platform, screen with the theme suffix
  `-dark`/`-light` of its flow dropped, label, size, position rounded to 1 px), so the
  same control in light and dark counts once while ten identical buttons at ten places
  count ten; `rawTotals` counts every render. T is a lower bound: nodes touching the
  window or a scrollable's edge are skipped, and use cases are measured in the light
  theme only. Zero-area nodes and nodes fully outside the
  window are not targets.
- Also reported: tap targets without a label or tooltip (`labeledTapTargetGuideline`'s
  rule), and macOS targets exactly 44 or 48 wide or high (`macosInflated`: Material's
  `kMinInteractiveDimension`, which a pointer does not need).
- No per-file attribution: a semantics node does not carry its widget's creation
  location, so a finding names its screen or use case, label and size.

Limits: like the guidelines, it skips merged nodes, links, text fields, nodes touching the
window edge or a scrollable's edge, and anything not mounted (lazy list rows below the
fold, closed menus and dialogs, states a use case does not show). Workflow screens are
measured only where a test calls `capture`, at that test's platform and theme.

## Ratchet

`test/architecture/style_ratchet_test.dart` registers the counted rules (`style.color`,
`style.spacing`, `style.radius`, `style.font.role`, `style.font.offRole`,
`style.elevation`, `style.dialog`, `style.adaptive`, `style.string`) with
`ratchetTests(..., namespace: 'style')`. It runs the same scan and allowlist as the CLI
(`tool/style_score/measure.dart`) and compares per rule and file with
`test/architecture/baseline.yaml`. `style.duration` and `style.iconSize` are not ratcheted.
General API: the `architecture-guards` skill.

- **A count rises, or a new file has a hit:** the test fails with `path:line: snippet` and
  the building block to use instead (named in the message). Use it. Never raise or add a
  baseline entry.
- **A count falls:** the test fails with the exact edit ("lower style.color <path> to N" or
  "remove the entry"). Make it, or run
  `UPDATE_BASELINE=1 flutter test --concurrency=1 test/architecture`, which only lowers
  and removes. Commit `baseline.yaml`.
- **A legitimate exception** (a brand name, a platform boundary): add an entry to
  `tool/style_score_allowlist.yaml` with a reason (see Adding an exception). The CLI and
  the ratchet both skip it, so the baseline does not change. Say why in the PR.
- Baseline totals per rule equal the CLI's per-category counts (`font` is split into
  `font.role` and `font.offRole`).

Still planned: a contrast-violation count over the catalog.
