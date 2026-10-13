## 1. Posting result

- [x] 1.1 Start with failing native-adapter tests for accepted posts, plugin errors, unavailable support, and permission refusal. Add a result-bearing posting operation while retaining the never-throwing `show` wrapper for existing callers.
- [x] 1.2 Start with failing background tests where posting returns failure rather than throwing. Post per chat before saving represented request marks and keep failures eligible for later live checks.

## 2. Interruption and privacy

- [x] 2.1 Start with failing post-before-mark interruption and partial-batch and announcement-persistence failure tests. Reuse the stable profile/chat notification ID on retry, preserve generic-wait equivalence, and keep unrelated checks independent.
- [x] 2.2 Start with failing resolved-before-retry, foreground suppression, disabled permissions, and App Lock content tests. Retain existing categories and verify no stale request produces a retry.
- [x] 2.3 Start with failing telemetry privacy and throwing-logger tests. Add accepted/failed attempt and mark-failure counts to `background.task`, `background.request_alert.post_failed` with fixed reason and error type, and `background.request_alert.mark_failed` with error type only.

## 3. Verify and reconcile specs

- [x] 3.1 During implementation spec sync, explicitly supersede the unarchived background-refresh remember-before-post clause after that capability is integrated. Preserve all other request and generic-wait requirements. Inspect project-local and legacy verification skills and update affected retry instructions only if stale. No API regeneration applies.
- [x] 3.2 Keep this fix under roughly 500 changed lines with `fix(notifications): retry unaccepted background request alerts`.
- [ ] 3.3 Run `dart format`, `flutter analyze`, notification-adapter and background `flutter test`, and isolated `verify-in-app`. Exercise a pending approval, simulated native failure, later accepted retry, and post/mark interruption. Record OS acceptance separately from observed presentation.
