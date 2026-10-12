## 1. Suspend voice work

- [ ] 1.1 Start with failing tests for held support/model results, inactive start/download, and fresh capability-only resume; implement optional activity fencing in composer dictation.
- [ ] 1.2 Start with failing tests for held microphone shutdown, late partial/upload results, and held recorder acquisition; restore typed text and selection synchronously and serialize recording cleanup.
- [x] 1.3 Start with failing tests for active disposal release, paused release, and held acquisition ordering; retain captured lease cleanup until authorized resume and expose inactive-disposal handoff.
- [ ] 1.4 Integrate owner-held cleanup for inactive composer disposal; retain it only for its original session and never flush under another owner's credentials.
- [x] 1.5 Start with failing real stop-and-send tests for a pause during transcript and silence settlement. Mark the invalidated completion cancelled, preserve the typed value, and prevent sending that draft.

## 2. Verify

- [x] 2.1 Confirm existing cancellation breadcrumbs remain content-free; no new observability signals or API routes are introduced. Review project skills for stale instructions; no new workflow skill is expected.
- [ ] 2.2 Run dart format, flutter analyze, focused flutter tests, and the integrated verify-in-app loop when shell wiring is available. Use only synthetic audio in tests, with no physical microphone access.

Planned commit: `fix(voice): suspend composer dictation with session activity`. Voice lifecycle and lease cleanup form one component change. Owner-held cleanup wiring belongs to the session integration slice. No new widgets require Widgetbook cases.

Verification evidence on 2026-10-13: the three lease cleanup regressions failed before the fix, then all 49 focused composer/controller tests passed. The related voice/composer suite passed 104 tests, and the screen dictation/profile suite passed 31 tests after a concurrent notification import was corrected. Focused analysis found no issues, formatting completed, and no physical microphone was accessed. Owner-held cleanup and the integrated verification loop remain open.

Subsequent independent review reproduced two settlement regressions through the real composer and `sendAfterDictation`: both sent the retained typed draft after a synchronous pause/resume. After correcting the completion outcome, all 51 focused composer/controller tests passed. Focused analysis and formatting passed. These checks used synthetic audio only and establish no native or integrated retention coverage.
