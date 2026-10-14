# Proposal

## Why

The app has no way to tell users where to report a bug. There is no in-app link to
the project's issue tracker anywhere, and no screen shows the app's own version
number, which is the first thing an issue report needs. This matters most on the
server-setup and sign-in screens: a user stuck before ever reaching the chat UI
has no account menu to find help in, and a broken connect/sign-in is exactly the
kind of thing worth reporting.

## What Changes

- Add an "About" entry to the account menu (`AccountFooter` in
  `lib/src/chat/widgets/thread_sidebar.dart`), alongside the existing
  Appearance / Notifications / App lock entries.
- The entry opens an "About" dialog showing the app's version (via the
  already-present `package_info_plus` dependency) and a "Report a bug" action
  that opens `https://github.com/cedricziel/hermes-app/issues` in the external
  browser (via `url_launcher`, the same pattern used in
  `lib/src/plugins/catalog_tab.dart` and, for a link, in
  `lib/src/screens/server_setup_screen.dart`'s "Read the VPN setup guide").
- Add the same "Report a bug" link to the bottom of `ServerSetupScreen`
  (`lib/src/screens/server_setup_screen.dart`) and `LoginScreen`
  (`lib/src/screens/login_screen.dart`), the two screens shown before a user
  reaches the signed-in app and its account menu.

## Capabilities

### New Capabilities

- `about`: where a user finds the app's version and gets to the project's
  issue tracker to report a bug — from the About dialog (behind the account
  menu) and from the server-setup and sign-in screens (before sign-in).

### Modified Capabilities

(none — no existing capability's requirements change; the setup and sign-in
screens gain a link, not a change to how connecting or signing in behaves)

## Impact

- `lib/src/chat/widgets/thread_sidebar.dart`: new `PopupMenuItem` and
  `onSelected` branch in `AccountFooter`.
- New `lib/src/settings/about_dialog.dart` (mirrors
  `lib/src/settings/appearance_dialog.dart`).
- New shared `ReportBugLink` widget (e.g.
  `lib/src/settings/report_bug_link.dart`), used by the About dialog,
  `ServerSetupScreen` and `LoginScreen`, so the URL and the "open externally"
  behavior live in one place.
- `lib/src/screens/server_setup_screen.dart` and
  `lib/src/screens/login_screen.dart`: add `ReportBugLink` at the bottom of
  each screen's layout.
- `pubspec.yaml`: no new dependency — `package_info_plus` and `url_launcher`
  are already present, `package_info_plus` just goes from unused to used.
- New Widgetbook use cases for the About dialog and for the setup/login
  screens' new link state, per this repo's UI convention of a catalog use
  case before wiring a widget into a screen.

Security/privacy impact: None — no new data collected, stored, or sent; the
link opens the user's own browser to a public GitHub URL.

Telemetry impact: None.

Non-goals: no in-app bug report form, no crash log attachment, no diagnostics
bundle. "Report a bug" only opens the GitHub issues page in the browser.
