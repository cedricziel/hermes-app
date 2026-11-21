---
name: architecture-guards
description: Use when a test under test/architecture/ fails (a guard or the baseline ratchet), when adding a source-scan guard rule, or when lowering or reading test/architecture/baseline/<ns>.yaml.
---

# Architecture guards and the baseline ratchet

`test/architecture/` scans source files and fails CI when a new call site breaks a repo rule. Known old violations are listed in `test/architecture/baseline/<ns>.yaml`; the list can only shrink.

## The ratchet

- One baseline file per namespace: `test/architecture/baseline/<ns>.yaml` (`arch`, `style`, `test`), mapping rule id (`<ns>.<name>`) to (repo-relative path to allowed count). A rule with no violations has no entry. Each namespace has exactly one test file that calls `ratchetTests(rules, namespace: '<ns>')` directly in the body of its top-level `main()` (a helper, a closure, a tear-off or a non-literal namespace fails); `ratchet_test.dart` fails when a namespace is registered from two files or a baseline file has none.
- A count above its entry, or a file not listed, fails with the offending lines and the building block to use instead.
- A count below its entry fails too, with the edit to make: `lower <rule> <path> to N`, or remove the entry (and the rule id line if it was the last; an empty `arch.x:` still parses). That is how the debt only goes down.
- A baseline id that none of the namespace's rules claims fails, and a rule id registered twice throws.
- `UPDATE_BASELINE=1 flutter test test/architecture` makes the edits for you. It never raises a count or adds an entry, and it removes entries and rule ids left with no entries. It keeps ids no rule claims (and the orphan test still fails): once a rule is really gone and its id removed from the code, run `UPDATE_BASELINE=prune flutter test test/architecture` once to drop them. Each file has one writer, so no lock is needed; the write goes through a temp file and a rename.

## When a guard fails

1. Read the message: it names the building block to use. Use it.
2. If the new site is legitimate (the block itself, a platform boundary), add its path to the rule's allowlist in code with a reason, and say why in the PR. Never raise or add a baseline entry.
3. If the count fell, run the update command above (or make the edit the message gives) and commit the baseline file.

## Adding a rule

1. Write the scan. A `Rule` (`ratchet.dart`) has `id`, `scan` (path to violation count), `locate` (offending lines of one path, for the failure) and `message` (what to use instead; name the shared building block, a rule without one is not finished).
2. Register it with `ratchetTests([...], namespace: 'arch')` in a test file under `test/architecture/`. The `arch.*` rules are the table `guardRules` in `architecture_guards_test.dart`; `source_scan.dart` gives a comment-free view of each file (`SourceFile.text` keeps string literals, `SourceFile.code` blanks them, so a call pattern never matches text in a string).
3. Run the scan on main and read every hit. Allowlist the legitimate paths in code, with a reason. Baseline only real violations you will not fix in this change: `UPDATE_BASELINE=1` never adds, so write those entries by hand with the counts the failure reports.
4. Prove the rule can fail: add one violating line to a `lib/` file, run `flutter test test/architecture`, see the failure with the right message, revert it. Do not commit the line. A rule over `test/` (`arch.tests-read-docs`) needs a temporary file under `test/` instead, deleted afterwards.
5. Keep the whole directory fast (it may run in a pre-commit hook): read files once, no process spawns.

## Known gaps

The scans read text, not types, so some slips get through. They are known, and a review is still the backstop:

- `arch.error-interpolation-in-telemetry`: an error handler held in a variable (`final handler = (e, st) {...}; fut.catchError(handler)`), a helper that takes the error as a parameter with another name and logs it, an error built into a string before the call (`final msg = '$e'; debugPrint(msg)`), and the errors of an isolate (`ReceivePort.listen` on an `addErrorListener` port).
- `arch.doctor-fix`: a route held in a `const` and passed by name, and a string split across two literals (`'--fi' 'x'`, `'/api/ops/' 'doctor'`).
- A bare `e`, `ex` or `st` is only an error name where a catch, a `catchError`/`handleError`/`onError`/`runZonedGuarded` handler or a `StackTrace`/`FlutterErrorDetails` parameter binds it.
