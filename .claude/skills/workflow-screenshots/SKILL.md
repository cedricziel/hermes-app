---
name: workflow-screenshots
description: Use when adding or changing a workflow test (test/workflows/), when a screen should be looked at for rendering problems without a running backend, or when a workflow screenshot looks wrong (black boxes, hard black borders, half-scrolled chat).
---

# Workflow tests with screenshots

`test/workflows/*_workflow_test.dart` walk a user flow through the real widgets
(onboarding, chat, kanban, skills/messaging/settings) and write a numbered PNG at
each step to `build/workflow_screenshots/<flow>/NN-name.png` (`WORKFLOW_SHOTS_DIR`
overrides it; CI uploads one `workflow-screenshots-<shard>` artifact per test shard that wrote any). They run
with plain `flutter test`, on phone (`phoneSize`) and desktop (`desktopSize`),
light and dark. Read the PNGs to look for overflow, clipping, contrast and
alignment problems; the tests themselves only assert that the flow still runs.

`WORKFLOW_SIZE=320x568` and `WORKFLOW_TEXT_SCALE=2.0` (with `WORKFLOW_PLATFORM=iOS`)
rerun any workflow at a small phone and large text. Run one test by
`--plain-name`: flows that tap rows below the fold stop at the first tap that
misses, which is the harness, not an overflow; overflow shows as a
`RenderFlex overflowed` failure.

To see one widget in every state without a flow around it, use the
`component-catalog` skill (Widgetbook) instead.

## Writing one

- `test/support/screenshot_recorder.dart`: `ScreenshotRecorder(flow)`, then
  `await shots.start(tester, size)` first, `shots.frame(app)` around the app,
  `shots.capture(tester, 'name')` at each step.
- `test/support/workflow_app.dart`: `pumpScreen` mounts one screen in a themed
  `MaterialApp`; `pumpWorkflowApp` mounts the whole `HermesApp` (needs a
  `LocalDashboard` from `test/support/local_dashboard.dart`, a real loopback
  socket, because `AuthController` builds its own Dio).
- Everything else is the usual fakes: `FakeHermesServer`, `FakeChatTransport`.
- Set `SharedPreferencesAsyncPlatform.instance` before constructing an
  `AuthController` or `AppLockController`.

## Traps

- Third-party widgets that read a theme from a scope (`gpt_markdown` reads
  `material_ui`'s) need the app's `AppThemeScopes` (`lib/src/theme/material_ui_bridge.dart`).
  `HermesApp`, `pumpScreen` and the Widgetbook catalog all mount that one widget;
  a hand-built test app (`MaterialApp`, `CupertinoApp`, `WidgetsApp`, or a helper
  such as `pumpChatScreen`, `pumpOnPlatform` or `pumpFiles` that builds one) that
  renders markdown, code, files or skills widgets must mount `AppThemeScopes` in
  its `builder:`. Without it `mui.Theme.of` does not throw but falls back to the
  light theme, so dark markdown headings draw near-black (1.17:1) and code blocks
  draw light on a dark page, in the screenshot and never in the app.
  `test/app_theme_scopes_test.dart` enforces it. It reads the sources with the
  analyzer's unresolved syntax tree (`parseString`, no analysis context, nothing
  resolved), so it sees names and shapes, not types. It derives the readers from
  `lib/` (every class, function, getter or extension that reads `mui.Theme.of`,
  draws `GptMarkdown`, or mentions one that does; the navigation-only roots
  `AppShell`, `MacProfilesPage` and `HermesApp` do not count). A `*_test.dart`
  file fails, naming the file and the readers, when it references one and builds
  an app that mounts nothing, or calls a helper (any function or class under
  `test/` outside `*_test.dart` files) whose app does not. A mention in a string,
  an import or a `find.byType` does not count, and one mounted app does not
  excuse another in the same file. The guard scans `test/` only; `benchmark/`
  apps are out of its scope.
  - What mounts: an `AppThemeScopes(`, `MaterialUiThemeScope(`,
    `FlyerMaterialScope(` or `mui.Theme(` call in the app's `builder:` that wraps
    the builder's child (its second parameter) and has no `?:`, `switch`, `if`
    statement or collection `if` between it and the builder. A scope in `home:`
    never counts (a route pushed from `home` is built outside it), nor does one
    beside the child (`Stack(children: [AppThemeScopes(...), child!])`). A
    `builder: _scoped` tear-off counts when every function or method named
    `_scoped` in the same file mounts by those rules. An app is a bare or
    import-prefixed (`m.MaterialApp(`) `MaterialApp`, `.router`, `CupertinoApp`
    or `WidgetsApp`, with or without `const`.
  - What an unmounted app draws: the readers in its own test (the narrowest
    `test`, `testWidgets` or `group` callback around it; the whole file when it
    is in none) and the readers built around the tests of every group it is in:
    a `setUp` or `setUpAll` (also of an outer group), a local or closure of
    `main` or a `group`, a `for` loop over widgets, a top-level helper of the
    test file. A reader found there is reported with where it is built, for
    example `BoundedMarkdown (reader built in setUp at line 12)`. Sibling `test`,
    `testWidgets` and `group` callbacks stay out, and so does the `setUp` of a
    sibling or nested group, so a localization-only app beside another test that
    reads the theme passes.
  - An extension member (`context.surface`) is a getter, setter or method that
    the extension declares, read from its syntax tree; it counts as a reader use
    only in a file that is in the extension's library or imports it. Imports and
    `part of` are read from the string literal, so `import r'package:...'` works.
  - A test that leaves its app unmounted on purpose (the unbridged fallback)
    goes on the `_exemptions` list in the guard, with the path, the text of the
    app and a one-line reason; a test asserts each entry is still an offender,
    so remove it once it no longer applies. Never hide a conditional mount from
    the guard by rewriting it.
  - Known gaps, left as they are: a bare word is matched by name across files
    (two classes of the same name in two libraries are one reader); `export`
    barrels are not followed, so a library re-exported elsewhere is seen only
    through its own imports; a function that returns a record of widgets is not
    followed; a tear-off is looked up by name in its own file only (not through a
    `part`, an import or a local variable). A mount that depends on a condition
    on a reference to the scope (`final s = AppThemeScopes(child: child!);
    return on ? s : child!;`) or on an early `return child!` before it is not
    caught; these are on the roadmap. Reader names, seeds and finders are still
    matched as words in the comment-free text of the range the syntax tree gives
    (`_wordsPattern`, `_seed`), not as nodes.
  - A reader named in a test by a member (`t.md`, a getter of an extension)
    is reached through the members of the class or extension that holds it,
    and references are identifiers and type names in the syntax tree, so a
    label such as `body:` or a local inside a declaration is not one. Only a
    declaration around the tests is followed, as a whole.
  - A scope that wraps a local made of the child (`final content = child!;
    return AppThemeScopes(child: content);`) mounts, unless the local is
    assigned again or its value has a `?:`, `switch` or collection `if`; a
    local declared bare and assigned once (`Widget w; w = child!;`) does not
    count, which is conservative. Only the scope's
    `child:` counts, not its `key:`. A reader built around the tests counts
    only when a `setUp`, `setUpAll` or loop builds it, or when something the
    test refers to by name (transitively) does; a reader in a mounted app's own
    arguments, or in a declaration nothing refers to, is not blamed on another
    test. Every file the guard scans has to parse without errors; a fixture may
    be a bare snippet, a real file may not. If a Flutter or Dart bump brings
    syntax that the `analyzer` package cannot parse, that assertion fails with
    `path:line`; bump `analyzer`, do not change the file.
  - `the analyzer API canary` parses a snippet with every construct the guard
    reads (named arguments, bare and prefixed calls, constructions, extensions
    and their members, directives, conditionals, loops) and names the ones the
    parser no longer produces. If an `analyzer` major bump fails it, update
    `_Parsed`, `_Index`, `_shapes`, `_findApps`, `_bodyMounts` and
    `_declarations` to the new node types before trusting a green guard: a node
    that is no longer produced would make it see no apps and pass.

  Add new app-level theme scopes inside `AppThemeScopes`.
  `test/app_theme_scopes_test.dart` compares the theme-like inherited widgets
  above the `Navigator` in `HermesApp` and `pumpScreen` (a scope added in
  `app.dart` that the harness lacks fails it; a chrome-only inherited widget goes
  on its `_notTheme` list) and, as a source check, that a file in `lib/` does
  not build more apps (`MaterialApp`, `.router`, `CupertinoApp` or `WidgetsApp`,
  `HermesApp` aside) than it has `AppThemeScopes(` calls. That is a file-level
  count: it does not prove that each app mounts the scope (two apps and two scope calls pass
  even when one scope is in `home:`), so every app in `lib/` (the
  conversation window and quick panel engines too) still has to mount it in its
  `builder:`. It does not catch a scope added between the
  `Navigator` and a route, or a value changed inside an existing type such as
  `scrollBehavior`.
- Fonts must be loaded inside the test body (`shots.start` does it). Loaded in a
  `setUpAll` they are ignored, and all text is drawn as black boxes.
- Text with no font family (the AppBar title, some third-party widgets such as
  the markdown code block) still draws as boxes; `withScreenshotFont` fixes the
  theme's AppBar title, `HermesApp(lightTheme:, darkTheme:)` lets a whole-app
  flow use it. Code blocks stay boxes. That is the harness, not the app.
- The test binding draws every shadow as a hard black outline; `capture`
  repaints once with real shadows. A thick black rim around a FAB or menu in a
  screenshot means that repaint was skipped.
- Pump a chat frame by frame (`_runFrames` in `chat_workflow_test.dart`), not
  with one long `pump(Duration)`. One long pump skips frames the list needs and
  leaves the newest message or a request card scrolled out of view, which looks
  like an app bug and is not.
- A spinner never settles, so use `pump`, not `pumpAndSettle`, while one is on
  screen (waiting for the browser, a running tool, a pairing).
- Taps that miss are fatal in these tests (`hitTestWarningShouldBeFatal`), or the
  same screen would be captured again and again.
- A real socket needs `tester.runAsync`; `pumpUntilFound` does that. End such a
  test with `app.finish(tester)` so HTTP keep-alive timers are not left pending.
