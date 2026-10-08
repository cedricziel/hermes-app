# Screenshots

The images in this folder are the ones in the main README. They are rendered
from the app's own widgets in a Flutter test, on any machine, in about a minute.
The App Store screenshots are different: they are still captured from the real
app on a Mac (see "App Store screenshots" below).

Both show a few invented chats (a failed backup, release notes, a certificate
rotation). They live in `scripts/demo_sessions.json`, which the render test
and `scripts/seed_demo_sessions.py` both read. No real server, account or chat
is in them.

| File                                                      | Shows                                                  |
| --------------------------------------------------------- | ------------------------------------------------------ |
| `iphone-chat.png`, `iphone-chat-dark.png`                 | A chat with tool calls, a code block and a list        |
| `iphone-threads.png`                                      | The thread list, with a pinned chat                    |
| `iphone-welcome.png`                                      | A new chat with its starter prompts                    |
| `ipad-chat.png`, `ipad-chat-dark.png`, `ipad-welcome.png` | The wide layout: navigation rail, thread list and chat |
| `mac-chat.png`, `mac-chat-dark.png`, `mac-welcome.png`    | The wide layout in a Mac window                        |
| `watch-threads.png`                                       | The watch app's thread list                            |

## Render the README images

```bash
README_SCREENSHOTS=1 flutter test test/readme_screenshots_test.dart
python3 scripts/finish_screenshots.py --readme-only   # needs Python 3 with Pillow
```

The test mounts the whole app against a stand-in dashboard on a loopback
socket, which serves the demo chats. It renders the iPhone, iPad and Mac
screens at the store sizes, light and dark, and writes the raw images to
`build/screenshots/`. Without `README_SCREENSHOTS=1` it renders the same
screens and writes nothing, so a plain `flutter test` still checks that they
render. `--readme-only` writes `docs/screenshots/` and never
`fastlane/screenshots/`, so a rendered image can't reach an App Store upload.
It leaves the watch image alone.

The "README screenshots" GitHub workflow does the same on demand (Actions >
README screenshots > Run workflow) and opens a PR with the new images. Its
artifact holds the raw and finished files.

What differs from the real app:

- Text is Roboto, not San Francisco, and code is JetBrains Mono.
- There is no status bar and no native Mac window frame. The Mac image is the
  window content on the usual canvas.
- The server is a stand-in that answers only what the chat and welcome
  screens ask for. Anything else is a 404 and its feature stays hidden.

## App Store screenshots

These need the real app. You need `hermes` on your PATH (see `scripts/dev-backend.sh`), Xcode with the
iOS 26 simulators, and Python 3 with Pillow.

```bash
scripts/store-screenshots.sh ios       # iPhone 17 Pro Max and iPad Pro 13-inch simulators, light and dark
scripts/store-screenshots.sh mac       # the Mac window, widened to 1440 x 900 points
scripts/store-screenshots.sh watch     # the watch app, through its paired phone
scripts/store-screenshots.sh finish    # flatten, size and write the images
```

`ios iphone` or `ios ipad` retakes just one of the two. The `mac` run opens the
app and takes over the screen for a few minutes, because a window has to be in
front to be captured; leave the machine alone until it is done.

What happens:

1. `scripts/dev-backend.sh` starts a throwaway dashboard in its own
   `HERMES_HOME`, and `scripts/seed_demo_sessions.py` fills it with the chats
   from `scripts/demo_sessions.json`. Edit that file to change what the
   screenshots say.
2. `integration_test/store_screenshots_test.dart` opens the app on each device
   and walks to the chat, the thread list and a new chat. It asks the driver
   in `test_driver/integration_test.dart` for a screenshot at each stop. The
   simulators are set to English with a 9:41 status bar.
3. `scripts/finish_screenshots.py` flattens the captures (the store rejects
   transparency), puts the Mac window on a 2880 x 1800 canvas, and writes both
   sets. It also erases two things, and adds nothing: the address of the
   throwaway backend that the account row shows when nobody is signed in
   (the test reports where it is drawn, in a `.erase` file next to each
   capture), and the window handle iPadOS draws in a corner.

Raw captures go to `build/screenshots/`. The store images go to
`fastlane/screenshots/<ios|mac>/en-US/`, which is not committed.

| Device            | Size        | Store display |
| ----------------- | ----------- | ------------- |
| iPhone 17 Pro Max | 1320 x 2868 | iPhone 6.9"   |
| iPad Pro 13-inch  | 2064 x 2752 | iPad 13"      |
| Mac               | 2880 x 1800 | Mac           |
| Apple Watch Ultra | 422 x 514   | Apple Watch   |

The Mac window opens at 800 x 600 points, below the 900 point breakpoint of the
wide layout, so the test first resizes it (`SHOT_MAC_WINDOW`, 1440x900 by
default). `mac compact` keeps the default size and writes `mac-compact-*`, which
`finish` uses only when there is no wide capture.

The watch screenshot needs the watchOS simulator runtime (Xcode > Settings >
Components). The `watch` run builds the phone app with the watch app inside,
installs both on a paired Apple Watch Ultra 4 and iPhone 17, and captures the
watch once the phone has answered its request for the threads. A simulator
can't be tapped and the watch has no status-bar override, so it is the screen
the watch app opens on, with the simulator's own clock.

## Upload to the App Store

```bash
bundle exec fastlane sync_screenshots              # iOS and macOS
bundle exec fastlane sync_screenshots platform:ios # only one
```

This needs the App Store Connect key described in `fastlane/.env.default`. It
replaces the screenshots on the editable version and uploads no build. Like
`sync_metadata`, it moves that version to the number in `pubspec.yaml`.
