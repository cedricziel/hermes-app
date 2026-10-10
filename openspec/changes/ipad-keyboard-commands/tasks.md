# Tasks

One PR, `feat(ios): add Hermes commands to the iPad menu bar`. Wave 1, independent of the other changes. No API routes change, so no OpenAPI regeneration. No widget changes its look, so no Widgetbook use cases (the menu is native).

## 1. Spike

- [ ] 1.1 On the iPad simulator with a hardware keyboard, bind ⌘N as a `UIKeyCommand` in `AppDelegate.buildMenu(with:)` and log presses in Flutter with a temporary `HardwareKeyboard` handler. Record in design.md (Risks) who gets ⌘N: with nothing focused, with the composer focused, and with `canPerformAction` returning false. Remove the temporary code.

## 2. Shared layout (refactor, then TDD)

- [ ] 2.1 Refactor: move the menu table out of `macMenus` into `menuLayout` (`MenuSection`, `MenuEntry` with a platform set); `macMenus` renders it. `test/macos/mac_menu_bar_test.dart` passes unchanged.
- [ ] 2.2 Write failing tests that the iPad layout lists exactly the spec's sections, items and chords, has no duplicate chord, and binds none of ⌘C, ⌘V, ⌘X, ⌘A, ⌘Z, ⇧⌘Z, ⌘⌫. Mark the entries; verify.

## 3. Bridge (TDD)

- [ ] 3.1 Write failing tests in `test/macos/ipad_menu_bridge_test.dart` with a mocked `hermes_app/menu` channel: the layout is sent once with iOS chrome and never with Mac or Material chrome; a scope change sends `setState` with enabled flags and titles (New Task, Unpin); a hidden page's scope sends nothing enabled; an `invoke` from native runs the handler once; a channel error is swallowed. Implement `ipad_menu_bridge.dart` and mount it in `MacMenuBar`; verify.
- [ ] 3.2 Write failing tests that with iOS chrome `AppShell` offers Settings, Connection Details and Sign Out, and `ChatScreen`'s Find focuses the sidebar search field in the wide layout and is disabled in the narrow one. Implement (a `FocusNode` for `ThreadSearchView`); verify.

## 4. Native side

- [ ] 4.1 Add `ios/Runner/KeyCommandMenu.swift` (layout and state from the channel, `UIKeyCommand`s with the command name as property list) and the `buildMenu(with:)`, `canPerformAction(_:withSender:)`, `validate(_:)` and `hermesCommand(_:)` overrides in `AppDelegate.swift`; remove `.find`, `.format` and `.newScene`; add the file to the Runner target. Verify `flutter build ios --simulator -d <udid>`.

## 5. Observability

- [ ] 5.1 Write failing tests with a recording `Breadcrumbs` trail and `AppEventLogger`: an `invoke` adds `menu.command` (`command`, `platform`); a rejected `setLayout`/`setState` logs `ipad_menu.sync_failed` (`operation`, `error.type`); nothing else is attached. Implement; verify.

## 6. Docs and skills

- [ ] 6.1 Update CLAUDE.md's macOS menu bar paragraph (the layout is shared with iPad; ⌘F is `MacCommand.find` on both) and add an iPad keyboard check to the `verify-in-app` skill.

## 7. Verify

- [ ] 7.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all pass.
- [ ] 7.2 On the iPad simulator with a hardware keyboard against `scripts/dev-backend.sh`: hold ⌘ and see the commands; ⌘N, ⌘F, ⇧⌘P, ⌘, and ⌘[ each act once; Kanban shows New Task; with the composer focused ⌘C, ⌘V, ⌘A, ⌘Z and ⌘⌫ edit text; with no chat selected the chat items are disabled. Run the macOS app and check its menu bar is unchanged. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
