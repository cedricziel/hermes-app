## Why

The app calls its messaging-platform settings “Bots”, while Hermes Bot Mode uses that name for persistent specialist agents. Reserve “Bots” for those agents and make messaging connections easy to distinguish before introducing Bot Mode.

## What Changes

- Rename the messaging destination and screen to “Messaging”, with explanatory copy “Connect Hermes to Telegram, Discord, and other messaging platforms.”
- Use “messaging platform” in generic setup, loading, and error copy; retain “Telegram bot” and platform-specific credential labels where technically accurate.
- Rename the internal messaging models, repositories, screens, and callbacks to make a separate Bot Mode feature unambiguous.
- Update Widgetbook, workflows, README, and the existing behavior specification.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `profiles-and-bots`: Messaging navigation and generic platform terminology.

## Impact

Affected areas: `lib/src/bots/`, repository composition, chat navigation, management tests, and Widgetbook. Existing `/api/messaging/*` contracts remain the integration point. No dependency or minimum-server-version change.

Non-goals: This PR does not implement Bot Mode. The coordinated release also includes `bot-mode-roster`, `bot-mode-chats`, `bot-mode-group-protocol`, and `bot-mode-groups`; groups and agent messaging belong in that first release, as requested.

Security and privacy impact: None. Existing redaction, ephemeral setup fields, and server-side Telegram token handling remain requirements.

Telemetry: None added; existing opt-in HTTP instrumentation continues.
