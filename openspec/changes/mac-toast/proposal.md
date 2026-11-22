# Proposal

Audit item C9 (toast). The macOS platform brief already uses "C9" for the Refresh button; this change is called "the Mac toast" to keep them apart.

## Why

Transient messages are Flutter `SnackBar`s on every platform, the Mac included. There are 58 `showSnackBar` calls in 42 files under `lib/src` (counted with `grep -rn showSnackBar lib/src`), for example "saved" after an export (`lib/src/chat/session_export_flow.dart:81`), chat notices (`lib/src/chat/chat_screen.dart:990-993`), schedule results (`lib/src/schedules/schedule_actions.dart:9-11`) and an "Open" action after an MCP install (`lib/src/mcp/mcp_catalog_screen.dart:82-87`). No theme sets a `SnackBarThemeData` (nothing in `lib/src/theme/` mentions it), so each one is the Material default: a dark full-width bar fixed to the bottom edge of the nearest `Scaffold`, no icon, text only.

Why that looks wrong on a Mac:

- A Material bar stretching across a 1100 pt window is a phone pattern. A Mac app confirms a small action with a short, centred, rounded message (a HUD or toast) or an inline banner, and keeps the content visible.
- The bar sits where the chat composer is. One call site already works around it by measuring the composer and floating the bar above it (`session_export_flow.dart:134-147`, `behavior: SnackBarBehavior.floating`); the other 57 do not, so a message can cover the send button.
- There is no shared Mac look, so messages differ by call site, and one-line English literals remain in some (`lib/src/schedules/schedules_screen.dart:88`).
- Accessibility is left to Material. The app's own banner (`lib/src/widgets/app_banner.dart`) is a polite live region with an icon and a title, so status is never colour alone; the SnackBar has no icon and no tone.

## What Changes

An adaptive building block `AppToast` (message, optional tone, optional single action) shown through one call, `AppToast.show(context, ...)`.

- On macOS it draws a Mac toast: a small rounded capsule on the translucent material, an icon for the tone, the text, an optional action, placed in the content pane (not over the sidebar), above the composer. It is announced to VoiceOver, pauses while hovered or focused, dismisses on click or Escape, and one message at a time replaces the previous.
- On other platforms it shows today's floating `SnackBar` through `ScaffoldMessenger`, so nothing changes there.
- Call sites move to `AppToast.show` in batches. A new architecture rule (`arch.raw-snackbar`) bans a raw `showSnackBar` outside the block, with the 42 files in the baseline ratchet (`test/architecture/baseline/arch.yaml`), which only shrinks.

## Non-goals

- No change on iOS, Android, Windows or Linux.
- No system notification (Notification Center) for in-app results; notifications stay in `lib/src/notifications/`.
- No stack or history of toasts, no multiple actions, no undo framework.
- No replacement of `AppBanner` (persistent, inline status) or of dialogs for errors that need a decision.
- No new copy: texts are the existing ones; hard-coded English literals found on the way are reported, not fixed here.

## Security and privacy impact

None for tokens or storage. A toast shows content the call site already put in a SnackBar. It must not outlive App Lock: a covered app hides the toast and clears the queue, so no message text sits under or after the cover. The VoiceOver announcement carries the same text and is not logged.

## Observability

None. A toast is a UI restyle; the message text may be content or a server answer, so no breadcrumb, span or log event carries it, and a count of toasts would add no way to understand a failure.

## Design pass

Needed: new look and placement. Record a "Proposed:" note in `docs/design-briefs/macos-platform-fixes.md` (added by this change). Boards to ask for: each tone (neutral, success, warning, error) with its icon and word, with and without an action, one and two lines, long text truncated at three lines, light and dark, German, largest text, narrow window (compact, sidebar closed) and wide window (sidebar docked), over the chat composer, over a Kanban board, and the hover-paused state.

## Open questions for the owner

1. Placement: bottom centre above the composer (the Mac HUD habit, and where the eye is after sending) or top centre under the toolbar (never near the composer)? design.md recommends top centre; the design pass decides.
2. Should errors stay a toast at all? design.md keeps a toast for "could not" results only when the action can be retried or ignored, and leaves failures that need a decision to dialogs and banners.
3. Is a ratchet over 42 files acceptable, or should the migration be one PR per area?
