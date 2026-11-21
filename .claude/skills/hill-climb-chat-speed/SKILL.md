---
name: hill-climb-chat-speed
description: Use when measuring how fast the chat renders (frame cost while a reply streams, opening a long chat, scrolling, typing, the Mac sidebar), A/B comparing a change on the chat path (ChatScreen, message widgets, markdown, code blocks, tool cards, FollowingChatList) against main, or checking a chat PR for render regressions.
---

# Hill-climb chat speed

`benchmark/` drives the real `ChatScreen` through scripted, seeded streams with
the fakes from `test/support/` (no backend) and records the cost of every
frame. It is not under `test/`, so CI never runs it.

## Run it

```bash
scripts/chat-bench.sh --mode test 5            # debug JIT on the widget-test binding, ~18 min a run
scripts/chat-bench.sh --mode profile 5         # real Linux app, AOT, under Xvfb, ~13 min a run
scripts/chat-bench.sh --mode test 3 's4b|s3'   # filter: a regex on scenario ids
CHAT_BENCH_PHASES=1 CHAT_BENCH_FILTER=s4b flutter test benchmark/chat_render_bench_test.dart -j 1
```

Scenario ids: `s1-markdown` (300-message history, 6,000-word reply),
`s2-code-blocks` (12 fences, one of 2,000 lines), `s2b-fences-100|300|1000`
(empty fences), `s3-tool-calls` (40 calls with large JSON, some opened),
`s4a-tables`, `s4b-lists`, `s5-open-2000` (a = open, b = scroll up through
pages), `s6-typing`, `s7-mac-sidebar` (500 chats, desktop only). Each runs at
390x844 and 1280x800. Output: a table, `build/chat_bench/<mode>/run-N.json` and
`aggregate.json` (median across runs and the coefficient of variation).

Shared code is in `benchmark/support/` (`scenarios.dart` holds the scenarios,
`frame_stats.dart` the measuring, `harness.dart` the screen setup,
`content.dart` the generated fixtures). Never edit `test/support` or `lib/` for
the benchmark.

## Two modes, two meanings

- **test**: `flutter test`, debug JIT, fake clock. A frame is the real wall time
  of `tester.pump` (events fed in, build, layout, paint, microtasks). No
  rasteriser. Good for A/B on the same machine; the numbers are several times
  those of a release build, so do not quote them as what users feel.
- **profile**: `flutter drive --profile -d linux` under Xvfb, the real app in
  AOT with no asserts. A frame is the engine's `FrameTiming.buildDuration` (UI
  thread build, layout, paint) of the frames made while the measured pumps ran.
  Use this for absolute numbers. `raster_*` is reported beside it; under Xvfb the
  Linux embedder reports it as 0, so ignore it. Frame counts exceed the pump
  count (the engine makes extra, mostly cheap frames), which lowers p50 and p95
  too; only `max` is immune. Compare p50 and p95 only between runs of the same
  scenario, where the extra frames are alike.

## Reading results

`max` is the one slow frame (a jank); `top3` the mean of the three slowest;
`p95`/`p50` describe the steady cost; `>16`/`>100` count frames over those ms.
The first frames of each stream are warm-up and left out. `extra` fields:
`slowest` (index of the three worst frames among the measured ones, to find the
step of the script), `pumps`, `open_wall_ms` (s5a: real ms from the mount frame to the
newest message on screen, before the settle), `disclosures_opened` (s3).

`CHAT_BENCH_PHASES=1` (test mode only) splits each frame into event handling,
build, and layout+paint, and counts the elements rebuilt per frame by widget
type. A list builds its items while it lays out, so nearly everything is in
layout+paint; read `rebuilt_per_frame` to see whether a change cut rebuilds.

## Interleaved A/B

Machine noise drifts, so never run all of A and then all of B.

```bash
AB=${CHAT_BENCH_AB:-${TMPDIR:-/tmp}/hermes-chat-ab}    # scratch dir, outside the repo
mkdir -p "$AB" && git worktree add --detach "$AB/base" origin/main   # baseline
# candidate = this checkout
for i in 1 2 3 4 5; do
  (cd "$AB/base" && flutter pub get >/dev/null && CHAT_BENCH_DIR="$AB/base-$i" scripts/chat-bench.sh --mode test 1 "$FILTER") || exit 1
  CHAT_BENCH_DIR="$AB/cand-$i" scripts/chat-bench.sh --mode test 1 "$FILTER" || exit 1
done
python3 -I scripts/chat_bench_aggregate.py "$AB/base.json" "$AB"/base-*/test/run-1.json
python3 -I scripts/chat_bench_aggregate.py "$AB/cand.json" "$AB"/cand-*/test/run-1.json
git worktree remove --force "$AB/base" && rm -rf "$AB"    # clean up
```

Same machine, nothing else running, one test process at a time. Measure one
benchmark at a time on a machine: wrap runs in `flock -o <lockfile> scripts/chat-bench.sh ...`
(`-o` keeps a background child from inheriting the lock). Compare the
medians; treat a difference as real only when it is larger than about twice the
CV of that scenario and statistic (below). Copy `benchmark/`,
`scripts/chat-bench.sh` and `scripts/chat_bench_aggregate.py` into the baseline worktree if it predates them. Confirm
the winner in profile mode before claiming a speed-up.

## Noise (measured at b3d73a50: 3 test runs, 5 profile runs)

CV of the per-run value, across runs, on this machine:

- test mode (3 runs): `max` CV is 3-15 % for `s1`, `s2-code-blocks`,
  `s2b-fences-300/1000`, `s4a`, `s4b`, `s6`, `s7` and `s5b` desktop; `p95` CV is
  1-21 % there. `max` is one GC or JIT hiccup on `s2b-fences-100` (46-67 %),
  `s5a` phone (94 %) and `s5b` phone (143 %): read `p95` and `p50` for those
  (`s5a` is three frames, so its `p95` is its `max`). `s3` p95 varies a lot
  when the machine is shared (11-28 % in the full run, phone median 1,493 ms),
  and not alone (4-6 %, phone median 739 ms, `test 3 s3`): rerun it alone
  under `flock`.
- profile mode (5 runs): `max` CV is 3-31 % and `p95` CV 3-16 %; `p50` is
  steadier. Steadiest: `s4a` (max 3-9 %), `s2-code-blocks` (4-11 %, p95 3-8 %),
  `s6` p95 (5-15 %). Noisiest `max`: `s4b` phone (31 %), `s6` (22-31 %),
  `s2b-fences-100/1000` (12-22 %).
- Few scenarios are under 10 % on every statistic, so: run 5-10, compare
  medians, interleave, and ask for a difference above twice the CV.

## Traps

- Dio decodes a body over 50 KB in a background isolate, which the test clock
  never waits for (the chat just never opens). The harness uses `SyncTransformer`.
- `tester.enterText` needs the test text-input channel, which a real window
  (`flutter drive`) lacks: set the composer controller instead (`BenchChat.composer`).
- Sending a prompt pins it to the top of the list; `FollowingChatList` stops
  following when a disclosure is opened, and the end of the list is an
  estimate until items are laid out. The tool-call scenario scrolls to the end
  again before tapping, and fails the run when a tap does not land (s3 opens six disclosures).
- Loading a page remounts the list and drops a held drag: the scroll scenario
  starts a new drag when the list stops moving, and looks the scrollable up
  every frame.
- `pumpAndSettle` never settles in the Mac window; pump a fixed count.
- `flutter test` has no `--profile`. Profile mode needs the Linux build
  packages and `xvfb`. Where GitHub downloads are blocked, media_kit's CMake
  cannot fetch mimalloc: `apt install libmimalloc-dev` and run with
  `CHAT_BENCH_DYNAMIC_MIMALLOC=1` (the script patches `linux/CMakeLists.txt`
  for the run and restores it). A build directory configured before that keeps
  an install prefix of `/usr/local`, and `ninja install` writes there: the
  script removes `build/linux` first.
- The first scenario in a process pays for JIT; `warm-up` tests run first and are
  not recorded. A run on a busy machine is worthless: check `uptime`.
