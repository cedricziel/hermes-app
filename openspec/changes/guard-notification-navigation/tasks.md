## 1. Warm and launch notification safety

- [x] 1.1 Add failing warm-tap regressions using dirty editors, Keep editing, failed Save, and latest-target delivery.
- [x] 1.2 Wire the host navigation queue before warm notification mutation and protect scheduled-job delivery/availability. No new catalog widgets are introduced.
- [x] 1.3 Add failing launch-notification and warm-versus-launch ordering tests, then route launch handling through the same guard without changing standalone no-fetch/profile behavior.
- [x] 1.4 Add failing lock/disposal/availability-ordering regressions, implement the required resume and cancellation behavior, and test the fixed-attribute unavailable-job breadcrumb.

## 2. Verification and delivery

- [x] 2.1 Run formatting, flutter analyze, relevant notification/navigation/editor suites, OpenSpec validation, and the isolated app verification loop where applicable. Update stale skills only if needed.
- [ ] 2.2 Obtain current-head review, address findings, pass required CI/builds, merge, sync/archive this change, and update the backlog.
