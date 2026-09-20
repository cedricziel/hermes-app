## 1. Transport

- [ ] 1.1 Test first: an unhandled request for a session with no reply in flight, and one that arrives after the reply ended, are not refused
- [ ] 1.2 Track the runtime sessions with a reply in flight and refuse an unhandled request only for those

## 2. Wrap up

- [ ] 2.1 Telemetry: none, nothing to add
- [ ] 2.2 No `.claude/skills` entry is made stale by this
- [ ] 2.3 Sync the delta into `openspec/specs/chat/spec.md` and archive the change
- [ ] 2.4 Verify: dart format, flutter analyze, flutter test, `openspec validate --strict`; not checked against a running gateway
