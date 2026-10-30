---
category: Screens
---

The live viewer of the bot's screen. Besides the picture and its states it shows who is driving (`control`) and, while this device is in control, the input it sends.

- `control`: `watching`, `acquiring`, `in_control`, `releasing` or `lost`. `lostText` says who has the screen after a loss; `canForce` offers Hand back to Hermes on the blanked notice.
- `input` (only `in_control`): `device` is `touch` for the key bar under the picture (keyboard, Esc, Tab, Ctrl and Alt that latch, the arrows, Paste, then the Touch or Trackpad switch) or `desktop` for the tools row under the header (Paste, and Send F8 with `sendF8`). `mode`, `ctrl`, `alt` and `keyboardOpen` set the key bar's state, `cursor` places the Trackpad cursor as fractions of the picture, `notice` is the line under the header (such as the refused paste), and `onMode`, `onPaste` and `onSendF8` are the callbacks.
- `onTakeOver`, `onHandBack`, `onForceHandBack` and `onDismissLost` are the header and notice actions.
