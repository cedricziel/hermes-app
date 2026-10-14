# Design

## Context

After `chat-activity-panel`, only Working and Needs-you entries remain in `ChatThreadView`'s strip. Needs-you entries come from three controllers: `BillingVerificationController` (details while a request is pending, or uncorrelated details), the two `ConnectorOperationController`s (session-owned operations with authority and offered actions; connection-wide ones are always reference) and `ChatSessionState` (reclaimed). The composer is `ChatComposer`, positioned by `buildChatComposer` as a direct child of the `Chat` stack, reporting its height to `ComposerHeightNotifier`. Approval and clarify cards are transcript messages and are not affected.

## Goals / Non-Goals

**Goals:**

- One ordered queue across the three sources, independent of which controller changed last.
- The dock moves with the composer (keyboard, attachments, dictation) and keeps the transcript's bottom padding right.

**Non-Goals:**

- A combined card that shows several items at once.
- Notifications for these items.

## Decisions

- **`NeedsYouQueue`** (`lib/src/chat/activity/needs_you_queue.dart`) listens to the three sources, keeps a first-seen timestamp per item key (billing request, connector `owner`+`op_id`, reclaimed runtime), drops keys that leave the Needs-you tier, and exposes the ordered list plus the shown index. Paging state lives in the queue so a re-render keeps the position; when the shown item leaves, the index stays on the same slot (the next item). Alternative: sort by each source's own timestamp. Rejected: billing details carry no time and the connector `seq` is per operation.
- **Dock inside the composer's positioned box.** The dock is built by `buildChatComposer` above `ChatComposer` in the same `Positioned` column, so the reported composer height includes it and flutter_chat_ui pads the transcript correctly. Alternative: a separate overlay. Rejected: the transcript would scroll under it.
- **Card bodies reuse today's widgets.** The billing body comes from `BillingVerificationCard`'s details part and the connector body from `ConnectorOperationCard`, extracted into body widgets that the dock frames; the dock adds title, position and paging. This keeps the controller-facing action wiring unchanged.
- **Announcement** through `SemanticsService.announce` with a fixed sentence per kind, once per item key.
- **Quick panel height.** `QuickPanelScreen` measures the composer area already; the dock is part of it, so `resizePanel` grows by the card's height (capped by the native 60% screen limit).
- **Marker.** `ActivityButton` takes `waiting: int`; the dot uses the warning token (`--h-warning` / `AppColors.warning`), and the label becomes "Activity, 2 need you".

Platforms: iOS, Android, macOS (main window, conversation windows, quick panel), Windows, Linux. No native, entitlement, manifest or Xcode change.

Invariants touched: telemetry. `chat.activity.needs_you.shown` (`kind`, `count`) is recorded by the queue's owner in `ChatScreen`, `ConversationWindowScreen` and `QuickPanelScreen` when a new key reaches the front; `chat.activity.needs_you.paged` (`count`) on paging. Breadcrumbs only, fixed values, no codes, URLs, reasons, titles or ids. Privacy: the billing rules of `agent-billing-verification` (App Lock clearing, no persistence) apply unchanged because the dock reads the same controller state.

## Risks / Trade-offs

- [A tall connector card with several targets crowds a short phone screen] → The dock body is capped at 40% of the chat height and scrolls inside; the composer stays visible.
- [Paging hides the second item] → The position label and the Activity button marker both show the count.
- [Extracting card bodies touches two widgets with many tests] → Pure extraction committed first; existing card tests guard it.
