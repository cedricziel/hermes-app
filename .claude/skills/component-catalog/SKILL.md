---
name: component-catalog
description: Use when building or changing any UI in hermes-app (a new widget, a redesign, a layout or state change), when a widget should be looked at in isolation (every state, light and dark, phone and desktop), when adding a use case to the Widgetbook catalog in widgetbook/, or when test/widgetbook_test.dart fails.
---

# Component catalog (Widgetbook)

`widgetbook/` is a catalog of single widgets in each of their states, not a
screen of the app. Use it to look at a card or a row without a backend, a
controller or a workflow test. Whole flows stay in `test/workflows/`
(`workflow-screenshots` skill).

## Iterate here first

UI work starts in the catalog, not in a screen. Build or change the widget as
a use case, get every state and both themes and viewports right there, and only
then wire it into a screen. A component that takes plain models and callbacks
(no controller, no repository) can be dropped into any screen later, and into
a design tool. If a widget only works inside a screen, that is the thing to
fix. Widgets that a screen builds inline should be pulled out into
`lib/src/*/widgets/` so they can have use cases.

## Run it

```bash
flutter run -d macos -t widgetbook/main.dart
```

The sidebar lists components and use cases. The addons panel switches light and
dark (the app's own `buildHermes*Theme`), text scale and phone/desktop width.
Building for macOS rewrites tracked `ios/` and `macos/` Xcode files: stage
files by name and `git restore` those afterwards.

## Published page

`.github/workflows/widgetbook.yml` builds the catalog for the web and
publishes it from `main` to https://cedricziel.github.io/hermes-app/. A pull
request builds it without publishing, so a widget that stops compiling for the
web fails there. Build it yourself with `BASE_HREF=/ scripts/build-widgetbook.sh`
(output in `build/web`, serve it with `python3 -m http.server`). The script
creates `web/` only for the build; the app has no web platform, so never commit
one. Everything on the page is public: fixtures stay invented.

A use case can be opened by link, for example
`.../#/?path=chat/approvalcard/pending&theme={name:Dark}`. The path is the
lower-cased names with `-` for spaces.

## Add a use case

1. Add invented sample data to `widgetbook/fixtures.dart`. Never a real server
   address, token or message; `lib/` cannot import `test/support/`.
2. Add a `WidgetbookUseCase` in the feature's `*_use_cases.dart` and list its
   component in `widgetbook/directories.dart`. Wrap the widget in `frame(...)`.
3. Cover the states a user can see: empty, running, failed, answered, expired.
   Pass callbacks that resolve (`Future.delayed`) or throw, so the buttons work.
4. `flutter test test/widgetbook_test.dart`. It builds every use case in each
   theme and viewport of `widgetbook/environment.dart` and fails on an
   exception or an overflow. The test font is wider than the real one, so
   check text scale in the catalog (Addons panel), not in the test.

## Rules

- Directories are written by hand; there is no `widgetbook_generator` and no
  `build_runner`.
- A use case builds the widget alone. If it needs a controller or a repository,
  make a small constructor change on the widget (its tests unchanged) or leave
  it out. Do not fake a repository here.
- Keep knobs out for now: the smoke test builds use cases without a
  Widgetbook state, so `context.knobs` would throw.
- Nothing under `widgetbook/` may import `lib/src/telemetry/`; the catalog
  starts no SDK.
