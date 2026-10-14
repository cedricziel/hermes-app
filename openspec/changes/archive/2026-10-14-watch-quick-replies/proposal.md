# Proposal

## Why

Typing on a watch is slow, and most follow-ups to an agent are one word: "Continue", "Yes", "No". Starting a voice message also takes a precise tap on a small button, which is hard with one hand busy. Quick-reply chips and the double-tap gesture make the common cases one touch.

## What Changes

- In a watch chat, four fixed chips sit above the reply field: "Continue", "Yes", "No", "Summarize". A tap sends that text exactly as a typed message would be sent; the chips are disabled in every state where the field is.
- Double tap (`handGestureShortcut(.primaryAction)`, watchOS 11 and later) starts a voice message, or stops and sends it while recording.

Non-goals:

- No server- or context-derived suggestions, no localization of the chips, no user-editable chips.
- No change to the phone side (`lib/src/watch/`), the relay protocol or the Core send rules.

## Capabilities

### Modified Capabilities

- `watch`: adds the quick-reply and double-tap requirement.

## Impact

- `ios/HermesWatch/ConversationView.swift` only. The watch target already deploys to watchOS 26, so the gesture needs no availability check.
- Security and privacy: None. The chip texts are constants; they travel as an ordinary message.
- Observability: None. The chips reuse the send path and its existing relay diagnostics; the phone cannot tell a chip from typed text, and logging which chip was used would add nothing actionable.
