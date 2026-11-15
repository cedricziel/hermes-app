---
name: architecture-guards
description: Use when a test under test/architecture/ fails (a guard or the baseline ratchet), when adding a source-scan guard rule, or when lowering or reading test/architecture/baseline.yaml.
---

# Architecture guards and the baseline ratchet

`test/architecture/` scans source files and fails CI when a new call site breaks a repo rule. Known old violations are listed in `test/architecture/baseline.yaml`; the list can only shrink.

## The ratchet

- `baseline.yaml` maps rule id to (repo-relative path to allowed count). Ids are namespaced: `arch.*`, `style.*`, `test.*`. A rule with no violations has no entry.
- A count above its entry, or a file not listed, fails with the offending lines and the building block to use instead.
- A count below its entry fails too, with the edit to make: `lower <rule> <path> to N`, or remove the entry. That is how the debt only goes down.
- `UPDATE_BASELINE=1 flutter test --concurrency=1 test/architecture` makes those edits for you. It never raises a count or adds an entry, and it removes rule ids left with no entries and ids no rule claims. The rewrite is locked and atomic, so test files may run in parallel; `--concurrency=1` is only tidier.
- Removing the last entry of a rule: remove the rule id line too (an empty `arch.x:` also parses, and the update drops it).
- Each `ratchetTests(rules, namespace: 'arch')` call also fails on a baseline id in its namespace that none of its rules claims, and throws on a rule id registered twice.

## When a guard fails

1. Read the message: it names the building block to use. Use it.
2. If the new site is legitimate (the block itself, a platform boundary), add its path to the rule's allowlist in code with a reason, and say why in the PR. Never raise or add a baseline entry.
3. If the count fell, run the update command above (or make the edit the message gives) and commit `baseline.yaml`.

## Adding a rule

1. Write the scan. A `Rule` (`ratchet.dart`) has `id`, `scan` (path to violation count), `locate` (offending lines of one path, for the failure) and `message` (what to use instead; name the shared building block, a rule without one is not finished).
2. Register it with `ratchetTests([...], namespace: 'arch')` in a test file under `test/architecture/`.
3. Run the scan on main and read every hit. Allowlist the legitimate paths in code, with a reason. Baseline only real violations you will not fix in this change: `UPDATE_BASELINE=1` never adds, so write those entries by hand with the counts the failure reports.
4. Prove the rule can fail: add one violating line to a `lib/` file, run `flutter test test/architecture`, see the failure with the right message, revert it. Do not commit the line.
5. Keep the whole directory fast (it may run in a pre-commit hook): read files once, no process spawns.
