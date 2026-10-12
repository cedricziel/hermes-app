## 1. Auxiliary session safety

- [x] 1.1 Add failing real-auth/window-manager regressions for immediate suspension during held credential cleanup, same-owner restoration, changed/missing owner proof, and explicit departure.
- [x] 1.2 Add owner-scoped window connection/records and bind window lifecycle to immediate auth access; reject legacy gated records without proof.
- [x] 1.3 Add failing held-operation regressions and fence native creation/close/header callbacks, stale navigation/profile callbacks, and saved-state writes.
- [x] 1.4 Add and test fixed initialization/suspension/restoration/close-failure breadcrumbs without owner or content attributes.

## 2. Verification and delivery

- [x] 2.1 Run format, analysis, relevant window/auth/workflow suites, strict spec validation, and attempt isolated macOS lifecycle verification. Record any native-control limitation and update project verification guidance.
- [x] 2.2 Obtain current-head isolated review, fix findings, pass CI/builds, merge, sync/archive, and update the navigation backlog. Main activity/navigator draft recovery remains open.
