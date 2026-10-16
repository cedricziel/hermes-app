## Why

The user chose a messenger direction for Hermes, with Chats as home. On a phone, conversations currently sit in a drawer beside the open chat, making the conversation list a secondary destination.

## What Changes

- Open compact layouts on a full-page Chats list after ordinary sign-in or launch.
- Open a selected conversation with a back action to Chats, preserving its draft and ongoing work.
- Offer a local profile recipient picker through New message on every Flutter platform. Opening, sending, and resuming a chat use its owning profile explicitly and never change the server active profile, profile configuration, or terminal default.
- Keep recipient and model selectors visible side by side, with explicit loading, incomplete-configuration, error/retry, and ready states on every Flutter platform. Offer configuration guidance when options are missing instead of hiding a selector.
- Show profile avatars in conversation rows, the recipient picker, and chat headers, using configured images where supported and a deterministic monogram fallback. Define a distinct group avatar for group conversation surfaces when Groups integration ships.
- Keep an existing chat bound to its original profile. Selecting a different recipient starts or resumes a separate conversation.
- Keep a persistent conversation list beside the chat on wide layouts, including macOS.
- Keep the shell menu accessible from Chats for the existing agent management, Kanban, and Schedules destinations, subject to their existing capability gates.

This is the first independently shippable slice of the accepted messenger direction. The complete direction also includes conversations across agents, richer preview rows, unified Agents management, and a Groups section. Those remaining features need separate changes because profile ownership and group transport already have substantial behavior and active OpenSpec work.

## Capabilities

### New Capabilities

- `messenger-navigation`: Chats-first compact navigation and persistent wide conversation navigation.

### Modified Capabilities

- `profiles-and-bots`: Selecting a chat profile becomes local instead of changing the server active profile. Explicit terminal-default changes remain separate.

Existing ordering and paging remain unchanged. Lists may remain scoped to the locally selected recipient until the all-agent aggregation change.

## Impact

Affects `lib/src/shell/app_shell.dart`, `lib/src/chat/chat_screen.dart`, `lib/src/chat/widgets/thread_sidebar.dart`, `lib/src/profiles/chat_profiles.dart`, `lib/src/profiles/profiles_screen.dart`, profile-aware chat operations, relevant shell and chat tests, and Widgetbook. Reuse existing session APIs and gateway ownership. No backend, generated client, package, or native-project changes.

Non-goals: Combining profiles, renaming Profiles and Bots before their behaviors converge, adding a terminal-default action, redesigning transcript content, changing group protocol, adding unread tracking, or changing notification delivery. Existing activity-panel changes remain separate.

Security and privacy impact: No new storage of message content or credentials. Recipient selection and avatar display do not mutate profile settings or the server default. Avatar reads use the authenticated server connection; no third-party avatar service or new persistent image cache is introduced. Preserve App Lock, sign-out, server/account isolation, and secure token storage. Opening Chats must not send a message or mark an unseen conversation as read.

Observability: None added. Reuse existing session loading and profile-scoped request diagnostics. Local recipient selection adds no background work or telemetry attributes.
