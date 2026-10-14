## Implementation

- [x] Add fresh expiry transition evidence with a failing authentication regression.
- [x] Implement the owner activity coordinator with lifecycle regressions.
- [x] Run focused authentication and coordinator tests, formatting and analysis.
- [ ] Obtain isolated review, merge, then sync and archive the delivered requirements.

Verification: observed the expiry marker regression and seven coordinator behavior regressions fail before implementation. The owner, authentication refresh and local notification batch passed 126 tests; focused analysis and formatting passed. This change does not retain application screens or claim native verification.

Independent source review found mismatched fresh expiry during recovery and auth-first disposal. Both reproduced behavioral failures before fixes. The final owner and full authentication refresh suite passed 65 tests; focused analysis found no issues.
