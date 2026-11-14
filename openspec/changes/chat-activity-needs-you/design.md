# Design

## Context

Read from the code at `origin/main` after `chat-activity-panel` and `chat-activity-quiet` were archived. Working and For reference items are already only in the Activity panel (`BoundActivityPanel`). What `ChatThreadView` still draws between the header and the transcript is `chat-activity-strip`, a box of at most 280 pt (40% of the height) that holds Needs-you cards only: `ConnectorOperationCard`s of tier Needs you, the `BillingVerificationCard` while details are held, and `SessionStatusCard` for a reclaimed or failed-restore session (`sessionStateTier` returns Needs you for `reclaimedReason != null` or `resume.status == 'failed'`). The `todoPlan` parameter only feeds that box's listener; `moaProgress`, `onMoaDetails`, `processOutputs` and `onProcessOutputDetails` are declared and never read.

Needs-you items come from three controllers: `BillingVerificationController` (details while a request is pending, or uncorrelated details), the two `ConnectorOperationController`s (session-owned operations with authority and an offered action; connection-wide ones are always reference) and `ChatSessionState`. The composer is `ChatComposer`, positioned by `buildChatComposer` as a direct child of the `Chat` stack, reporting its height to `ComposerHeightNotifier`. Approval and clarify cards are transcript messages and are not affected.

Backend contract: none new. Frames and methods are those of `openrpc/hermes-gateway.openrpc.json` at the pinned commit (`openrpc/HERMES_REF`): `billing.step_up.verification`, the connector operation updates and the response call, `session.reclaimed`, `session.resume_progress`.

## Goals / Non-Goals

**Goals:**

- One ordered queue across the three sources, independent of which controller changed last.
- The dock moves with the composer (keyboard, attachments, dictation) and keeps the transcript's bottom padding right.
- Every answer and every offline moment has a visible, bounded state.

**Non-Goals:**

- A combined card that shows several items at once.
- Notifications for these items.

## Decisions

- **`NeedsYouQueue`** (`lib/src/chat/activity/needs_you_queue.dart`) listens to the three sources, keeps a first-seen timestamp per item key (billing request, connector `owner`+`op_id`, session runtime), drops keys that leave the Needs-you tier, and exposes the ordered list plus the shown index. Paging state lives in the queue so a re-render keeps the position; when the shown item leaves, the index stays on the same slot (the next item). Alternative: sort by each source's own timestamp. Rejected: billing details carry no time and the connector `seq` is per operation.
- **Four kinds.** `billing`, `connector`, `reclaim` (reclaimed) and `resume` (restore failed; same Reopen action, different title and body). The proposal listed three; the code's tier function already treats a failed restore as Needs you.
- **Dock inside the composer's positioned box.** The dock is built by `buildChatComposer` above `ChatComposer` in the same `Positioned` column, so the reported composer height includes it and flutter_chat_ui pads the transcript correctly. Alternative: a separate overlay. Rejected: the transcript would scroll under it.
- **Plain-model widget, three bodies.** `NeedsYouDock` takes a `NeedsYouDockModel` (items, shown index, callbacks for page, copy, open, skip, continue, reopen). An item carries its kind, title, a body model per kind (`BillingBody`: host, code, openable; `ConnectorBody`: targets with state, deadline text; `ReclaimBody`: reason as untrusted text), its answer status and its offered actions. The bound layer maps controller state to models; the card bodies of `BillingVerificationCard` and `ConnectorOperationCard` are extracted as body widgets that the cards still use, so the controller-facing wiring is unchanged (extraction first, own commit).
- **Layout (from the design pass).** Header row: kind icon, title, and when several wait "1 of 2" with Previous and Next icon buttons (44 pt, 28 pt on the Mac). Under it the body, which alone scrolls and is capped at 40% of the height the chat column has left, so with the keyboard up on a small phone the body shrinks to a few lines and the header and action row stay visible. Last, the action row. The card is a surface-high rounded card with 12 pt margin, the composer's own width (`kChatColumnMaxWidth`), no shadow.
- **Keyboard on a small phone (proposed by the design pass).** With the body at 40% of the chat a 667 pt phone with the keyboard open has no transcript left. While the keyboard is open the card collapses to its title, one summary line (for example "3 sign-ins waiting · Expires in 4 min") and its action row; the targets return when the keyboard closes. Task 1.3 builds both and the catalog decides the thresholds.
- **Title and actions.** The title wraps to two lines rather than truncating, so "1 of N" and the arrows never cut it. On a phone the billing actions stack full width with Open verification page (filled) over Copy code; elsewhere they share a row. The host line comes before the code box so a large text size cannot push it out of view.
- **Answer states.** `NeedsYouItem.answer` is `idle`, `sending`, `unconfirmed`. *Sending*: Skip and Continue disabled, a thin `BusyBar` under the header, the line "Sending your answer…". It ends in one of two ways within 10 s: the response confirms (the item leaves when the operation settles; if it is confirmed but unsettled the card returns to idle) or the bound passes and the card shows a warning line with icon, "Couldn't confirm your answer. It may have gone through. Check before trying again.", with the actions offered again. Nothing is resent; a late settle still removes the item. `ConnectorOperationController._answer` gets the bound (a `Future.timeout` of 10 s that reports `unconfirmed` and leaves the request's late result to be applied if it arrives); its existing refusal text "The response was refused or the connection was lost." is replaced by the same line.
- **Reopen has no answer state.** `reopenSession` is local and synchronous (it selects the thread and the resume flow reports its own progress), so Reopen needs no 10 s bound. While the resume runs the item has left Needs you.
- **Offline keeps the item.** Today a connection drop makes `connectorTier` return For reference (no attachment, so not actionable) and the card jumps to the panel and back after the reconnect replay. The dock keeps an item that was Needs you while the gateway is reconnecting: Skip, Continue, connector Open and Reopen are disabled (the canvas drew connector Open enabled; it needs operation authority, so it is disabled), the line reads "Offline. These actions come back when you're connected.", Copy code and a billing Open verification page stay (they are local and the controller still holds the details). The item still leaves on settle, deadline, App Lock, reclaim, retarget, sign-out and every other retirement the existing capabilities define; a retirement is never mistaken for offline. Implementation check (task 3.1): whether the controller keeps the snapshot across a reconnect; if it releases it, the queue holds the item's model, disabled, until the replay restores it or a retirement removes it, and never offers an action from stale authority.
- **Announcement** through `SemanticsService.announce` (polite) with a fixed sentence per kind, once per item key: "Billing access needs approval", "A connection needs you", "This chat was opened elsewhere", "This chat couldn't be restored". Never the code, URL, target names or reason. The code is read only when focus reaches it. Focus order is the drawn order: title, paging, body, actions.
- **Quick panel height.** `QuickPanelScreen` measures the composer area already; the dock is part of it, so `resizePanel` grows by the card's height (capped by the native 60% screen limit); the body then scrolls.
- **Marker.** `ActivityButton` takes `waiting: int`; a 10 pt filled circle in the warning token with a 2 pt ring in the surface colour at the icon's top right (as server care's attention mark), label "Activity, 2 need you". Status is not colour alone: the label carries the count and the dock itself carries the words. On the Mac the toolbar button gets the same marker.
- **Strip removal.** The whole `chat-activity-strip` box, `activity()` and its `ListenableBuilder` are deleted; `connectorOperations`, `billingVerification` and `sessionState` stay on `ChatThreadView` only as inputs of the dock.

Platforms: iOS, Android, macOS (main window, conversation windows, quick panel), Windows, Linux. No native, entitlement, manifest or Xcode change.

Invariants touched: telemetry. `chat.activity.needs_you.shown` (`kind`, `count`) is recorded by the queue's owner in `ChatScreen`, `ConversationWindowScreen` and `QuickPanelScreen` when a new key reaches the front; `chat.activity.needs_you.paged` (`count`) on paging. Breadcrumbs only, fixed values, no codes, URLs, reasons, titles or ids. Privacy: the billing rules of `agent-billing-verification` (App Lock clearing, no persistence) apply unchanged because the dock reads the same controller state.

## Risks / Trade-offs

- [A tall connector card with several targets crowds a short phone screen] → Only the body scrolls, capped at 40% of the remaining height; header and actions stay.
- [Paging hides the second item] → The position label and the Activity button marker both show the count.
- [Extracting card bodies touches two widgets with many tests] → Pure extraction committed first; existing card tests guard it.
- [Keeping an offline item shows actions that cannot run] → They are disabled and the line says why; nothing is queued for later.
- [The 10 s bound reports "unconfirmed" for an answer that did arrive] → The line says it may have gone through, and a late settle removes the item.
