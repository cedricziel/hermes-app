## Behaviour changes

<!-- What a user or an operator sees differently, one line each. -->

## Proof

<!-- The mutation or reverted fix the new test kills, the screenshots you looked at, the scripts/verify.sh run line, the design canvas link. A fix: PR also answers "What would have caught this earlier?" -->

## Not verified on a device

<!-- Write "Nothing" if nothing. -->

## Review

<!-- Paste the isolated reviewer's block verbatim, never write or edit it: Reviewer: ... Head: <full sha> Verdict: clean | changes-requested, then Range: <base sha>..<head sha>, Findings: ... and Proof reproduced: ... A push after a review needs a new review. A clean merge of main needs none (the check proves it from git). A merge with a conflict fix or an extra change needs the reviewer's block headed by a line Merge-review: <files>. -->
<!-- A new public widget under lib/src/**/widgets/ needs a Widgetbook use case naming it. If none applies, the isolated reviewer emits "Catalog-first: not applicable, <reason>" in its block; paste the block unchanged. -->
<!-- A UI PR (lib/src/**/widgets/, lib/**/*_screen.dart, lib/src/theme/) names its design record in the PR body: "Design: <canvas link or docs/design-briefs/ or openspec design.md path>", or "Design: not needed, <reason>" (text-only, behaviour-only, test-only, no-visual-change refactor, bug fix restoring the designed look). The isolated reviewer confirms it; advisory for now. -->
