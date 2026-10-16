## Context

See proposal.md for the accepted direction and first-slice scope. `AppShell` owns destinations and queued external navigation. `ChatScreen` owns the chat controller, composer, thread selection, and activity panel. It currently puts `ThreadSidebar` in a 280-point drawer on narrow layouts. Wide layouts display that list beside the transcript. macOS has its own sidebar visibility and compact overlay rules in the chat specification.

`HermesChatRepository.loadThreadPage` uses the generated sessions client with explicit profile, recent order, archived exclusion, offset, and limit. `ThreadSidebar` already receives thread data, search, housekeeping, and callbacks. Reuse these behaviors rather than creating another repository or chat controller.

## Goals / Non-Goals

Goals: Give compact phone layouts a Chats root and a conversation detail that returns to the same list. Preserve one owner for drafts, queues, transport, and activity.

Non-goals: All-agent list aggregation or importing the artifact's entire agent model into this navigation PR. Locally selected profile-scoped lists remain an intermediate state. Existing bot and group destinations remain reachable through the menu.

Platforms: iOS and Android gain list/detail navigation on compact layouts. iPad and wide Android layouts keep list/detail side by side. macOS, Windows, and Linux retain their existing wide layout and desktop navigation behavior. macOS compact overlay behavior remains unchanged. Local recipient selection applies to all five Flutter target platforms, including macOS, Windows, and Linux. watchOS navigation is unaffected. No entitlement, manifest, or Xcode project changes.

## Decisions

### Keep chat state above list/detail presentation

Retain the existing controller and transport owner across list/detail navigation. Returning to Chats changes presentation without closing the session, clearing a draft, cancelling a queued prompt, or stopping generation. Do not push a second independently owned `ChatScreen`: duplicate owners would complicate resume and activity listeners.

Use route-aware Back handling for compact detail presentation so iOS edge Back and Android system Back return to Chats. A guarded editor or modal above detail handles Back first. Layout changes reuse the selected thread and controller; narrowing with an explicit selected or composing detail keeps that detail visible, while an untouched home stays on Chats.

### Reuse list content independently of its drawer frame

Extract only the presentation needed to render existing list sections and controls at full available width. Chats gets a title, shell menu, search, and New message action. Do not place a full-width page inside a fixed-width drawer. Retain paging, ordering, thread actions, error/retry, and draft rows.

An explicit New message action offers the available profiles as recipients and opens the new-chat composer under the selected profile. Creating that draft must not send a prompt. Returning preserves the draft using existing draft behavior. Before first send, changing the recipient updates profile-dependent models, starters, and microphone availability; an unsupported model selection is cleared. After sending, the conversation owner is fixed.

### Reuse avatar identity across messenger surfaces

Provide a reusable profile avatar with row, recipient-chip, and header sizes using existing theme tokens. Read configured avatar imagery through the connected server's existing supported profile-asset contract. Where image retrieval is unsupported, absent, invalid, or fails, render a deterministic monogram and color from profile identity. Reuse the roster presentation where available rather than introducing an image upload pipeline.

Keep image lookup and any in-memory cache scoped to server, account, and canonical profile. Clear that state on sign-out or account/server replacement, and reject stale image results after recipient changes. Do not fetch arbitrary external avatar URLs, write profile assets, or change profile metadata just to display an avatar. Preserve the visible name and accessible recipient label; avatars must not be the only way to distinguish agents.

Conversation rows, New message recipients, and chat headers use the same profile identity across compact and wide layouts on all Flutter platforms. Groups use a visually distinct group avatar when the separately planned group-list integration ships. This requirement does not pull group protocol work into this PR.

No new avatar endpoint or minimum backend version is required: configured images are an enhancement when the existing asset contract is supported, and monograms work without it. The pinned gateway contract uses `profiles.get_asset` with `name` and `asset: avatar`, returning `found`, `mime`, `size`, and a `data` URL. Accept only bounded PNG, JPEG, or WebP data and fall back when unsupported or invalid. Image content and profile identity remain excluded from added telemetry; this feature adds none.

### Keep external navigation authoritative

Ordinary launch enters Chats. Accepted deep links, notification taps, shared-content flows, and explicit new-chat actions open their target detail through the existing shell navigation queue. Do not reset presentation to Chats after an asynchronous target resolves. Retain App Lock, route dismissal guards, capability discovery, and latest-intent ordering.

### Keep the first PR independent

Deliver the feature through coherent commits for local recipient selection, avatar components, conversation ownership, and Chats navigation. The original roughly 500-line estimate proved too small for the accepted avatar requirement and ownership regression coverage. Reuse list content and existing transports, and retain all required behaviors in the completed feature. Later changes implement all-agent aggregation and unified agent management, then messenger preview rows and group-list integration. Each needs its own proposal and acceptance checks. The existing bot-mode changes remain independent prerequisites where their contracts are reused.

The artifact's Agents label is the destination model for the finished direction. This slice keeps current Profiles and Bots labels because a rename alone would imply unified behavior that does not exist yet.

### Select a recipient without mutating the server default

`ChatProfiles.switchTo` and `ProfilesScreen._choose` currently call `HermesProfilesRepository.setActive`. Remove that side effect from chat selection on desktop and mobile. Reuse profile-explicit history and transport APIs. New message, opening a profile, selecting a history row, sending, resuming, and reconnecting must not call POST /api/profiles/active or edit profile configuration. Session creation and message persistence on the server remain normal chat behavior.

Keep the server active marker distinct from the local recipient. With no local selection, initialize from the existing read-only active-profile lookup. An explicitly selected recipient always wins and must never silently fall back to the server default if unavailable. Keep local recipient state per window; this slice adds no cross-launch preference. A terminal-default change, if offered, must be separately labelled and explicitly invoked.

Identify chat state by profile plus session ID, including drafts, pending requests, queued prompts, and transport resume. Reject results from a stale recipient selection. Failure to load a selected profile keeps a visible Retry state and sends nothing under another profile. Keep existing chat ownership when another client changes the server default.

The existing `profiles-and-bots` Switching profile requirement mandates a sticky-default write. The accompanying delta replaces that behavior for chat selection; it is not an optional implementation detail.

### Preserve contracts and privacy

Use existing generated REST calls and `/api/ws` transport unchanged. No OpenAPI regeneration or new minimum backend version is needed. Preserve secure token storage, concurrent refresh behavior, App Lock, and account/server state teardown. No additional spans, events, breadcrumbs, or attributes are added because this slice changes presentation only. Existing diagnostics retain their privacy restrictions.

## Risks / Trade-offs

- Back could dispose active chat work. Keep ownership above presentation and exercise running and queued turns while returning to Chats.
- Breakpoint changes could show the wrong page. Cover list, selected detail, and composing detail while resizing in both directions.
- External navigation could be masked by home initialization. Exercise delayed launch targets and warm taps through the existing queue.
- A profile-scoped Chats list is an intermediate product state. Preserve current scope visibly and do not advertise all-agent search until the aggregation change ships.
- Profile switches can mix identically named session IDs or stale results. Test two profiles with the same session ID and a delayed response; bind state and requests to the profile owner.
- The catalog or verify workflow could still expect a drawer. Update the affected cases and instructions in the implementation PR.

## Migration Plan

No data migration. Deploy the presentation change with existing saved chats and drafts. Reverting the PR restores drawer presentation without converting stored state. Validate against an isolated throwaway backend and app profile before shipping.
