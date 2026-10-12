## Context

RootNavigationQueue already coalesces notifications, links, and shares and waits for actual route dismissal. The two remaining direct handoffs publish ChatOpenRequests before _showChat performs popUntil.

## Goals / Non-Goals

Defer the entire handoff, including chat-request mutation, until guarded departure. Preserve the editor on Stay and keep the latest destination. Do not alter the queue or pretend every external entry point is covered.

## Decisions

Send Show in Main Window and scheduled-run callbacks through _queueExternalNavigation. Construct the NotificationTarget and request/select Chat only inside the authorized action. Existing queue ordering, App Lock gating, disposal, and chat target validation remain. The shared queue also checks current protected authorization, ready state, and the shell's captured owner generation at delivery. Listen for auth changes so a still-mounted same-generation shell can resume; explicit departure can never authorize its old queue. This closes the interval where auth has revoked access but delayed keychain deletion leaves its state ready.

## Risks / Trade-offs

A refused Back waits for manual editor completion, rather than repeatedly prompting. A newer notification/link replaces the pending handoff. Auxiliary window host behavior remains source/widget verified; native lifecycle testing remains open.

## Migration Plan

Start with failing widget regressions for both entry points, then change the two callers. Run the existing external-navigation coverage and window ownership tests before review and CI.

## Open Questions

None for the two callers. Other direct bot/menu/intent callbacks remain separate audit work.
