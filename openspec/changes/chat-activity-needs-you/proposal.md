# Proposal

## Why

Activity that waits on the user (a billing verification code, a connector sign-in, a reclaimed session) sits in the same scrolling strip as status lines, at the top of the chat, far from where the user answers. It is easy to miss and it competes with everything else for 280 pt. This is the third of four changes (after `chat-activity-panel`; design: https://claude.ai/artifact/JxjvcyRkd7YC9ajQSqvFXn): it docks Needs-you items above the composer, one at a time, like approvals.

## What Changes

- Needs-you items (billing verification details of a pending request, connector operations the user can act on, a reclaimed session) show as one card docked directly above the composer, oldest first, with "1 of N" paging when there are several.
- The card offers the item's own actions (Open page, Copy code; Open, Skip, Continue per target; Reopen) and leaves when the item is resolved, expires, or its scope retires.
- The card is announced to screen readers when it appears.
- The Activity button shows a dot while any Needs-you item exists, and its accessible label says how many.
- Applies to the main chat window (all layouts), Mac conversation windows and the quick panel.
- Needs-you items stop drawing in the strip.

## Non-goals

- A "needs you" mark on sidebar rows or the Dock/menu bar item (the menu bar item already lists requests).
- Operating-system notifications for these items: billing details must never reach a notification, and connector notifications are a separate decision.
- Changing approval or clarify cards, which already live in the transcript.

## Capabilities

### New Capabilities

None (adds to `chat-activity`).

### Modified Capabilities

- `chat-activity`: the docked Needs-you card and the Activity button's marker.
- `agent-billing-verification`: verification details show in the docked card instead of an expandable strip card.

## Impact

- New `NeedsYouDock` widget in `lib/src/chat/activity/widgets/` (plain models: item kind, title, body, actions, position) and a `NeedsYouQueue` that orders items from the billing, connector and session-state controllers by first-seen time.
- `chat_composer_builder.dart` / `ChatThreadView` place the dock above the composer, inside the chat column; `QuickPanelScreen` sizes the panel for it.
- `ActivityButton` gains the dot.
- Widgetbook use cases for each kind, paging, and narrow/wide widths.

## Security and privacy

The billing code and URL keep every existing rule: shown only in-app, cleared under App Lock, never written to preferences, telemetry or notifications. The dock's screen-reader announcement names the kind ("Billing access needs approval") and never reads the code or URL aloud unprompted. Connector URLs stay subject to the HTTPS and authority checks.

## Observability

- Breadcrumb `chat.activity.needs_you.shown` with `kind` (`billing` | `connector` | `reclaim`) and `count` when a new item reaches the front of the queue: explains a later crash in an action handler. Fixed values only.
- Breadcrumb `chat.activity.needs_you.paged` with `count`.
- No new log events or spans: billing and connector outcomes are already logged by their controllers.
