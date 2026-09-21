# Tasks

Type and scope for the PR: `chore(dev): component catalog with Widgetbook, published to GitHub Pages` (about 520 changed lines).

## 1. Setup

- [x] 1.1 Add `widgetbook` to `dev_dependencies` and run `flutter pub get`; verify the `pubspec.lock` diff moves no existing package and `flutter analyze` is still clean
- [x] 1.2 Add `widgetbook/main.dart` with `Widgetbook.material`, the light and dark themes from `hermes_theme.dart`, the text-scale addon and phone/desktop viewports, and an empty `directories` list; verify `flutter analyze` passes

## 2. Smoke test first

- [x] 2.1 Write `test/widgetbook_test.dart` walking `directories` and pumping every use case in light and dark inside a themed `MaterialApp`; verify it fails against a deliberately throwing use case, then remove that use case

## 3. Use cases

- [x] 3.1 Add `widgetbook/fixtures.dart` with invented domain objects per state; verify by using them in 3.2 to 3.4
- [x] 3.2 Add the palette and theme use case (`HermesColors` swatches and the main text styles); verify the smoke test passes and the window shows both themes
- [x] 3.3 Add chat use cases: `ToolCallCard` (running, finished, failed), `ApprovalCard` (pending, answered, expired, answer fails), `ClarifyCard` (choices, free text) and `ThinkingIndicator`; verify the smoke test passes
- [x] 3.4 Add the `KanbanCard` use case (with and without tags and meta); verify the smoke test passes
- [x] 3.5 If a widget cannot be built without a controller, make the smallest constructor change that lets it be, with its existing test unchanged and passing; skip the widget if that is not small

## 4. Docs and skills

- [x] 4.1 Add `.claude/skills/component-catalog/SKILL.md` (run command, how to add a use case, the Xcode-file `git restore` trap) and point `workflow-screenshots` and `verify-in-app` at it where they overlap
- [x] 4.2 Add the run command under Commands in `CLAUDE.md`
- [x] 4.3 Telemetry: none to add (see proposal); verify no file under `widgetbook/` imports `lib/src/telemetry/`

## 5. Publish

- [x] 5.1 Add `widgetbook/web/` (page and favicon) and `scripts/build-widgetbook.sh`; verify `BASE_HREF=/hermes-app/ scripts/build-widgetbook.sh` writes `build/web/index.html` and leaves no `web/` folder and no tracked file changed, also when the build fails
- [x] 5.2 Add `.github/workflows/widgetbook.yml` (build on pull request and `main`, deploy on `main` only); verify the pull request run builds and the deploy job is skipped
- [ ] 5.3 Set the repository's Pages source to "GitHub Actions" and, after merge, verify the `deploy` job succeeds and the page loads at `https://cedricziel.github.io/hermes-app/`
- [x] 5.4 Add the address and the build script to the `component-catalog` skill and `CLAUDE.md`; verify both mention them

## 6. Verify

- [x] 6.1 Run `dart format .`, `flutter analyze` and `flutter test`; verify all pass
- [ ] 6.2 Run `flutter run -d macos -t widgetbook/main.dart`, switch theme, text scale and viewport on each component, and screenshot the window (verify-in-app loop); verify no overflow or contrast problem, then `git restore` the rewritten `ios/` and `macos/` files
