## Context

flutter_chat_ui's `Chat` puts `builders.composerBuilder` into its `Stack` and pads the message list by the height the composer reports through the `ComposerHeightNotifier` it provides. The stock `Composer` returns a `Positioned`, measures itself after each frame, and reads `OnMessageSendCallback` and `OnAttachmentTapCallback` from the provider scope `Chat` sets up. It is built on `material_ui`, which is why `FlyerMaterialScope` exists.

## Goals / Non-Goals

**Goals:**

- One composer widget that takes plain models and callbacks, so Widgetbook shows it without a `Chat`.
- Keep `chat_screen.dart`'s contract with the builder (`buildChatComposer`) unchanged.

**Non-Goals:**

- Removing `FlyerMaterialScope`: the package's message widgets still use `material_ui`.

## Decisions

- **Own widget instead of `Composer.topWidget` tricks.** The stock composer has no slot below the field, and hiding its row to rebuild one in `topWidget` would leave two text fields to keep in step. Alternative rejected: forking the package's composer file.
- **Two layers.** `ChatComposer` is the card and the bars above it, built from plain values and callbacks (`onSend`, `onAttach`). A small wrapper in `chat_composer_builder.dart` returns the `Positioned`, reads the package's send and attach callbacks from the provider scope, adds the bottom safe-area padding and reports its height to `ComposerHeightNotifier`. The wrapper stays a direct child of the `Chat` stack, as the package requires.
- **Measure on every size change.** The wrapper measures after a `SizeChangedLayoutNotification` as well as after its own builds, so the list's padding follows the field as it grows line by line.
- **Flutter's material widgets.** The card uses Flutter's `TextField` and `IconButton.filled`, like the stop bar and the queue already do, under the app's own theme; `material_ui` is not needed for it.
- **Enter handling kept.** A key handler on the field's focus node sends on Enter without Shift and leaves Shift+Enter to the field, as the package does with `sendOnEnter`.

Platforms: all (iOS, Android, macOS, Windows, Linux). No native, entitlement, manifest or Xcode project change. watchOS is unaffected.

Invariants touched: none.

## Risks / Trade-offs

- [The list's bottom padding lags a frame behind the composer's height] → Same as the package's own composer, which also measures after the frame.
- [Keyboard insets] → The chat screen's `Scaffold` resizes for the keyboard, as it did for the package composer; the composer only adds the bottom safe area.
