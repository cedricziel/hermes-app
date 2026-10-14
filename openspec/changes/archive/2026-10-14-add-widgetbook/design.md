# Design

## Context

The app is one Flutter package (`hermes_app`) with `flutter_otel` git overrides in `dependency_overrides`. Widgets under `lib/src/*/widgets/` take plain model objects (`ToolCall`, `ApprovalRequest`, `KanbanTask`), so most can be built in isolation. Theme comes from `buildHermesLightTheme()` and `buildHermesDarkTheme()`. Test fixtures live in `test/support/`, which `lib/` cannot import. There is no `web/` platform, and `flutter build web` needs a `web/` folder in the project root. `flutter create --platforms=web` would also edit `analysis_options.yaml` and `.metadata`. See proposal.md for why. A trial `flutter build web -t widgetbook/main.dart --release` compiles, so the widgets under catalog reach no `dart:io`-only code.

## Goals / Non-Goals

**Goals:**
- The catalog is published on GitHub Pages, rebuilt when `main` changes.
- One command opens a window listing components, each in its states, switchable between light/dark, text scale and phone/desktop width.
- The catalog fails CI when a use case stops building.
- No change to release builds.

**Non-Goals:**
- Golden images and design sync (see proposal.md).

## Decisions

**Catalog lives in the app package, at `widgetbook/`, with `widgetbook` as a dev dependency.**
A separate package would need the `dependency_overrides` copied and kept in step with the app's, and a path dependency on `hermes_app` drags every app dependency in anyway. In the app package the catalog imports `package:hermes_app/...` and resolves with the same lockfile. Alternative: a `widgetbook/` package of its own. Rejected for the override duplication.

**Hand-written directories, no `widgetbook_generator`.**
`widgetbook/directories.dart` lists `WidgetbookComponent`s and `WidgetbookUseCase`s directly. The generator would add `build_runner`, a generated file to commit or verify in CI, and a second code-generation flow next to the API client's. With about six components a list is shorter than the machinery. Revisit when the catalog passes roughly 30 use cases.

**Addons: `MaterialThemeAddon`, `TextScaleAddon`, `ViewportAddon`.**
The theme addon is fed the two theme builders from `lib/src/theme/hermes_theme.dart`, so the catalog can never show a look the app does not have. Viewports are a phone and a 900 px desktop width, the same split the app uses for its detail panes.

**Fixtures are local to `widgetbook/`.**
`lib/` cannot import `test/support/`, and the test fixtures are shaped for backend responses, not widget states. `widgetbook/fixtures.dart` holds a few domain objects per state (a running, a finished and a failed tool call; a pending, answered and expired approval). All text is invented.

**Use cases build the widget alone, with callbacks that resolve after a short delay.**
Interactive cards (`ApprovalCard`, `ClarifyCard`) take an `onAnswer` future, so a use case passes one that completes, and one that throws to show the failure message. If a widget cannot be built without a controller or repository, the fix is a small change to the widget's constructor in the same PR, with its existing tests still passing. A use case never builds a fake repository.

**Smoke test at `test/widgetbook_test.dart`.**
It walks the `directories` list, pumps every use case inside a themed `MaterialApp` in each theme and viewport of `widgetbook/environment.dart` (the same list the catalog's addons use), and fails on a thrown exception or an overflow. Text scale is left to the catalog itself: the test renderer's font is wider than the real one and exaggerates overflow. Directories are plain Dart objects, so no widgetbook app or platform channel is needed. Alternative: only rely on `flutter analyze`. Rejected, because analyze does not catch a use case that throws while building.

**The web build is a script, and `web/` is not committed.**
`widgetbook/web/` holds an `index.html` and a favicon. `scripts/build-widgetbook.sh` copies them to `web/`, runs `flutter build web -t widgetbook/main.dart --release --base-href "$BASE_HREF"` into `build/web`, and removes `web/` again (also on failure). CI and a developer run the same script. Alternatives: commit a `web/` platform (adds a platform the app does not ship, and its icons and manifest to keep up); run `flutter create` in CI (edits tracked files and hides the page's content in a generated default). Wasm is not used: `flutter_secure_storage_web` is not wasm-compatible, and the default build is enough.

**Pages deploys from a separate workflow, `widgetbook.yml`.**
It runs on pull requests and pushes that touch `widgetbook/`, `lib/`, `pubspec.*` or the script, on a push to `main`, and by hand. A `build` job builds the site and uploads it as the Pages artifact; a `deploy` job, only on `main`, publishes it with `actions/deploy-pages` to the `github-pages` environment. A pull request therefore proves the web build still works and publishes nothing. The base href is `/<repository name>/`. Alternative: a job in `ci.yml`. Rejected: it would slow the required checks and mix a deploy into them. Repository Pages must be set to the "GitHub Actions" source once.

**Run locally on a desktop target.**
`flutter run -d macos -t widgetbook/main.dart`, as the app itself. Building macOS rewrites tracked `ios/` and `macos/` Xcode files, so the skill repeats the CLAUDE.md rule: stage by name and `git restore` them afterwards.

## Platforms and invariants

- Platforms: none affected in a shipped build; the web is a build target for the catalog only. The catalog is run on macOS, Linux or Windows by a developer. No entitlement, manifest or Xcode project change.
- Invariants: telemetry stays off (the catalog never calls `main.dart`'s setup, so no SDK exists and nothing is exported). No auth, token or API layering code is touched.

## Risks / Trade-offs

- [The catalog drifts from the widgets] → The smoke test builds every use case on each CI run; a signature change breaks it.
- [A dev dependency slows `pub get` or conflicts with a pinned package] → `widgetbook` is small and depends on `url_launcher` and a few UI helpers. Check `flutter pub get` and the lockfile diff in the first task, and stop if it wants to move a pinned package.
- [A widget starts importing something that does not compile for the web] → The pull request build fails on the web build, before it reaches `main`.
- [The public page shows something private] → Fixtures are invented; the skill says so; the page is built from `widgetbook/` alone.
- [Widgets tied to controllers cannot be shown] → Start with the ones that take plain models; leave the rest out rather than faking a repository.
- [Manual directories get long] → Split by feature file (`chat_use_cases.dart`, `kanban_use_cases.dart`); adopt the generator later if it hurts.

## Open Questions

None.
