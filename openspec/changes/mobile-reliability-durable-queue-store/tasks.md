## 1. Protected storage adapter

- [x] 1.1 Start with failing restart, FIFO, account/profile/session isolation, and corruption-isolation and index-rebuild tests. Add the versioned local record model and encrypted storage adapter, using separate authenticated record payloads so one corrupt record does not lose others.
- [x] 1.2 Start with failing attachment-retention and interrupted-commit tests. Add encrypted app-owned attachment copies, atomic envelope commit and recoverable index, and orphan cleanup while preserving existing size limits. Add the authenticated-encryption dependency through normal package tooling.
- [ ] 1.3 Start with failing missing-key, locked-storage, and payload-exposure tests. Add secure-key handling and platform backup exclusion; verify no prompt, metadata, or bytes enter preferences, backups, or shared surfaces.

## 2. Submission state and cleanup

- [x] 2.1 Start with failing crash-boundary tests. Implement durable submission-started and acceptance transitions so a stopped process never resets an uncertain entry to unsent.
- [x] 2.2 Start with failing sign-out, server-removal, conversation-deletion, and unavailable-cleanup tests. Add scoped deletion and cleanup tombstones, retaining records on profile switch and preserving unrelated accounts.
- [x] 2.3 Start with failing telemetry privacy and throwing-logger tests. Add `chat.queue.storage` spans and `chat.queue.storage_failed` events with the fixed attributes named in the proposal.

## 3. Verify and prepare integration

- [x] 3.1 Review the project-local verification skill and any legacy `.claude/skills` entry for stale queue-storage instructions. Update only guidance made stale by this change; document temporary storage and fake-key verification when needed. No API regeneration is required because no route changes.
- [ ] 3.2 Keep this PR limited to the storage adapter and its tests, aiming for roughly 500 changed lines. Use `feat(chat): add protected durable queue storage`; leave controller and UI integration to the dependent proposal.
- [x] 3.3 Run `dart format`, `flutter analyze`, and relevant `flutter test` storage suites. Verify restart, original-file deletion, failed commits, and key unavailability in isolated temporary storage. No UI or connection behavior changes in this proposal require an app launch.
