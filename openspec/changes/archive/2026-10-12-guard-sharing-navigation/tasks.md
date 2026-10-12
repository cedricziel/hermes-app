## 1. Guarded sharing

- [x] 1.1 Add failing integration regressions for dirty/busy editors, accumulated text/files/latest quote, and no chat mutation before dismissal.
- [x] 1.2 Queue warm/held share delivery without consuming payloads early. Keep existing quote breadcrumb and standalone behavior.
- [x] 1.3 Add failing replacement/repeated-Chat-entry, deferred recovery ordering, delayed launch lookup, App Lock, and disposal tests; implement deliberate Chat-entry recovery and once-only delivery.

## 2. Verification and delivery

- [x] 2.1 Run formatting, analysis, share/chat/navigation suites, strict OpenSpec validation, and isolated app verification where applicable. Update stale skills only if needed.
- [x] 2.2 Obtain current-head review, address findings, pass CI/builds, merge, sync/archive, and update the backlog.
