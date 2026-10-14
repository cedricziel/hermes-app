# Proposal

## Why

The app's widgets can only be seen inside a running app or a workflow test, and both need a whole screen wired to a fake backend. Looking at one card in every state (running, failed, answered, expired), in light and dark, on phone and desktop, is slow. A component catalog makes that a single window. Published as a web page, it also lets designers and reviewers look at the components without a Flutter toolchain, and it is the seed for a design-system project on claude.ai/design later.

## What Changes

- Add [Widgetbook](https://pub.dev/packages/widgetbook) (Flutter's counterpart to Storybook) as a dev dependency and a `widgetbook/` entry point, run with `flutter run -d macos -t widgetbook/main.dart`.
- Write the catalog by hand, without the annotation generator and `build_runner`.
- Ship a first set of use cases: the colour palette and theme, `ToolCallCard`, `ApprovalCard`, `ClarifyCard`, `ThinkingIndicator` and `KanbanCard`, each in its meaningful states.
- Add addons for light/dark, text scale and phone/desktop viewports, so each use case shows the same variations the workflow tests cover.
- Build the catalog for the web with `scripts/build-widgetbook.sh` and publish it to GitHub Pages from `main` with a new `widgetbook.yml` workflow. Pull requests build it without publishing.
- Add a smoke test that builds every use case in both themes, so the catalog cannot rot silently.
- Document the workflow, including the published address, in a new `component-catalog` project skill, and make it the place where UI work starts: components are built and tuned there first, then wired into screens.

## Capabilities

### New Capabilities

None. The catalog is developer tooling and does not change what the app does, so the change sets `skip_specs: true`.

### Modified Capabilities

None.

## Impact

- New: `widgetbook/` (entry point, use cases, fixtures, a `web/` page template), `scripts/build-widgetbook.sh`, `.github/workflows/widgetbook.yml`, `test/widgetbook_test.dart`, `.claude/skills/component-catalog/SKILL.md`.
- Changed: `pubspec.yaml` and `pubspec.lock` (one dev dependency, `widgetbook`), `CLAUDE.md` (a line under Commands).
- Release builds are unchanged. A dev dependency is not part of the app, and nothing in `lib/` imports the catalog.
- Widgets may need small changes so they can be built without a controller or repository. Any such change must keep behaviour identical.

## Non-goals

- Adding a web platform to the app. The `web/` folder the build needs is created for the length of the build and removed again; the app is still not built for the web.
- Visual regression with golden images.
- Syncing components to claude.ai/design. That needs a separate export step and a design-system project to write to.
- Catalog entries for whole screens, or anything that needs a live `AuthController` or a backend. The workflow tests keep covering those.
- Adopting Widgetbook's cloud review service.

## Security and privacy impact

None. The catalog uses made-up data only, holds no tokens, and is never built into a release. The published page is public (the repository is public), so it must never contain anything that is not meant to be seen; fixtures are invented and reviewed like any other code. The workflow has `pages: write` and `id-token: write` only on the deploy job and deploys from `main` only. The URL a Git install would use, server addresses and tokens never appear in a fixture.

## Telemetry

None. The catalog does not start the OpenTelemetry SDK, so no spans or log events are emitted.
