## Context

See proposal.md. ConversationWindows stores targets by server only, closes them from the delayed signedOut stream, and checks native header callers by window ID/server. The HTTP foundation exposes immediate protected access, verified owner proof, and owner generation.

## Goals / Non-Goals

Close auxiliary processes immediately on suspension, restore targets only for their verified owner, and fence native creation/header/storage races. Preserve existing conversation/profile/frame behavior for matching owners. Main navigator drafts, main transport suspension, and native-window draft preservation remain separate layers.

## Decisions

Use a window connection value containing normalized server, auth mode, and a deterministic owner key. For gated access derive the key from a JSON tuple of the server-verified server/user/organization/provider and SHA-256; missing verified user proof supplies no window connection. Anonymous access uses a distinct server-scoped tuple. Persist that non-secret key alongside existing conversation target metadata, never tokens or drafts. Legacy gated records without a key fail closed.

Bind the window manager to AuthController changes and remove that listener on disposal. On the first protected-access loss, invalidate tracked windows and pending native work synchronously and start closeAll before credential deletion finishes. Retain saved targets on expiry only when verified expired-owner proof exists. Explicit departure or owner-generation changes discard old restoration targets. Once a usable owner returns, restore only matching records; mismatched/legacy records are removed before native creation.

On initial binding, close untracked native engines before restoring matching targets. Serialize native close operations and wait for them and late retired creations before new creation/restoration/panel toggles. Propagate native close failures and block new engines until a successful retry. Fence native inventory snapshots with mutation and query epochs so an old read cannot remove a fresh window. Capture generation/connection across each await and recheck before exposing a new window, focusing it, or returning headers. Native callbacks from unknown/retired windows cannot select a chat, reveal the current profile, publish focus/title state, or transfer a draft. Existing window IDs are resolved only within the current tracked lifetime. Queued Show in Main requests retain their generation and owner and are checked again at delivery.

Serialize saved-window writes with snapshots and await pending writes before loading. An old save cannot overwrite explicit forgetting or newer-owner metadata. Retain targets, not native-window drafts, across expiry.

Observability: record fixed initialized, suspended, resumed, and close_failed window-session outcomes through Breadcrumbs, with restoration permitted as a boolean only. Existing window count breadcrumbs remain. Never record fingerprints, server addresses, user IDs, profiles, titles, tokens, or draft content.

macOS auxiliary windows are affected; other platforms retain existing availability and watchOS retains the phone relay. No native entitlement/project, dependency, API route, RPC method, or minimum Hermes Agent version changes. Existing session REST routes and /api/ws remain unchanged.

## Risks / Trade-offs

Legacy saved windows cannot prove ownership and will not reopen automatically; opening a new window records its current verified owner. Anonymous-to-gated changes must not match. Failed native close must not grant access or allow old completion to affect a later owner. Main-view activity and navigator visibility remain unresolved until subsequent slices.

## Migration Plan

Ship after failing ownership/race tests, current-head isolated review, analysis/tests/spec validation, and isolated macOS window lifecycle verification. Then suspend main activity and implement retained navigation.

## Verification record

The isolated macOS fixture built successfully with memory preferences/tokens,
a unique Debug app/extension namespace, no ordinary URL schemes or Services,
a unique disabled Handoff type, and no App Group entitlement. The backend
reported its fresh throwaway home. Native controls could not bind the new
bundle reliably and then stalled while the Flutter runner disconnected.
Window lifecycle interaction was not verified; automated real-auth manager
and native MethodChannel regressions cover the retirement and close barriers.
Temporary runtime/project substitutions were removed after fixture shutdown.
