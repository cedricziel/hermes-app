---
name: watch-simulator
description: Use when a change to the watchOS app (ios/HermesWatch) should be built, tested or looked at — its Swift core tests, a compile check of the watch target, or screenshots of its screens in the watch simulator without a paired phone.
---

# Build, test and look at the watch app

The watch app has no network of its own; every screen asks the phone over
WatchConnectivity (`RelayClient`), and the phone answers in
`lib/src/watch/`. A watch simulator has no phone to ask, so on its own it only
ever shows "Can't reach your iPhone". Debug builds can answer from canned
chats instead (`DemoClient.swift`).

## Tests and compile check

```bash
(cd ios/HermesWatch && swift test)   # Core/ logic, runs on the Mac; CI's "Test watch core"
xcodebuild -project ios/Runner.xcodeproj -target HermesWatch -sdk watchsimulator \
  -configuration Debug CODE_SIGNING_ALLOWED=NO SYMROOT=/tmp/hw-build build
```

The views are not in the Swift package, so only the `xcodebuild` step
compiles them. A new Swift file must also be added to the `HermesWatch`
target in `ios/Runner.xcodeproj/project.pbxproj` (the project has no
synchronized folders): a `PBXBuildFile`, a `PBXFileReference`, the group
child and the Sources phase entry, mirroring `Models.swift`.

## Screenshots

```bash
W=$(xcrun simctl list devices available | grep -m1 'Apple Watch Series' | grep -oE '[0-9A-F-]{36}')
BID=com.cedricziel.hermesApp.watchkitapp
xcrun simctl boot $W; xcrun simctl bootstatus $W -b
xcrun simctl install $W /tmp/hw-build/Debug-watchsimulator/HermesWatch.app
SIMCTL_CHILD_HERMES_WATCH_DEMO=list xcrun simctl launch $W $BID   # or =chat to open a chat
sleep 4; xcrun simctl io $W screenshot /tmp/watch.png
xcrun simctl terminate $W $BID
```

- The demo switch is an environment variable: launch arguments passed to
  `simctl launch` do not reach the watch app.
- `DemoClient` exists only where `DEBUG` is defined; the watch target's Debug
  configuration sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` for it.
- A chat scrolls to the reply field on load. To see its top, build once with
  the `proxy.scrollTo("composer")` call disabled and restore the file after.
- Building for the simulator does not touch the tracked Flutter `ios/` files,
  but check `git status` anyway before committing.
