---
name: workflow-screenshots
description: Use when adding or changing a workflow test (test/workflows/), when a screen should be looked at for rendering problems without a running backend, or when a workflow screenshot looks wrong (black boxes, hard black borders, half-scrolled chat).
---

# Workflow tests with screenshots

`test/workflows/*_workflow_test.dart` walk a user flow through the real widgets
(onboarding, chat, kanban, skills/bots/settings) and write a numbered PNG at
each step to `build/workflow_screenshots/<flow>/NN-name.png` (`WORKFLOW_SHOTS_DIR`
overrides it; CI uploads it as the `workflow-screenshots` artifact). They run
with plain `flutter test`, on phone (`phoneSize`) and desktop (`desktopSize`),
light and dark. Read the PNGs to look for overflow, clipping, contrast and
alignment problems; the tests themselves only assert that the flow still runs.

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
