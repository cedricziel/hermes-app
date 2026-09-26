## Why

The model pill from `chat-model-selection` sits in a strip above the text field, because flutter_chat_ui's stock composer has a slot above its row and none below it. That puts a per-message control where the stop bar, the queue and the attachments already stack up, and the attach and send buttons flank the field in a single row that matches neither the Claude app nor the Hermes dashboard.

## What Changes

- The composer becomes one rounded card: the multi-line text field ("Message Hermes…", or "Queue a message…" while a reply runs) on top, and a bottom row below it with, left to right, an attach button ("+"), the model pill, a flexible gap and the send button.
- The send button is a filled circle in the primary colour with an upward arrow, and looks disabled when there is nothing to send.
- The stop bar, the queued messages and the attachment chips stay above the card.
- Every behaviour of today's composer is kept: Enter sends and Shift+Enter breaks the line, attachments alone can be sent, the field is cleared by the screen only once a send is accepted, the field grows up to eight lines, and the composer stays clear of the bottom safe area and the keyboard.

This is the second change of the stack started by `chat-model-selection`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: the composer's layout, with attach, the pill and send in a row below the text field.

## Impact

- Code: a new composer widget in `lib/src/chat/widgets/`; `chat_composer_builder.dart` builds it in place of flutter_chat_ui's `Composer`. `chat_screen.dart` keeps calling the builder as before.
- Widgetbook: use cases for the composer in each state.
- Tests: finders that named the package `Composer`, its `material_ui` send button or the old paper-clip icon.
- API: none.

## Non-goals

- New composer features (voice input, slash commands, model options in the "+" menu).
- Changing the pill or the picker themselves.
- Changing how attachments are picked: "+" opens the same menu the paper clip did.

## Security and privacy impact

None.

## Telemetry

None.
