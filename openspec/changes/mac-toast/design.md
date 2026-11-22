# Design

Platforms: macOS gets the new look. iOS, Android, Windows and Linux keep the floating SnackBar (`platformChromeOf(context)`, `lib/src/theme/platform_chrome.dart:16`, is `macos` only on macOS). No native, entitlement or Xcode change.

Invariants touched: App Lock (no message under the cover), privacy (no message text in telemetry), accessibility (the owner's rule: never status by colour alone).

## Current behaviour

- `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))` at 58 call sites in 42 files, e.g. `lib/src/chat/chat_screen.dart:990-993`, `lib/src/schedules/schedule_actions.dart:9-11` (hides the current one first), `lib/src/mcp/mcp_catalog_screen.dart:82-87` (the one action, "Open"), `lib/src/files/widgets/files_questions.dart:136`.
- The messenger belongs to the root `MaterialApp` (`lib/src/app.dart:173`); the bar attaches to a `Scaffold`: the shell's (`lib/src/shell/app_shell.dart:885`, `:889`) or a page's own. There is no `SnackBarThemeData`.
- The only adaptation is `session_export_flow.dart:79-88` and `:134-147`: floating, with a margin measured from the composer's `chatComposerKey`.
- Screen-reader use: `SemanticsService.sendAnnouncement` is used at six sites: the curator (`lib/src/skills/widgets/curator_section.dart:247`), `lib/src/chat/activity/bound_needs_you_dock.dart:60`, `lib/src/chat/widgets/reply_reconnecting_note.dart:60`, `lib/src/chat/widgets/tool_value_view.dart:588`, `lib/src/chat/widgets/touch_row_menu.dart:65` and `lib/src/chat/widgets/reply_interrupted_note.dart:65`. `AppBanner` is a live region (`lib/src/widgets/app_banner.dart:177-179`).
- The conversation windows and the quick panel have their own `MaterialApp` and messenger (`lib/src/windows/conversation_window_app.dart:80-81`), so a toast host is needed in each, or a window without a host falls back to the SnackBar.

## Options

A. Mac toast overlay as an adaptive block (recommended). One host in the `MaterialApp` builder; `AppToast.show` queues into it. Full control of look, timing and focus; works over any `Scaffold`, and over pages with none.

B. Theme the SnackBar for the Mac (`SnackBarThemeData`: floating, rounded, width cap, margin). Cheapest, and call sites stay. It cannot add a tone icon, pause on hover, avoid the composer on its own or follow the content pane, so it fixes the width and nothing else.

C. Inline banners (`AppBanner`) for results. Persistent and accessible, but they move the layout and need a place on every screen; wrong for "Saved".

D. Notification Center banners from the app. Outside the window, needs permission, and shows message text on the Lock Screen path the privacy rules limit. Rejected.

Recommendation: A, with B's theme as the floor on other platforms (they keep the SnackBar unchanged in this change).

## The Mac toast

- Model: `AppToastMessage(text, tone, action)`; tone is `neutral`, `success`, `warning`, `error` and is shown by the icon and by the words, never by colour alone (icons from `AppIcons`, as `AppBanner.defaultIcon`). Plain values only; the host takes no controller.
- Look (the design pass settles it): capsule on the translucent material, 10 pt radius, 13 pt text, one to three lines, 360 pt wide at most, a 28 pt action button (the Mac target).
- Placement: in the content pane, never over the sidebar. Decided in the design pass (open question 1, the owner may overrule): top centre, 12 pt under the toolbar, so it never covers the composer, the send button or a Kanban column footer. The alternative (bottom centre, 16 pt above the composer) needs the composer's height and fails on pages with other bottom bars. A compact window (below `kMacCompactWindowWidth`, `lib/src/macos/mac_sidebar.dart:20`) uses the window width.
- Content pane bounds: the host sits above the navigator and cannot see the split. The Mac shell wraps its content pane (the `content` of `MacSplitView` in `AppShell` and in `ChatScreen`'s layout) in a `ToastRegion` that reports its global rectangle and toolbar height to the host after each layout; the host places the toast against the newest region. With no region (a page pushed over the window, a compact window, a conversation window) it uses the window's width under a 52 pt toolbar.
- Timing: 3 s, plus 1 s per 40 characters beyond 40, at most 8 s; 8 s minimum when it has an action; paused while the pointer is over it or it has keyboard focus; restarted after. With `MediaQuery.accessibleNavigation` (VoiceOver or Switch Control) it stays until dismissed, as Material's SnackBar does with an action. Reduced motion: fade only, or none (`MediaQuery.disableAnimationsOf`), as `macos_page_transitions.dart` does.
- Queue: one at a time; a new message replaces the visible one at once (as `schedule_actions.dart` does with `hideCurrentSnackBar`), except that an error is not replaced by a neutral one within 1 s.
- Dismiss: click, Escape while it has focus, the action, or the timer.
- Accessibility: a live region (polite; an error is assertive), plus `SemanticsService.sendAnnouncement(view, text, textDirection)` so VoiceOver speaks it once even when no live-region change is seen; the same text, no extra words. The action is reachable by Tab only while visible; the toast does not take focus. Text size is honoured (grows, wraps at three lines, then ellipsis with the full text in the semantics label).
- App Lock: in the main app, when `AppLockController.covered` is true the host hides the toast, drops the queue and ignores `show` calls until unlock. Conversation windows and the quick panel start no App Lock (`lib/src/windows/conversation_window_app.dart:43-45`); their hosts read the link's `queueVisibility` stream instead (`lib/src/windows/desktop_conversation_windows.dart:256-258`, `:422-424`), which the main engine drives with `queue.locked` and `queue.unlocked` (`lib/src/windows/conversation_windows.dart:254-265`) from `!lock.covered` and the session (`lib/src/chat/queue_storage/queue_persistence.dart:25-30`). `queue.locked` hides the toast and drops the queue there.
- Sign-out, server change: the queue is dropped (a message about the old connection is stale).
- Which results are toasts: a "could not" result is a toast only when the action can be retried or ignored (Try Again as its one action, or none). A failure that needs a decision stays a dialog, and a lasting state stays an `AppBanner`.
- Hosts: `HermesApp`'s `MaterialApp.builder`, `conversation_window_app.dart` and the quick panel's app. A window without a host falls back to the SnackBar.

## Migration

- `AppToast.show(context, text, {tone, action})`; on other platforms it calls `ScaffoldMessenger.maybeOf(context)?.showSnackBar` with the floating behaviour, so output there matches today's.
- Add guard `arch.raw-snackbar` in `test/architecture/architecture_guards_test.dart` with the message "use AppToast.show", allow-listing `lib/src/widgets/app_toast.dart`, and record today's per-file counts in `test/architecture/baseline/arch.yaml`. The ratchet only shrinks: each migration PR lowers it with `UPDATE_BASELINE=1`.
- The first PR migrates the block's own users: the export flow (drops `_aboveComposer`), chat notices, schedules. Other areas follow, one PR per area as needed.

## Risks

- Overlay focus and hit testing: the toast must not steal focus from the composer or block clicks beside it. Test with a focused text field.
- A toast over a modal route: the host sits above the navigator, so it would show over a dialog; it must hide while a modal barrier is up, or show above it only for an action the dialog started. Decide in the design pass.
- Messages carry server text in a few places; they stay in the view, never in telemetry.

## Acceptance

- Catalog (`widgetbook/`): `AppToastView` with every tone, with and without action, one and three lines, German, largest text, light and dark, compact and wide window, hovered, and the reduced-motion state. `test/widgetbook_test.dart` builds them.
- Widget tests: one at a time and replacement; the timer (fake clock, no fixed delays) and the pause on hover; accessible navigation keeps it; a covered app hides it and drops the queue; sign-out drops it; the SnackBar fallback on iOS and Material chrome.
- Semantics test: the live region and the announcement carry the text once; the tone has an icon and a word in the label.
- Architecture guard test: a new raw `showSnackBar` fails; a baseline count that drops without an edit fails (the ratchet's own rule).
- Spec scenarios in `specs/mac-toast/spec.md`.

## Design pass

Canvas "Hermes: Mac Settings window, toast, sub-pages" (private, ask its owner for access): https://claude.ai/artifact/Q36fmBuDK9Gy3jkgBF2g5R. Its "Mac toast" row, one decision per board:

- Today, the full-width SnackBar: a dark Material bar across the bottom, text only, no tone; it covers the composer and the send button.
- Proposed, top centre, light, with action: placement decided (open question 1): top centre of the content pane, 12 pt under the toolbar, never over the sidebar or the composer; 360 pt wide at most; one 28 pt action.
- Proposed, top centre, dark, error: the same capsule on the raised surface (`--h-apple-elevated`) with a 1 px border and the menu shadow; the error reads "Error" beside its icon, not red alone, and is announced assertively.
- Tones, light and dark: each tone leads with its icon and a bold word, Info, Done, Warning, Error (German: Info, Erledigt, Warnung, Fehler; new strings); colour tints only the icon; at most one action, a 28 pt text button; text wraps to three lines at most.
- Alternative, bottom centre 16 pt above the composer: not chosen; it must track the composer's height and clashes with other bottom bars.

Still owed: German, the largest text size, a compact window, over a Kanban board, and the hovered state.
