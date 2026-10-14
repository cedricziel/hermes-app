# Tasks

One PR, `fix(chat): draw nothing for empty activity states`, under ~300 changed lines.

## 1. Tiers

- [x] 1.1 Write failing unit tests in `test/chat/activity/activity_tier_test.dart` for the tier of every activity kind in the `chat-activity` spec, including a connector operation that moves from Needs you to For reference when it settles and a connection-wide read-only update that is always For reference.
- [x] 1.2 Add `ActivityTier` and the per-source mapping in `lib/src/chat/activity/activity_tier.dart` and verify 1.1 passes.

## 2. Catalog

- [x] 2.1 Add or update the Widgetbook use cases for `TodoPlanCard`, `SessionUsageCard` and `BillingVerificationCard` so the unknown/unsupported states render nothing, and verify `flutter test test/widgetbook_test.dart` passes in both themes.

## 3. Quiet states

- [x] 3.1 Write failing widget tests: an attached plan with no snapshot draws no "Plan unavailable"; usage after method-not-found draws no row; billing after method-not-found draws no row; usage that went stale still shows its values with the stale label.
- [x] 3.2 Make the three cards and `ChatThreadView` skip empty entries, and leave out the strip container when no entry has content; verify 3.1 passes.
- [x] 3.3 Write a widget test that a chat with no activity content places the transcript directly below the header (no strip container), and verify it passes.

## 4. Observability and docs

- [x] 4.1 No new spans, log events or breadcrumbs (see proposal); confirm the existing card event tests still pass.
- [x] 4.2 Update the Chat paragraph of `CLAUDE.md` only if it describes the removed placeholders; no `.claude/skills` entry goes stale.

## 5. Verify

- [x] 5.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all clean.
- [ ] 5.2 Run the `verify-in-app` loop on macOS against `scripts/dev-backend.sh`: open a new chat and confirm no activity rows appear above the transcript; screenshot it.
