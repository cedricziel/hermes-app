## Why

On a Mac, the text a user wants to ask Hermes about is usually in another app: an error in a terminal, a paragraph in a browser, a line in a mail. Today they copy it, switch to Hermes, start a chat and paste. The macOS Services menu lets any app hand its selected text to another app in one step. An "Ask Hermes" service puts the selection into a new chat's composer, quoted, so the user only has to type the question.

## What Changes

- Register an "Ask Hermes" service for text on macOS (`NSServices` in `macos/Runner/Info.plist`). It appears in the Services submenu of the app menu and in the context menu of any app that has selected text.
- Add a Services provider to the macOS app delegate. It reads the selected text from the service pasteboard, brings the main window forward, and passes the text to Dart.
- Deliver the text over the existing `hermes_app/share` channel and `ShareController`, as a new shared item kind (a quote). The chat screen opens a new chat and puts the text in the composer as a Markdown block quote. It is never sent.
- Cover the cases the share path already handles (app not running, signed out, locked) and the macOS window cases (main window hidden or closed, a conversation window in front).
- Keep the entry only on macOS. The text is held in memory and never written to disk.

## Capabilities

### New Capabilities

- `mac-services`: The "Ask Hermes" entry in the macOS Services menu, how the selected text reaches a new chat's composer, and what happens when Hermes is not running, signed out, locked, hidden or showing a conversation window.

### Modified Capabilities

None. `sharing` stays as it is; the quote reuses its inbox and hold-until-ready behavior and adds one item kind. Archiving this change adds the new capability only.

## Impact

- `macos/Runner/Info.plist` (`NSServices`), a new `macos/Runner/AskHermesService.swift` (added to the Runner target in `project.pbxproj`), and `macos/Runner/AppDelegate.swift` (set the provider, merge queued quotes into the `take` result, show the window).
- `lib/src/share/` (`shared_item.dart`, `macos_share_inbox.dart`) and `lib/src/chat/chat_screen.dart` (`_absorbShared`).
- Tests: Dart tests for entry parsing and the chat screen; a Swift test in `macos/RunnerTests`; a manual check script in the `verify-in-app` skill.
- No API routes change, no OpenAPI regeneration, no new dependency, no new entitlement.
- One PR, roughly 300 lines.

### Non-goals

- Sending the text. The user always adds a question and sends it.
- Services that take files, images, URLs as links, or rich text. Only plain text is read.
- Services that return text to the calling app (no "replace the selection with Hermes' answer").
- A second service entry (for example "Add to current chat"). The quote always starts a new chat.
- Choosing a profile or model from the service. The new chat uses what the chat screen would use for New Chat today.
- A `hermes://` URL or deep link. Another change owns the URL scheme and router; this change does not use them and does not depend on them.
- iOS, Android, Windows, Linux, watchOS. Share extensions already cover the share sheet on iOS and macOS.
- Actionable notification buttons (owned by another change).

### Security and privacy

The selected text can be sensitive, and it comes from another app. It stays in the app's memory from the service call until the chat screen takes it, then lives in the composer like typed text. It is not written to the App Group container (unlike the share extension's `pending.json`), not to preferences, and not to telemetry. Nothing is sent to the Hermes server until the user presses send. The text is capped in length before it reaches Dart. Tokens, secure storage and the sign-in flow are untouched. The sandbox needs no new entitlement: a service receives its input through the system pasteboard the system hands to the provider.

### Observability

Breadcrumbs only, through `Breadcrumbs`, since this is a user step that can explain a later crash and has no timing or failure worth a span or a counted log:

- `service.ask.received` with the flags `launched` (the service started the app) and `truncated`.
- `service.ask.dropped` with `reason` (`empty`, `no_text`) when the pasteboard holds nothing usable.
- `chat.share.quote` with `held` (true when it waited for sign-in or unlock) when the chat screen opens the new chat.

No text, length, window titles, source app names or ids are recorded. No span, no log event, no new `hermes.*` attributes.
