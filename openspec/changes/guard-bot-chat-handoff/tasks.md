## 1. Guarded bot handoff

- [x] 1.1 Start with failing generated-client widget regressions for dirty editor protection, departure during held lookup, and newer external intent supersession. Reuse the existing root queue with shell-local arrival ordering and captured owner checks while preserving canonical context.
- [x] 1.2 Confirm existing gateway and navigation telemetry suffices, generated API contracts remain unchanged, and no project skill becomes stale. No visual component or Widgetbook case changes are needed.

## 2. Verification

- [x] 2.1 Run focused shell, gateway, bot opening and navigation tests, formatting, Flutter analysis, and strict OpenSpec validation. Freeze one bounded fix(navigation) change for root review.
- [ ] 2.2 Verify the integrated handoff in an isolated native client when retained-owner integration exists. Source and widget tests do not establish native window or device behavior.

Verification before rebase: all three new behavior regressions failed against unchanged production source after fixture setup and teardown were corrected. The three tests and 120 existing shell, deep-link, queue, bot opening, and roster contract tests now pass. Focused analysis, formatting, whitespace checks, and strict OpenSpec validation pass. The fixture uses generated REST calls and an isolated scripted loopback gateway; no real Hermes backend or native client was launched. No project skill became stale.

Final verification: after rebasing onto the merged desktop history and replacement-guard queue changes, all 146 tests across nine affected shell, deep-link, queue, bot, and history test files pass. Full Flutter analysis reports no issues; formatting, whitespace checks, and strict OpenSpec validation pass. Native and retained-owner verification remain open.
