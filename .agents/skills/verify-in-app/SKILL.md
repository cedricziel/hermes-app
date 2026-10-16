---
name: verify-in-app
description: Verify UI, connection, authentication, or API changes against an isolated throwaway Hermes backend and client.
---

# Verify in the running app

Read and follow `.claude/skills/verify-in-app/SKILL.md` from this repository.
It contains the shared verification procedure and client-isolation prerequisite.
Use Codex computer-use tools for native UI actions. Do not launch a fixture
until its client storage and routing are isolated from personal app state.
For Chats-first navigation and profile-recipient checks, also follow
[`messenger-chats.md`](../../../.claude/skills/verify-in-app/scenarios/messenger-chats.md).

## Watch companion verification

For watch changes, follow [the isolated watch procedure](../../../.agents/skills/verify-watch/SKILL.md).
Core tests do not establish native delivery or device lifecycle behavior.
