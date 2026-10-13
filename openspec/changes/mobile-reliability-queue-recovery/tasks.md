## 1. Reviewed recovery interface

- [x] 1.1 Start with failing widget tests and add Widgetbook cases for recovered FIFO entries, review-required state, unknown submission, unavailable session, App Lock, and persistence failure before wiring the component into chat.
- [x] 1.2 Start with failing composer-preservation and double-submit tests. Await the durable-store enqueue commit before reporting success or clearing composer text and attachments.
- [x] 1.3 Start with failing restart, profile-reload, profile-switch, and same-ID/different-profile tests. Restore entries by exact stable identity with a review barrier that cancels settle timers and prevents implicit draining.

## 2. Submission ownership

- [x] 2.1 Start with failing transport tests for accepted `streaming`, `queued`, `redirected`, and `steered` results and lost replies. Expose the existing acceptance boundary without adding an RPC field or changing backend retry behavior.
- [x] 2.2 Start with failing before-submit and after-submit crash tests. Commit submission-started before network dispatch, remove local ownership only on known acceptance, and retain unknown outcomes with no automatic resend.
- [x] 2.3 Start with failing user-action tests. Wire Send next, inspect conversation, and discard actions, preserving the review barrier for remaining restored records and retaining existing live-queue FIFO/settle/stop behavior.
- [x] 2.4 Start with failing deletion, sign-out, unavailable-session, and lock-visibility tests. Bind scoped storage cleanup to existing lifecycle actions without rebinding entries to a new chat.
- [x] 2.5 Start with failing privacy and logger-failure tests. Add `chat.queue.recovery` and the three proposal breadcrumbs, carrying only fixed outcomes, states, and counts.

## 3. Verify and ship

- [x] 3.1 Check project-local `verify-in-app` and legacy `.claude/skills` for affected recovery guidance. Update the relevant skill only when it becomes stale. Preserve the full existing Queued messages scenarios when syncing this delta. No OpenAPI regeneration is required.
- [x] 3.2 Keep integration separate from encrypted storage and target roughly 500 changed lines. Use `feat(chat): recover queued prompts for review`; split a coherent preparatory refactor if actual integration exceeds the review budget.
- [ ] 3.3 Run `dart format`, `flutter analyze`, queue/widget/transport `flutter test`, and the isolated `verify-in-app` loop. Queue a text and attachment, restart, switch profiles, verify zero submissions before review, explicitly send one entry, and exercise an unknown submission without sending a duplicate.

Automated evidence: the initial isolated recovery implementation passed 236 tests. After reconciliation with merged session usage and the three queue preparatory layers, the extracted feature passed 296 queue, window, activity, composer, usage, gateway, and lifecycle regressions, 24 queue Widgetbook cases, full analysis, and formatting. Submission proof, storage access, and window coordination are separate preparatory PRs. The extracted recovery layer still needs native restart/keychain verification; task 3.3 remains open.
