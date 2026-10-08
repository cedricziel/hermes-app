"""Prints, as Markdown, what changed between two copies of the Hermes
dashboard's OpenAPI spec (openapi/hermes-agent.openapi.json): operations
added, removed or changed, and the parameters a changed one gained or lost.

    python3 scripts/diff_openapi_spec.py OLD NEW
"""

import json
import sys

METHODS = ("get", "post", "put", "patch", "delete")


def operations(spec):
    return {
        f"{method.upper()} {path}": op
        for path, item in spec.get("paths", {}).items()
        for method, op in item.items()
        if method in METHODS
    }


def params(op):
    return {p["name"] for p in op.get("parameters", []) if "name" in p}


def change(old, new):
    parts = [f"+`{p}`" for p in sorted(params(new) - params(old))]
    parts += [f"-`{p}`" for p in sorted(params(old) - params(new))]
    for key, label in (("requestBody", "request body"), ("responses", "responses")):
        if old.get(key) != new.get(key):
            parts.append(label)
    if not parts and old.get("parameters") != new.get("parameters"):
        parts.append("parameters")
    return ", ".join(parts) or "description"


def main(old_path, new_path, ref_path="openapi/HERMES_REF"):
    with open(old_path) as f:
        old = json.load(f)
    with open(new_path) as f:
        new = json.load(f)
    with open(ref_path) as f:
        ref = f.read().strip()

    before, after = operations(old), operations(new)
    added = sorted(after.keys() - before.keys())
    removed = sorted(before.keys() - after.keys())
    changed = sorted(k for k in before.keys() & after.keys() if before[k] != after[k])

    print(
        f"Updates `openapi/hermes-agent.openapi.json` to NousResearch/hermes-agent@{ref} "
        "and regenerates `packages/hermes_api`.\n"
    )
    for title, names, describe in (
        ("Added", added, lambda k: after[k].get("summary", "")),
        ("Removed", removed, lambda k: ""),
        ("Changed", changed, lambda k: change(before[k], after[k])),
    ):
        if not names:
            continue
        print(f"### {title} ({len(names)})\n")
        for name in names:
            print(f"- `{name}` {describe(name)}".rstrip())
        print()
    if not (added or removed or changed):
        print("No operation changed; only shared schemas did.\n")
    print(
        "A removed or retyped operation the app calls fails `flutter analyze` on this PR. "
        "Fix the caller before merging."
    )


if __name__ == "__main__":
    main(*sys.argv[1:])
