# Proposal

## Why

Activity that waits on the user (a billing verification code, a connector sign-in, a session that was reclaimed or failed to restore) sits in a card at the top of the chat, far from where the user answers, and is easy to miss. It is the last thing `ChatThreadView` still draws between the header and the transcript. This is the third of four changes (after `chat-activity-panel`, which moved Working and For reference items into the Activity panel; design: `docs/design-briefs/chat-activity.md`): it docks Needs-you items above the composer, one at a time, like approvals, and removes the strip.

## What Changes

- Needs-you items (billing verification details of a pending request, connector operations the user can act on, a reclaimed session or one whose restore failed) show as one card docked directly above the composer, oldest first, with "1 of N" paging when there are several.
- The card offers the item's own actions (Open verification page, Copy code; Open, Skip per target, Continue; Reopen) and leaves when the item is resolved, expires, or its scope retires.
- A Skip or Continue shows "Sending your answer…" and ends within 10 s: a confirmed answer removes the item, anything else shows "Couldn't confirm your answer" and offers the actions again. Nothing is resent automatically. This is a new bound on the connector response, which waits without limit today.
- While the connection is lost the item stays, with its server actions disabled and a plain "Offline" line, instead of silently moving to This session and back.
- The card is announced to screen readers by kind when it appears.
- The Activity button shows a marker while any Needs-you item exists, and its accessible label says how many.
- Applies to the main chat window (all layouts), Mac conversation windows and the quick panel.
- The strip above the transcript is deleted, with the `ChatThreadView` parameters only it used.

## Non-goals

- A "needs you" mark on sidebar rows or the Dock/menu bar item (the menu bar item already lists requests).
- Operating-system notifications for these items: billing details must never reach a notification, and connector notifications are a separate decision.
- Changing approval or clarify cards, which already live in the transcript.
- The Working activity line (change `chat-activity-line`).

## Capabilities

### New Capabilities

None (adds to `chat-activity`).

### Modified Capabilities

- `chat-activity`: the docked Needs-you card, its paging, answer and offline states, the Activity button's marker; the Needs-you tier gains a failed restore and keeps an item while offline.
- `agent-billing-verification`: verification details show in the docked card instead of an expandable strip card.
- `agent-connector-operations`: a response is confirmed or reported unconfirmed within 10 s.

## Impact

- New `NeedsYouDock` widget in `lib/src/chat/activity/widgets/` (plain models: item, kind, title, body, actions, position, status) and a `NeedsYouQueue` that orders items from the billing, connector and session-state controllers by first-seen time.
- `chat_composer_builder.dart` places the dock above the composer, inside the chat column; `ChatThreadView` loses the strip (`chat-activity-strip`) and the parameters only it read (`todoPlan`, and the already unused `moaProgress`, `onMoaDetails`, `processOutputs`, `onProcessOutputDetails`); `QuickPanelScreen` sizes the panel for the dock.
- `ConnectorOperationController` bounds its response wait at 10 s; `activity_tier.dart` keeps an offline item in Needs you.
- `ActivityButton` gains the marker.
- Widgetbook use cases for each kind, paging, answer states, narrow and wide widths.

## Security and privacy

The billing code and URL keep every existing rule: shown only in-app, cleared under App Lock, never written to preferences, telemetry or notifications. The dock's screen-reader announcement names the kind ("Billing access needs approval") and never reads the code or URL aloud unprompted. Connector URLs stay subject to the HTTPS and authority checks. The queue holds item keys and first-seen times only, never a code, URL, reason or title.

## Observability

- Breadcrumb `chat.activity.needs_you.shown` with `kind` (`billing` | `connector` | `reclaim` | `resume`) and `count` when a new item reaches the front of the queue: explains a later crash in an action handler. Fixed values only.
- Breadcrumb `chat.activity.needs_you.paged` with `count`.
- The existing connector log events gain one outcome value, `unconfirmed`, for the 10 s bound; no new log events or spans.
