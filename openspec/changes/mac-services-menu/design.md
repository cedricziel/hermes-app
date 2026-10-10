## Context

See `proposal.md`. Shared text on macOS already works like this: the share extension writes entries to `pending.json` in the App Group container and opens `hermes-share://share`; `AppDelegate` answers `take` on the `hermes_app/share` channel with `ShareHandoff.take()` and sends `shared` when the app runs. `MacosShareInbox` parses the entries into `SharedItem`s. `ShareController` (created in `lib/main.dart`, started at launch) holds them, including through setup and login, until `ChatScreen` calls `take()` from `_absorbShared` (at `initState` and on every change). `_absorbShared` appends `SharedText` to the composer of the current chat, which fits a share but not a quote.

## Goals / Non-Goals

Goals: one service entry that opens a new chat with a quote and nothing sent; reuse the share inbox and its hold-until-ready behavior; never write the selection to disk. Non-goals are in `proposal.md`.

## Decisions

### Platforms and native changes

macOS only. iOS, Android, Windows, Linux and watchOS are untouched; the Dart side compiles everywhere but only `MacosShareInbox` can produce a quote.

Native changes: `NSServices` in `macos/Runner/Info.plist`, one new Swift file in the Runner target (`project.pbxproj` gets a file reference and a Sources entry; the share extension target does not), and edits to `AppDelegate.swift`. No entitlement, App Group, URL scheme, deployment-target or Info.plist key other than `NSServices` changes. `macos/Runner/Release.entitlements` stays as it is.

### Declare the service

```
NSServices = [{
  NSMenuItem   = { default = "Ask Hermes" }
  NSMessage    = "askHermes"
  NSPortName   = $(PRODUCT_NAME)
  NSSendTypes  = [ "NSStringPboardType", "public.utf8-plain-text" ]
}]
```

No `NSReturnTypes`, so the service appears for read-only selections too (a web page, a PDF) and never offers to replace text. No `NSKeyEquivalent`: users can assign a shortcut in System Settings > Keyboard > Keyboard Shortcuts > Services, and a default would clash with other apps. `NSRequiredContext` is left out; the service shows whenever the source app offers text.

`NSPortName` is the product name so the system finds the running (or launches the) app. Debug builds use another bundle ID and product name (see CLAUDE.md), so a dev build and an installed release build can both list "Ask Hermes". The `verify-in-app` addition tells the developer to quit the release app or disable one entry.

### Native provider

A small `AskHermesService: NSObject` owns the `askHermes(_:userData:error:)` selector, the in-memory queue and the channel notification. `AppDelegate` sets `NSApp.servicesProvider` in `applicationWillFinishLaunching`, not in `applicationDidFinishLaunching`: when the service starts the app, the system sends the message as soon as the app has finished launching and the provider has to be there. After setting it, call `NSUpdateDynamicServices()` once so a freshly installed build shows the entry without a logout (this is cheap and idempotent).

The method:

1. reads `pboard.string(forType: .string)`; if it is nil or empty after trimming whitespace, sets `error` to a short message and returns (the Dart side never sees it; breadcrumb `service.ask.dropped` is recorded when Dart is told, see Observability);
2. caps the text at 20,000 characters on a character boundary and notes whether it cut;
3. appends `{type: "text", text, intent: "ask", truncated}` to its queue, activates the app, shows the main window (below), and sends `shared` on the share channel if Dart has installed it.

The queue is in memory only. The share extension runs in another process and cannot use it, which is why it needs the App Group file; a service runs inside the app, so writing selected text to a shared container would only add a disk copy of something the user selected in an unrelated app.

`AppDelegate`'s `take` handler returns `ShareHandoff.take() + service.takeQueued()`, so one channel and one Dart parser serve both. If `take` runs at launch before any message arrives, the queue is empty and a later message sends `shared`. If the message arrives before the channel exists (the app is starting), the entry waits in the queue and the first `take` returns it, the same way a launching `hermes-share://` open is handled today.

The 20,000 character cap is an assumption (see Risks). A larger selection would make the composer sluggish and most models would still get the point; the quote ends with a visible `[selection shortened]` line so the user knows.

### Show the right window

The service must be visible whatever the window state. In the provider, after queuing:

- Main window hidden or closed (the app keeps it ordered out so conversation windows keep their engine): call `makeKeyAndOrderFront` on `mainWindow` and `NSApp.activate(ignoringOtherApps: true)`, the same call `applicationShouldHandleReopen` makes. `AskHermesService` gets the window through a closure from `AppDelegate`, which holds `mainWindow`.
- A conversation window is key: the quote still goes to the main window. Conversation windows hold no `ShareController`, no share channel and no session (`MainFlutterWindow.swift` registers few plugins), and adding quoting to them would mean a second inbox and a second "new chat" rule. Activating the main window takes focus from the conversation window, which is the expected effect of invoking another app's service. The chat the user was reading in that window is not touched.
- App minimized: `makeKeyAndOrderFront` deminiaturizes it; call `deminiaturize` first if `isMiniaturized`.
- App not running: the system launches Hermes and delivers the message after launch. The window appears as it does for any launch. Dart's `ShareController.start()` runs `initialItems()` (a `take`) at startup and receives the quote there.

### Dart: a quote is its own item kind

Add `SharedQuote(text, {truncated})` to the sealed `SharedItem` (in `shared_item.dart`), distinct from `SharedText`, which keeps meaning "append to the current composer". `MacosShareInbox._itemFrom` returns `SharedQuote` when `intent == 'ask'` and the text is a non-empty string, otherwise `SharedText` as today. Unknown intents fall back to plain `SharedText` so an older entry format keeps working.

In `ChatScreen._absorbShared`:

1. If the batch holds quotes, take the last one only (an earlier unconsumed quote was superseded; a user who triggers the service twice before the app is ready expects the latest). Plain text and files in the same batch are handled as today after the new chat is made.
2. Call `_chat.newThread()` (through `_newThread`, which also cancels a pending handoff, closes the narrow drawer and focuses the composer).
3. Put `"> " + text` with each line prefixed, then a blank line, in the composer (`_appendToComposer`-like but with a separator `"\n\n"` and the cursor at the end). If the composer already has text, keep it above the quote: the composer is shared across threads in this screen, so wiping a half-typed message would lose data. This is the same rule `_appendToComposer` uses for shares.
4. Record `chat.share.quote`.

`ShareController.take()` stays as it is, and the signed-out case needs nothing new: the controller holds the item through setup and login, and `ChatScreen`, mounted only after sign-in, takes it in `initState`. Under app lock the shell is mounted but covered (`AppLockGate` keeps the child mounted), so the quote lands in the composer under the lock screen and becomes visible on unlock. That is what sharing does today and discloses nothing, since the lock screen covers the child.

The quote is plain Markdown block quote text, not a special message kind. The composer is plain text, the user may edit or delete lines, and the server sees it like any message. No attribution (source app or window title) is added: it is not available from a service, and guessing would be wrong.

### Why not a URL scheme or the deep-link router

A `hermes://` route (owned by another change) could carry the text as a query value, but text length and escaping, and the fact that URLs are logged and shown in places selected text should not be, make the pasteboard path better. The service already hands over the text in-process. This change does not depend on the router. If the router later offers a "new chat with draft" route, the chat screen's quote handling is the natural place to reuse.

### Dependencies

No mature pub.dev plugin receives macOS Services input (a pub.dev search found `receive_sharing_intent`, which is an iOS share-extension plugin, and Android-only text-processing plugins). The native piece is about 60 lines: the plist entry, one selector and a queue. Reusing the existing `hermes_app/share` channel adds no new channel.

## Invariants touched

- Telemetry: breadcrumbs go through `Breadcrumbs`, which is `Breadcrumbs.none` when telemetry is off; failures are swallowed. No text or length is recorded.
- Auth: sign-in and tokens are untouched, and a waiting quote never holds sign-in up. `ShareController` lives for the process, so a quote waiting across a sign-out would reach the next user; sign-out therefore calls a new `ShareController.discardQuotes()` (task 1.2). Plain shares keep today's behavior.
- API layering: no REST calls.

## Observability

Where each is recorded:

| Signal | Name | Where | Attributes |
| --- | --- | --- | --- |
| breadcrumb | `service.ask.received` | `MacosShareInbox`, when it parses a quote | `launched`, `truncated` (flags) |
| breadcrumb | `service.ask.dropped` | `MacosShareInbox`, when native reports a drop | `reason`: `empty` or `no_text` |
| breadcrumb | `chat.share.quote` | `ChatScreen._absorbShared` | `held` (flag) |

`launched` is true when the first `take` at startup returned the quote. Native code reports a drop by queuing `{type: "dropped", reason}`, which `_itemFrom` turns into the breadcrumb and no item. None of them holds the text, its length, the source app, titles or ids. A breadcrumb fits because the action is instant and local; a span would time nothing, and a log event is not needed since a dropped service call is not an error worth counting.

## Risks / Trade-offs

- The 20,000 character cap and the `[selection shortened]` line are a guess; tune after use.
- Services menu caching: macOS caches the list, so a new build may need `/System/Library/CoreServices/pbs -update` or a logout. The `NSUpdateDynamicServices()` call covers most cases.
- Two apps with the same menu title (dev and release) show twice; documented, not solved.
- Services in sandboxed apps work without entitlement, but App Review has not seen this app with `NSServices`. The key is a normal Info.plist key and many sandboxed apps use it.
- A user who triggers the service while a reply is streaming gets a new chat; the running reply continues in its thread, as with File > New Chat.
