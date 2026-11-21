#!/usr/bin/env python3
"""Aggregates the per-run JSON files of benchmark/chat_render_bench_test.dart.

usage: chat_bench_aggregate.py <aggregate.json> <run.json>...

Per scenario and width: the median across runs of each per-run statistic, and
its coefficient of variation (sample standard deviation / mean, in percent).
"""
import json
import statistics
import sys

STATS = ["max", "top3", "p95", "p50", "total"]
# Present only in some runs or modes: reported when every run has them.
OPTIONAL = ["raster_max", "raster_p95", "open_wall_ms"]
COUNTS = ["over16", "over100", "frames"]


def cv(values):
    if len(values) < 2:
        return 0.0
    mean = statistics.fmean(values)
    return 0.0 if mean == 0 else 100 * statistics.stdev(values) / mean


def main(argv):
    out, runs = argv[1], argv[2:]
    rows = {}
    order = []
    for path in runs:
        with open(path) as f:
            for r in json.load(f)["results"]:
                key = (r["scenario"], r["width"])
                if key not in rows:
                    rows[key] = []
                    order.append(key)
                rows[key].append(r)
    result = []
    for key in order:
        rs = rows[key]
        entry = {"scenario": key[0], "width": key[1], "runs": len(rs)}
        for s in STATS:
            vals = [r[s] for r in rs]
            entry[s] = round(statistics.median(vals), 2)
            entry[s + "_cv"] = round(cv(vals), 1)
            entry[s + "_min"] = min(vals)
            entry[s + "_maxrun"] = max(vals)
        for o in OPTIONAL:
            if all(o in r for r in rs):
                vals = [r[o] for r in rs]
                entry[o] = round(statistics.median(vals), 2)
        for c in COUNTS:
            entry[c] = statistics.median(r[c] for r in rs)
        result.append(entry)
    with open(out, "w") as f:
        json.dump({"runs": len(runs), "results": result}, f, indent=2)
    extra = " (profile: build = UI thread)" if any("raster_max" in e for e in result) else ""
    head = (
        f"{'scenario':<18}{'width':<8}{'max':>8}{'cv%':>6}{'top3':>8}{'cv%':>6}"
        f"{'p95':>8}{'cv%':>6}{'p50':>8}{'>16':>6}{'>100':>6}{'frames':>7}"
    )
    print(f"median over {len(runs)} runs (ms); cv = std/mean of the per-run value{extra}")
    print(head)
    for e in result:
        print(
            f"{e['scenario']:<18}{e['width']:<8}{e['max']:>8.1f}{e['max_cv']:>6.1f}"
            f"{e['top3']:>8.1f}{e['top3_cv']:>6.1f}{e['p95']:>8.1f}{e['p95_cv']:>6.1f}"
            f"{e['p50']:>8.1f}{e['over16']:>6.0f}{e['over100']:>6.0f}{e['frames']:>7.0f}"
        )


if __name__ == "__main__":
    main(sys.argv)
