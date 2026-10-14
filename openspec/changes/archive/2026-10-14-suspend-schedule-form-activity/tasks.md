## 1. Regression Tests

- [x] 1.1 Add failing controller tests for paused metadata reads/saves, dropped late reads, fresh metadata after recovery, stale save cancellation, and preserving a newer save barrier during stale-save notification.
- [x] 1.2 Add a failing JobFormScreen test proving nested activity notifications cancel an earlier save while a save attempted during the live inactive window is rejected; keep the route open and do not present cancellation as a form error.

## 2. Activity Boundary

- [x] 2.1 Add optional activity, a live getter, epoch checks, paused metadata-read suppression, and metadata-only refresh on resume to JobFormController.
- [x] 2.2 Add typed save cancellation and handle it in JobFormScreen without popping or revealing a form error.

## 3. Verification

- [x] 3.1 Run Dart formatting, Flutter analysis, focused form and schedules workflow tests, and strict OpenSpec validation. The focused suite passed 61 tests.
- [ ] 3.2 Verify session recovery in-app after owner wiring and client isolation are available. No telemetry signal is added because cancellation is expected lifecycle behavior.
