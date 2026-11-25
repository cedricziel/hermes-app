---
name: hill-climb-tests
description: Use when judging the value of hermes-app tests (is this test worth keeping, can the suite fail for a real defect, which subject has weak tests), before removing or merging any test, or when adding or running a mutant in the mutation sample (scripts/mutation_sample.py, tool/mutants/).
---

# Hill-climb the tests with the mutation sample

A green suite says nothing about whether it can go red. The mutation sample
answers that for a few key subjects: it applies one small, realistic defect
(a mutant) to the product code, runs every test file that imports the
subject, and records whether any test failed. A mutant that no test notices
is a test gap, or a rule nobody wrote down. The kill rate per subject is the
roadmap's H.5 measure.

Files:

- `scripts/mutation_sample.py`: the runner (Python 3, no packages).
- `tool/mutants/<subject>.json`: one list per subject: `tests` (every test
  file that imports the subject's library (directly, one hop deeper, or through a
  `test/` helper, see "Keep the lists honest"), and for a `part of` file
  the importers of its parent library, plus `test/workflows/*`),
  an optional `quick_tests` subset, and `mutants`.
- `scripts/mutant_importers.py` (tests in `scripts/test_mutant_importers.py`): reports
  the test files a list's `tests` is missing, see "Keep the lists honest".
- `scripts/test_mutation_sample.py`: the runner's own tests (fake repo, fake
  `flutter`); CI runs them with `python3 -m unittest discover -s scripts -p 'test_*.py'`.
- Results: `.dart_tool/mutation-sample/<subject>.json` (not committed).

Subjects: `auth_controller`, `server_address`, `token_store`, `chat_sending`,
`gateway_reconnect`, `gateway_replay`, `app_lock`, `deeplinks`, `files`
(`ServerPath`, `SecretNames`), `inline_reply`, `kanban`, `media`, `model`
(chat model choice, first-run card, composer pill) and `queue` (the durable
queue store). `tests` holds at least every importer plus `test/workflows/*`, and may add
curated tests that exercise the subject through another library;
`quick_tests` is optional (`deeplinks` and `inline_reply` have none, so
`--quick` runs their full list), and where present it is the curated core.

## Run it

```bash
python3 -I scripts/mutation_sample.py --check                 # every old occurs once; no test run
python3 -I scripts/mutation_sample.py token_store             # one subject, full tests list
python3 -I scripts/mutation_sample.py token_store --quick     # quick_tests only (fast, a lower bound)
python3 -I scripts/mutation_sample.py auth_controller --only au03,au17   # single mutants
python3 -I scripts/mutation_sample.py --summary               # kill rate per subject from saved results
```

Other flags:

- `--only id,id`: always reruns those ids, even when saved, and merges them
  into the saved results (the other ids are kept).
- `--fresh`: ignores saved results and starts over.
- `--baseline-only`: runs only the unmutated tests, to see whether they are green.
- `--concurrency N`: passed to `flutter test` (default 2); keep it low on a shared machine.
- `--out DIR`: writes results there instead of `.dart_tool/mutation-sample/`.

It refuses to start when a file it mutates has uncommitted changes (and
prints the `git restore` command; a copy of each original is taken under
`.dart_tool/mutation-sample/backup/` before it is mutated), needs a green
baseline first (exit 0 and at least one test passing), and restores the file
after every mutant and on an error, Ctrl-C, SIGTERM or SIGHUP. Saved results
are reused at the same commit, mode and test file contents, and a mutant whose
list entry changed is rerun. So the loop "add a test, rerun the mutant with
`--only`" always measures the new test: a changed test file makes the baseline
run again, and the other ids' older results are shown as stale. Run one
subject at a time; the full lists are large (the baseline alone is minutes),
and a machine shared with other agents should not run two at once. Use
`--quick` while iterating and the full list to certify a result: a quick
survivor may still be killed by a test outside the subset.

## Read the results

Per mutant: `KILLED`, `SURVIVED` (exit 0, nothing failed, and at least 90% of
the baseline's tests ran), `TIMEOUT` (counts as a kill), `INVALID` (did not
compile; counts for nothing, fix the mutant) or `INCONCLUSIVE` (a non-zero
exit with no failing test, no test ran, or far fewer ran than in the baseline;
neither killed nor survived, see `reason` and rerun). The kill rate is
killed / (killed + survived).

- `first_failure.kind`: `expect_mismatch` (a matcher said no, the best sign),
  `unexpected_request` (a fake server saw a call nobody stubbed),
  `uncaught_exception`, `timeout`, `other`. A pile of `timeout` or
  `uncaught_exception` kills means tests that fail by accident, not by
  asserting the rule.
- `sole_killer`: the one test file that catches the mutant. A test file that
  is the sole killer of anything is not redundant.
- A survivor: read the product code first. Either the rule is untested (add a
  test that fails on the mutant and passes on main), the mutant is equivalent
  (change it so it is not, or drop it with a note), or the product is wrong as
  written, which is a defect to fix on its own.

## Add a mutant

1. Pick a rule the subject must keep (a boundary, a guard, an ordering, a
   limit), not a typo. One small edit that changes behaviour.
2. Add `{"id", "file", "old", "new", "note"}` to the list. `file` is the
   file that holds the code, a part file included. `old` is copied exactly
   and must occur once in that file; make it longer, not clever, to be unique.
   `note` says in a few words what breaks.
3. `python3 -I scripts/mutation_sample.py --check`, then run the mutant with
   `--only`. A `compile error` means the edit is not valid Dart.
4. When code moves or changes, re-anchor: an `old` that no longer occurs once
   fails `--check`. Keep the id and its intent; drop a mutant only when the
   code it targeted is gone, and say so in the PR.

## Keep the lists honest

- `--check` must pass for every list before a list is committed. It checks
  anchors and that the files exist; it does not check importers.
- Missing importers: a test that reaches a subject's library but is not in
  `tests` can kill a mutant the list says survives. Check with
  `python3 scripts/mutant_importers.py [subject ...]` (`--apply` adds what it
  finds; it exits 1 while a list is missing files). It counts four ways: a
  direct `import`/`export` of a mutated file (for a `part of` file, of the
  parent library with its `part '...'` line); one hop through a `lib/` library
  that itself imports a mutated library (a listener test reaches the parser
  through the listener); a non-test Dart file under `test/` (a harness or fake
  such as `test/support/pump_chat.dart`) that imports a mutated library; and
  helper chains, which it follows transitively: a helper that imports a helper
  that imports the library counts, at any depth. `test/workflows/*` is always
  included. Run it after a pull that adds test files, and add what it finds.
- A survivor is a test gap only after it ran against the full `tests` list,
  not only `quick_tests`: a quick survivor is a lead, not a finding.
- Re-run a subject's mutants after any merge that touches it (its product
  files or its tests), and state the main commit next to every result. A
  kill rate without a commit is not comparable.

## Known equivalent mutants

A mutant moves here only after it SURVIVED a full-list run (`--only <id>`, no
`--quick`) and has a reason that holds against tests that plant data
directly (a test that writes a record or file itself skips the defence the
reason names). Reasoning alone is not enough: `queue` q11 and q12 looked
equivalent by reading the code, and `durable_queue_store_binding_test.dart`
kills both. The runner applies one edit per mutant, so a pair of defences
cannot be removed together. Record the reason and the main commit of the run.

Each entry below survived a full-list run on main `c04b9fce`, and the mutant
stays in its list (it is not dropped); the entry only says why it is not a
test gap.

- `model` mo05 (`profile != _profile` after the await in `_loadModelOptions`):
  `_profile` only changes in `_loadThreads`. A late answer started before it
  fails the `_loadGeneration` guard. A `refreshModelOptions()` started after
  `_loadThreads` bumped the generation but before it set `_profile` passes
  that guard, and the `_modelOptionsGeneration` request guard rejects it,
  since the `_loadModelOptions` call right after `_profile = profile` bumps it.
- `inline_reply` i11 (`!_mark.written` in `_failed`): with the prompt written
  and not acknowledged, `_byMark(failed)` returns the same unconfirmed
  verdict the fall-through returns.
- `app_lock` a16 (`_authenticating` guard in `_unlockOnce`): it runs only
  through `unlock()`, which needs `_locked`, and `_locked` is true only while
  the lock is enforced, so `setEnabled(true)`'s prompt (which runs while
  `_enabled` is false) never overlaps it. Holds unless `load()` runs twice.

Not equivalent, though they looked it: `queue` q11 (JSON scope check), q12
(record id vs file name) and q24 (scope in the AAD) are all killed by
`durable_queue_store_binding_test.dart`, whose planted records skip the
defence the reasoning named (q24 is killed only because its `plantValid`
copies the AAD format). `queue` q18 (attachment size check) survives a full
run, and a planted blob with a wrong size would kill it, so it is a test gap.

## The removal rule

A test is removed, merged or loosened only with mutation evidence: run the
subject's mutants with and without it, and show that every mutant it kills is
also killed by another file (it is never the `sole_killer`), or show it asserts
nothing (it survives mutants of the very code it names, and a stripped
assertion changes no result). A test about code outside every sample subject
has no evidence either way: leave it. Never delete a test because it is slow,
old or duplicates another by name alone.
