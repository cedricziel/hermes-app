## 1. Protect asynchronous action errors

- [x] 1.1 Add a widget regression test that keeps the messenger mounted, disposes the action caller, then completes a pending action with an error and expects a normal failure result without a UI exception.
- [x] 1.2 Guard snackbar presentation after an action fails so disposed callers do not present UI; keep the existing visible error for mounted callers.

## 2. Make Quick Look completion tests deterministic

- [x] 2.1 Add an explicit completion signal to the Quick Look test fake and await it in the gated transfer and preview breadcrumb tests instead of relying on a fixed real-time wait for action completion.

## 3. Verify

- [x] 3.1 Run formatting, analysis, the focused Kanban error and Quick Look tests, and strict OpenSpec validation.

- [ ] 3.2 Obtain isolated current-head review, pass CI/builds, merge, sync/archive, and update the navigation backlog. Native interaction remains unverified; the UI lifecycle regression uses widget tests.
