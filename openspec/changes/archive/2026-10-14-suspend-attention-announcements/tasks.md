## 1. Announcement suspension

- [x] 1.1 Start with failing tests for paused and disposed announcements, held permission results, and pause followed by resume. Implement an optional activity signal and epoch checks.
- [x] 1.2 Start with a failing held native-preparation test. Supply guarded delivery authorization and preserve ordinary-service compatibility.
- [x] 1.3 Verify that taps and held launch targets still reach the routing owner while paused and that device permission results remain recorded.
- [x] 1.4 Start with failing regressions for earlier activity listeners and reentrant resume; read live activity at dispatch and invalidate old work on each delivered activity notification.

## 2. Integration and verification

- [ ] 2.1 Root integration supplies the shared session activity signal and verifies guarded LocalNotificationService delivery.
- [ ] 2.2 Run dart format, flutter analyze, focused notification tests, and strict OpenSpec validation. Record unavailable native evidence under the shared verify-in-app isolation rules. Deliver one bounded fix(notifications) PR under 500 changed lines.
- [x] 2.3 No new telemetry, generated API changes, Widgetbook cases, or project skill updates are needed for this local notification boundary.
