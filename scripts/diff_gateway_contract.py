"""Prints, as Markdown, what changed between two copies of Hermes' gateway
contract (openrpc/hermes-gateway.openrpc.json): the event frames, server
requests and methods added or removed.

    python3 scripts/diff_gateway_contract.py OLD NEW
"""

import json
import sys

SECTIONS = (
    ("x-notifications", "Event frames"),
    ("x-server-requests", "Server requests"),
    ("methods", "Methods"),
)


def entries(contract, key):
    return {e["name"]: e.get("summary", "") for e in contract.get(key, [])}


def main(old_path, new_path, ref_path="openrpc/HERMES_REF"):
    with open(old_path) as f:
        old = json.load(f)
    with open(new_path) as f:
        new = json.load(f)
    with open(ref_path) as f:
        ref = f.read().strip()

    print(f"Updates `openrpc/hermes-gateway.openrpc.json` to NousResearch/hermes-agent@{ref}.\n")
    changed = False
    for key, title in SECTIONS:
        before, after = entries(old, key), entries(new, key)
        added = sorted(after.keys() - before.keys())
        removed = sorted(before.keys() - after.keys())
        if not added and not removed:
            continue
        changed = True
        print(f"### {title}\n")
        for name in added:
            print(f"- added `{name}`: {after[name]}".rstrip(": "))
        for name in removed:
            print(f"- removed `{name}`")
        print()
    if not changed:
        print("No frames, requests or methods were added or removed; only schemas or summaries changed.\n")
    print(
        "If `test/gateway/gateway_contract_test.dart` fails, classify each new "
        "event frame or server request in its table before merging."
    )


if __name__ == "__main__":
    main(*sys.argv[1:])
