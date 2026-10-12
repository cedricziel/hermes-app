## 1. Session client safety

- [x] 1.1 Add failing controller/HTTP regressions for slow departure cleanup, stale client use after another account/server, delayed refresh/401 responses, and same-owner restoration.
- [x] 1.2 Add immutable verified-owner proof and logical owner/request lifetimes; suspend protected access before cleanup and fence credential attachment, retries, responses, and header lookups.
- [x] 1.3 Add failing storage-ordering regressions, serialize writes/clears, and preserve candidate/bootstrap verification plus token rotation/adoption behavior.
- [x] 1.4 Add and test the fixed-reason client-retirement event without identity or content attributes.

## 2. Verification and delivery

- [x] 2.1 Run formatting, analysis, relevant auth/controller/workflow suites, strict OpenSpec validation, and isolated app verification where applicable. Update stale project skills only if needed.
- [x] 2.2 Obtain current-head review, address findings, pass CI/builds, merge, sync/archive, and update the backlog. Keep navigator/draft recovery explicitly open for the next layer.

Verification: 124 auth/window-auth/auth-gate/onboarding tests passed; analysis and strict OpenSpec validation passed. macOS verification against an isolated backend connected to Hermes 0.21.5 at the checkout-local throwaway home, departed through Change server, and reconnected. The pushed Connection Details route remained visible until Back revealed setup, confirming the still-open navigator layer. Native client-storage isolation was not verified. Native gated login/expiry was not exercised; controller tests use real loopback HTTP with held responses and storage operations.
