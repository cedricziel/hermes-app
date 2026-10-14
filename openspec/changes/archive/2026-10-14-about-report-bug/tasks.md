# Tasks

## 1. Shared "Report a bug" link

- [x] 1.1 Write a widget test for `ReportBugLink` (new, in
      `lib/src/settings/report_bug_link.dart`) asserting tapping it invokes an injected
      link opener with `https://github.com/cedricziel/hermes-app/issues`, and that a
      failed launch (opener returns/throws failure) does not throw; make it fail first
      (no widget exists yet), then implement `ReportBugLink` to pass it. Default the
      opener to `launchUrl(uri, mode: LaunchMode.externalApplication)`, mirroring the
      "Read the VPN setup guide" `TextButton` in
      `lib/src/screens/server_setup_screen.dart`.
      (`test/settings/report_bug_link_test.dart`)
- [x] 1.2 Add a `WidgetbookUseCase` for `ReportBugLink` (fixed no-op link opener) and verify
      `flutter test test/widgetbook_test.dart` passes in both themes.

## 2. About dialog

- [x] 2.1 Write a widget test for the About dialog widget (new, in
      `lib/src/settings/about_dialog.dart`) asserting it shows the app's version and a
      `ReportBugLink`; make it fail first, then implement it. Accept version as an
      injected parameter, and reuse `ReportBugLink`'s own default opener rather than
      re-implementing link opening.
      (`test/settings/about_dialog_test.dart`. Named `AppAboutDialog` /
      `showAppAboutDialog`, not `AboutDialog` / `showAboutDialog` as originally
      written here — those names collide with Flutter's own `material.dart`
      exports and would be an `ambiguous_import` everywhere both are imported.)
- [x] 2.2 Write `showAppAboutDialog(BuildContext)` in the same file, loading the version via
      `PackageInfo.fromPlatform()`, mirroring `showAppearanceDialog` in
      `lib/src/settings/appearance_dialog.dart`. Verify `flutter analyze` is clean.
      (Also moved `package_info_plus` from `dev_dependencies` to `dependencies` in
      `pubspec.yaml` — it was dev-only and unused by `lib/`, so `flutter analyze`
      caught it as `depend_on_referenced_packages`.)
- [x] 2.3 Add an "About" `WidgetbookUseCase` next to Appearance/Notifications/App lock in
      `widgetbook/app_use_cases.dart`'s `Dialogs` component, using a fixed fake version.
      Verify `flutter test test/widgetbook_test.dart` passes in both themes.
- [x] 2.4 Write a widget test on `AccountFooter` (`lib/src/chat/widgets/thread_sidebar.dart`)
      asserting selecting "About" from the popup menu opens the About dialog; make it fail
      first, then add the `PopupMenuItem` (value `'about'`) and the `onSelected` branch
      calling `showAppAboutDialog(context)`.
      (`test/about_setting_test.dart`, mirroring `test/appearance_setting_test.dart`.)

## 3. Setup and sign-in screens

- [x] 3.1 Write a widget test on `ServerSetupScreen` asserting a `ReportBugLink` is shown
      at the bottom of the screen; make it fail first, then add it below the "Connect"
      button in `lib/src/screens/server_setup_screen.dart`.
- [x] 3.2 Write a widget test on `LoginScreen` asserting a `ReportBugLink` is shown; make it
      fail first, then add it in `lib/src/screens/login_screen.dart`, placed outside every
      conditional branch so it renders in every state (loading, provider list, error,
      unsupported server) rather than duplicated into each branch. One widget test covers
      the representative "provider list" state; `test/widgetbook_test.dart` additionally
      builds all three `LoginScreen` use cases (Provider, Signing in, Sign-in failed) and
      confirms none throw with the link present.
- [x] 3.3 Add or extend Widgetbook use cases for `ServerSetupScreen` and `LoginScreen` so
      the new link is visible in the catalog. Verify `flutter test test/widgetbook_test.dart`
      passes in both themes.
      (No new use cases needed — the existing `ServerSetupScreen` and `LoginScreen`
      use cases in `widgetbook/app_use_cases.dart` render the real screens, so they
      picked up `ReportBugLink` automatically. Confirmed visually via a headless
      Chromium screenshot of the built `widgetbook/` web catalog.)

## 4. Verify

- [x] 4.1 Run `dart format .`, `flutter analyze`, `flutter test` and confirm all pass.
      (`dart format --output=none --set-exit-if-changed .`: clean. `flutter analyze`:
      no issues. `flutter test`: full suite green, 3115 passed.)
- [ ] 4.2 Use `verify-in-app` to check: the account menu's "About" entry shows the version
      and opens the issues page; the server-setup screen's link opens the issues page; the
      sign-in screen's link opens the issues page.
      **Not done.** This session's environment cannot grant macOS Screen Recording
      permission, so `scripts/dev-app.sh screenshot` (`screencapture -l <window>`)
      fails outright (`could not create image from window`), and `hermes` is not on
      PATH to stand up `scripts/dev-backend.sh` either. Verified instead with a
      headless Chromium screenshot of the built `widgetbook/` web catalog (real
      widget code, real rendering, not a mock), plus the widget/unit tests above.
      Actually tapping "Report a bug" against a live browser launch was not checked
      end-to-end anywhere. Run this task in an environment with `hermes` on PATH and
      normal Screen Recording permission before calling the change fully verified.
