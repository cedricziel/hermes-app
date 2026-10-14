# Design

## Context

`ChatThreadView` (`lib/src/chat/widgets/chat_thread_view.dart`) builds a list of activity cards and stacks them above the transcript in a scroll view capped at 280 pt. Some cards draw a placeholder for a state with no value: `TodoPlanCard` shows "Plan unavailable" when attached without a snapshot, `SessionUsageCard` shows "Session usage is unavailable on this server", `BillingVerificationCard` shows "Billing verification unavailable" when `supported` is false. The strip is added whenever its list is non-empty, even when every entry draws only a placeholder.

## Goals / Non-Goals

**Goals:**

- One place that says which tier an activity kind belongs to, so the three later changes route by it instead of each re-deciding.
- Empty and unsupported states stop drawing, and the strip's container is left out when nothing in it has content.

**Non-Goals:**

- Moving cards or changing their look (later changes).
- Changing controller state: the controllers keep "unavailable" as a state; only the presentation changes.

## Decisions

- **Decide visibility from state, not from rendered size.** Each activity source gets a `hasContent` style check next to its state (plan: attached and snapshot with entries; usage: supported and a snapshot or stale snapshot exists; billing: supported). `ChatThreadView` adds an entry to the strip only when its check passes. Alternative considered: cards returning `SizedBox.shrink()` (the todo card already does for an empty plan). Rejected because the strip still adds its container and the 280 pt cap for an all-empty list.
- **Tier as a plain enum with a pure mapping function.** `ActivityTier { needsYou, working, reference }` and `tierOf(...)` functions per source (`lib/src/chat/activity/activity_tier.dart`). A connector operation's tier depends on its state (settled, authority, offered actions), so the mapping takes the operation and its controller's answers. Alternative: an interface implemented by every controller. Rejected: it would touch ten controllers for a decision that only presentation needs.
- **The idle billing row stays in this change.** The spec requires the Verify action to be offered while availability is unknown; hiding it before the Activity panel exists would remove the only way to start verification.

Platforms: iOS, Android, macOS, Windows, Linux (shared Flutter UI). No native, entitlement, manifest or Xcode change. No invariant from the project context is touched: no auth, API or telemetry change.

## Risks / Trade-offs

- [A server that is merely slow to send its first plan shows nothing until then] → Intended: absence means nothing to report; the plan appears with the first `todo.updated`.
- [The tier mapping is unused by any UI in this change] → It is covered by unit tests here and consumed by `chat-activity-panel` next; keeping it here keeps the later PRs smaller.
