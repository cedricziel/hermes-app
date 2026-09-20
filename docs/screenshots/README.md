# Screenshots

The images in this folder are the ones in the main README. The same run makes
the App Store screenshots.

They come from the real app, running against a throwaway Hermes dashboard that
holds a few invented chats (a failed backup, release notes, a certificate
rotation). No real server, account or chat is in them.

| File                                                      | Shows                                                  |
| --------------------------------------------------------- | ------------------------------------------------------ |
| `iphone-chat.png`, `iphone-chat-dark.png`                 | A chat with tool calls, a code block and a list        |
| `iphone-threads.png`                                      | The thread list, with a pinned chat                    |
| `iphone-welcome.png`                                      | A new chat with its starter prompts                    |
| `ipad-chat.png`, `ipad-chat-dark.png`, `ipad-welcome.png` | The wide layout: navigation rail, thread list and chat |
| `mac-chat.png`, `mac-chat-dark.png`, `mac-welcome.png`    | The wide layout in a Mac window                        |

## Retake them

You need `hermes` on your PATH (see `scripts/dev-backend.sh`), Xcode with the
iOS 26 simulators, and Python 3 with Pillow.

```bash
scripts/store-screenshots.sh ios       # iPhone 17 Pro Max and iPad Pro 13-inch simulators, light and dark
scripts/store-screenshots.sh mac       # the Mac window at its default, compact size
scripts/store-screenshots.sh finish    # flatten, size and write the images
```

`ios iphone` or `ios ipad` retakes just one of the two. The `mac` run opens the
app and takes over the screen for a few minutes, because a window has to be in
front to be captured; leave the machine alone until it is done.

What happens:

1. `scripts/dev-backend.sh` starts a throwaway dashboard in its own
   `HERMES_HOME`, and `scripts/seed_demo_sessions.py` fills it with the demo
   chats. Edit that file to change what the screenshots say.
2. `integration_test/store_screenshots_test.dart` opens the app on each device
   and walks to the chat, the thread list and a new chat. It asks the driver
   in `test_driver/integration_test.dart` for a screenshot at each stop. The
   simulators are set to English with a 9:41 status bar.
3. `scripts/finish_screenshots.py` flattens the captures (the store rejects
   transparency), puts the Mac window on a 2880 x 1800 canvas, and writes both
   sets. It also erases two things, and adds nothing: the address of the
   throwaway backend that the account row shows when nobody is signed in, and
   the window handle iPadOS draws in a corner.

Raw captures go to `build/screenshots/`. The store images go to
`fastlane/screenshots/<ios|mac>/en-US/`, which is not committed.

| Device            | Size        | Store display |
| ----------------- | ----------- | ------------- |
| iPhone 17 Pro Max | 1320 x 2868 | iPhone 6.9"   |
| iPad Pro 13-inch  | 2064 x 2752 | iPad 13"      |
| Mac               | 2880 x 1800 | Mac           |

The Mac window opens at 800 x 600 points, below the 900 point breakpoint of the
wide layout, so `mac` takes the compact one, with the thread list in a drawer.
A script can't widen the window without Accessibility permission for the
terminal, and setting the size in the xib or in `MainFlutterWindow.swift` did
not reach the built app. The wide Mac shots are taken by hand instead: start
the backend and seed it, run `scripts/dev-app.sh start`, widen the window, open
the chat, and run `scripts/dev-app.sh screenshot
build/screenshots/mac-light/chat.png`. Do the same for `welcome.png`, then
switch the app to dark for `mac-dark/chat.png`. `finish` prefers these over the
compact ones.

The Apple Watch app has no screenshots here: it needs a watchOS simulator
runtime, which this setup doesn't install.

## Upload to the App Store

```bash
bundle exec fastlane sync_screenshots              # iOS and macOS
bundle exec fastlane sync_screenshots platform:ios # only one
```

This needs the App Store Connect key described in `fastlane/.env.default`. It
replaces the screenshots on the editable version and uploads no build. Like
`sync_metadata`, it moves that version to the number in `pubspec.yaml`.
