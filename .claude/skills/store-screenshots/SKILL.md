---
name: store-screenshots
description: Use when the App Store or README screenshots need retaking or changing — the UI changed, the demo chats should say something else, a device size is needed — or when asked to upload screenshots to App Store Connect.
---

# Retake the store and README screenshots

One script takes them from the real app, against a throwaway Hermes seeded with
invented chats. `docs/screenshots/README.md` lists the files, sizes and what is
erased. This is the procedure and the traps.

## Steps

1. Change what the shots say in `scripts/seed_demo_sessions.py`. Invented chats
   only.
2. `scripts/store-screenshots.sh ios` takes the iPhone 17 Pro Max and iPad Pro
   13-inch simulators, light and dark (about 10 minutes cold). `ios iphone` or
   `ios ipad` takes one.
3. `scripts/store-screenshots.sh mac` takes the Mac window, resized to 1440 x
   900 points, light and dark. It takes over the screen for a few minutes.
   Don't move this run to a GitHub macOS runner: there, `flutter drive` built
   the iOS app (8 minutes) and then never reached it on the simulator.
4. `scripts/store-screenshots.sh finish`, then look at every image in
   `fastlane/screenshots/`: no dev address, an English status bar, no seams
   where something was erased.
5. Upload with `bundle exec fastlane sync_screenshots version:<editable
version>`. Check the editable version on App Store Connect first and pass
   it, or fastlane renames it to the `pubspec.yaml` version. Read the sets back
   from Apple before saying it worked; the lane's log is not proof.
6. Commit the README-sized copies in `docs/screenshots/`. The store images are
   git-ignored.

## Rules

- Invented data only. Never point the app or `hermes` at the real `~/.hermes`,
  and never run `hermes dashboard --stop` (see `verify-in-app`).
- An upload changes the public listing at the next release. Do it when asked.
- `finish` only erases (the dev URL row, the iPadOS window handle). Never
  paint or fake content into a screenshot.
- Builds rewrite tracked `ios/` and `macos/` files. Stage by name.
- Delete the App Store Connect key and env file when done. The builds take
  several GB; if the disk fills, clear `build/macos` and `build/ios`.

## Traps

- The integration driver's `onScreenshot` runs after the whole test, so every
  file was the final screen. The test asks the driver over HTTP (`SHOT_PORT`)
  and waits. Compare checksums of the captures: a passing test can still have
  taken the same screen three times.
- A missed tap must fail the test, so `hitTestWarningShouldBeFatal` is set. Tap
  the icon, not its tooltip wrapper, and never open a drawer that is already
  open.
- The Mac window opens at 800 x 600, under the 900 point wide breakpoint. A
  size in the xib or in `MainFlutterWindow.swift` never reached the built app;
  the test resizes it through the `setContentSize` call on the
  `hermes_app/window` channel (`SHOT_WINDOW`).
- Don't add erase boxes for the dev address by hand. The test finds the
  address text and writes its pixel box to `<screen>.erase`; `finish` erases
  that. A fixed box goes stale with the next layout change.
- The seed script needs the interpreter `hermes` runs on. Newer installs run a
  bundled Python and load their dependencies through `hermes_bootstrap`, so
  `store-screenshots.sh` asks `hermes --print-runtime-command`; set
  `HERMES_PYTHON` to override. A seed failure stops the run.
- The welcome shot's starter prompts come from the backend: a failed cron job,
  a blocked Kanban task, the latest chat and the most-used skill. The seeded
  backend has only chats, so it shows "Pick up '<latest seeded chat>'" and
  three generic prompts. Make the latest seeded chat the one that should be
  named there.
- Simulators must be `en_US` (the script sets it), or the iPad status bar shows
  the date in the system language.
- The watch shot needs the watchOS runtime (Xcode > Settings > Components) and
  `store-screenshots.sh watch`. The watch app asks the paired phone app, which
  must be running, and a hand-installed watch app is not noticed for about a
  minute, so the run waits before it launches the watch app. A simulator can't
  be tapped, so it is only the first screen, the thread list.
- `op` can time out once waiting for approval in the 1Password app. Retry.
