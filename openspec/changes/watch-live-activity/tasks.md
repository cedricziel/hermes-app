# Tasks

One PR, `feat(ios): show a running reply on the watch Smart Stack`. No API routes change.

## 1. Widget extension

- [x] 1.1 Declare `.supplementalActivityFamilies([.small])` on the activity and add `SmallView` (icon, title, short state word, elapsed time) for the `.small` family; verify the `HermesLiveActivity` scheme compiles for the iOS simulator.
- [x] 1.2 Map the stored state to the short word in `ReplyActivity`; no Dart change, since `state`, `title` and `startedAt` are already shared.

## 2. Docs

- [x] 2.1 Update CLAUDE.md's Notifications section: the watch layout, and that a turn sent from the watch gets no activity.

## 3. Verify

- [x] 3.1 `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and compile the extension with `xcodebuild`.
- [ ] 3.2 On a paired watch (not available in CI or the simulator): send from the phone and see the Smart Stack card.
