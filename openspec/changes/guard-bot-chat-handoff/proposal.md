## Why

Opening a bot publishes its canonical chat before the main root guard can protect an editor. A delayed roster or canonical lookup can also apply after session departure or replace a newer external request.

## What Changes

- Publish the bot target and Chat selection only after the existing root dismissal queue permits navigation.
- Reserve bot intent ordering at arrival and retire its lookup when a newer root request arrives.
- Check captured owner authorization before lookup, after each shell await, and before queued delivery.
- Preserve the canonical BotChatContext and existing backend lookup behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `navigation`: Protect the bot roster/menu chat handoff through the shared root guard and latest-request policy.

## Impact

AppShell, focused widget tests, and this change's artifacts. No generated API, dependency, or minimum-version change.

Non-goals: a generic intent broker, bot creation/editing, group routes, authentication route retention, native window behavior, and undoing canonical operations already dispatched. Full owner/broker integration remains separate.

Security and privacy: retired shell lookups cannot publish a target or private failure into a replacement owner. No credential, storage, or telemetry payload changes.

Observability: none added. Existing gateway spans and chat/navigation breadcrumbs cover the reused lookup and handoff without user content.
