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
  `test/app_theme_scopes_test.dart` enforces it. It derives the readers from
  `lib/` (every class, function, getter or extension that reads `mui.Theme.of`,
  draws `GptMarkdown`, or mentions one that does; the navigation-only roots
  `AppShell`, `MacProfilesPage` and `HermesApp` do not count). A `*_test.dart`
  file fails, naming the file and the readers, when it references one and builds
  an app that mounts nothing: no `AppThemeScopes(`, `MaterialUiThemeScope(`,
  `FlyerMaterialScope(` or `mui.Theme(` call in its `builder:` outside a `?`/`:`
  conditional, and none that is the whole `home:` expression (a scope inside a
  `home:` subtree covers only that part), or calls a
  helper (any function or class under `test/` outside `*_test.dart` files) whose
  app does not. A mention in a string, an import or a `find.byType` does not
  count, and one mounted app does not excuse another in the same file. The guard scans
  `test/` only; `benchmark/` apps are out of its scope. Add new app-level
  theme scopes inside `AppThemeScopes`. `test/app_theme_scopes_test.dart` compares
  the theme-like inherited widgets above the `Navigator` in `HermesApp` and
  `pumpScreen` (a scope added in `app.dart` that the harness lacks fails it; a
  chrome-only inherited widget goes on its `_notTheme` list) and, as a source check
  (comments stripped, a file may not build more `MaterialApp`, `.router`,
  `CupertinoApp` or `WidgetsApp` constructors than `AppThemeScopes(` calls), that
  every app in `lib/` (the conversation window and quick panel engines too)
  mounts it. It does not catch a scope added between the `Navigator` and a
  route, or a value changed inside an existing type such as `scrollBehavior`.
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
