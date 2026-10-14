## 1. Watcher pause contract

- [x] 1.1 Start with failing tests for held job/profile/baseline work, retained comparison state, and stopped polling; implement epoch-fenced pause/resume with fresh checks.
- [x] 1.2 Start with a failing guarded-service delivery test; pass the watcher activity predicate through guarded notification preparation and preserve simple service compatibility.

## 2. Integration and verification

- [x] 2.1 Wire the watcher pause flag to shell session activity and verify it with held auth cleanup. Coordinate guarded LocalNotificationService delivery with its owner.
- [x] 2.2 Review verification instructions and record native presentation limits; no new telemetry, generated API changes, Widgetbook cases, or skill changes are needed for this watcher boundary.
- [ ] 2.3 Run dart format, flutter analyze, focused watcher/shell/notification tests, strict OpenSpec validation, and the applicable verify-in-app check or explicitly record unavailable native evidence. Deliver one bounded fix(schedules) PR.

AppShell integration uses the same mounted, ready, protected-request, and captured-owner-generation authorization check as external navigation. Authorization closure pauses the watcher and invalidates availability detection synchronously. Authorized recovery resumes polling only for the same mounted owner. Four new shell tests failed for initial unauthorized requests, continued paused polling, stale availability clearing the baseline, and retired-owner polling before the fix. All 147 AppShell, deep-link, and watcher tests now pass. Formatting, focused analysis, diff checks, and strict OpenSpec validation pass. Native notification presentation and the isolated in-app verification remain unverified. Guarded local notification preparation is implemented by its separate owner.

Deferred separate slice: AppShell bot opening still starts roster and canonical-chat RPC work without the shell authorization gate and directly calls `_showChat()` after those awaits. It needs behavioral fake-gateway coverage for suspension, latest-intent arbitration, and unsaved-route dismissal before changing that navigation path. No bot navigation changes are included in this schedule integration.

Final isolated-checkout verification: all 182 watcher, shell and local notification tests passed. Independent source review found no further actionable findings. Native presentation and interaction remain unverified; no real notifications were dispatched by these tests.
