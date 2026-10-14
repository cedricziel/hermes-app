## Why

The watch can keep conversation text visible after `signed_out`, and the phone can return a remembered reply before checking its current session. Signing out must invalidate every watch-owned copy and pending operation once the watch learns that the session ended.

## What Changes

- Check current phone session availability before reading remembered sends or starting any relay operation.
- Clear open conversations, list state, drafts, retry payloads, recordings, disk caches, and watch status on session invalidation.
- Deliver a content-free invalidation through WatchConnectivity and process it before showing saved data on foreground entry.
- Reject late results from work begun before invalidation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: Session invalidation and private state cleanup.

## Impact

Affected areas include `WatchRequestHandler`, `WatchBridge`, native `WatchRelay`, watch transport, conversation and list models, `ChatCache`, and `VoiceRecorder`. Platforms are iOS and watchOS. No backend route or entitlement changes are required.

Security and privacy: remove cached content and audio; credentials remain exclusively on the phone in secure storage. An unreachable watch cannot be remotely erased immediately. Cleanup occurs when invalidation or `signed_out` arrives.

Observability: retain request result events and add a fixed-name `watch.session.invalidated` outcome event on the phone, plus local Apple cleanup-result logs. Only reason enums, success flags, and counts are permitted. No new spans are needed because existing relay diagnostics cover the boundary. No new breadcrumbs are needed because this change handles session lifecycle rather than a new user step.

Non-goals: remote device erase, secure deletion guarantees for flash storage, clearing operating-system notification history, account-scoped thread identity, or canceling already accepted backend commands. Identity is specified separately in `watch-context-identity`.
