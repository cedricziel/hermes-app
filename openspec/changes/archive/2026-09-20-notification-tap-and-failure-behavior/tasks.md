## 1. Behavior (shipped in #71)

- [x] 1.1 Announce a reply that broke before it completed as a failed reply
- [x] 1.2 Judge the open chat under the profile the turn was sent under
- [x] 1.3 Select a tapped chat without closing screens above the chat, and close an open thread drawer
- [x] 1.4 Say "Could not open that chat." when a tap or launch cannot open its chat
- [x] 1.5 Hold a tap made while the chat list loads and apply it afterwards

## 2. Specs

- [x] 2.1 Update the notifications and chat delta specs to match
- [x] 2.2 Telemetry: none, nothing to add
- [x] 2.3 No `.claude/skills` entry is made stale by this
- [x] 2.4 Verify: `openspec validate --strict`; the code was verified with dart format, flutter analyze and flutter test in #71
