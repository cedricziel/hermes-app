## 1. Guard deep-link navigation

- [x] 1.1 Add failing workflow tests for dirty editor protection, latest-link delivery after Discard or Save, and a guarded route beneath a clean route.
- [x] 1.2 Add a reusable serial navigation queue with disposal cancellation and migrate deep-link delivery to it. Keep existing breadcrumbs; no new observability signals or catalog widgets are introduced.
- [x] 1.3 Add regressions for busy routes, App Lock during waiting, disappearing destinations, and shell disposal.

- [x] 1.4 Add failing save-race regressions and block Skill/schedule editor dismissal until save completion, retaining failed-save drafts and errors.

## 2. Verify and deliver

- [x] 2.1 Run dart format, flutter analyze, focused tests, the full relevant suite, OpenSpec validation, and the isolated verify-in-app loop. Update stale project skill guidance only if this change reveals a reusable gap.
- [x] 2.2 Obtain an isolated review when CodeRabbit is limited, address findings, open a fix(navigation) PR, pass required checks, and merge. Sync and archive the completed spec, then update the backlog.
