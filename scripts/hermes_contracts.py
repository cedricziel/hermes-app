import argparse
import pathlib
import re
import subprocess
import sys


PROVENANCE = ("openapi/HERMES_REF", "openrpc/HERMES_REF")
CONTRACTS = (
    "openapi/hermes-agent.openapi.json",
    "openrpc/hermes-gateway.openrpc.json",
)
OUTCOMES = ("success", "failure", "cancelled", "skipped", "unavailable")


def resolve(root):
    """Return matching full commit SHA; reject missing or invalid provenance."""
    values = []
    for name in PROVENANCE:
        value = (root / name).read_text(encoding="utf-8").rstrip()
        if not re.fullmatch(r"[0-9a-fA-F]{40}", value):
            raise ValueError(f"{name} must contain a 40-character hexadecimal SHA")
        values.append(value.lower())
    if values[0] != values[1]:
        raise ValueError("REST and gateway provenance mismatch")
    return values[0]


def changes(root):
    """Return update flags only after both committed source refs agree."""
    resolve(root)
    result = subprocess.run(
        ["git", "-C", str(root), "diff", "--name-only", "HEAD", "--",
         *CONTRACTS, *PROVENANCE],
        check=True, capture_output=True, text=True,
    )
    paths = set(result.stdout.splitlines())
    return {
        "changed": bool(paths),
        "openapi_changed": CONTRACTS[0] in paths,
        "provenance_changed": bool(paths.intersection(PROVENANCE)),
    }


def summary(root, outcomes):
    """Render public provenance and fixed CI outcomes without test content."""
    try:
        sha = resolve(root)
    except (OSError, UnicodeError, ValueError):
        sha = "unavailable"
    rows = [
        ("Resolved Hermes SHA", sha),
        ("Provenance agreement", outcomes.provenance),
        ("Backend download", outcomes.download),
        ("Backend install", outcomes.install),
        ("Backend start", outcomes.start),
        ("Contract suite", outcomes.tests),
        ("Backend cleanup", outcomes.cleanup),
        ("HERMES_DEV_MODEL_CALLS", "unset"),
        ("HERMES_DEV_TELEGRAM_PAIRING", "unset"),
    ]
    return "\n".join([
        "## Advisory backend contract", "", "| Evidence | Result |",
        "| --- | --- |", *(f"| {name} | {value} |" for name, value in rows),
        "", "Free loopback scripted-model turns are included in the contract suite.",
        "Paid-provider and external Telegram pairing scenarios are deliberately skipped.",
        "Setup failure or skipped tests provide no passing compatibility evidence.",
    ])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("resolve", "changes", "summary"))
    parser.add_argument("--root", type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parents[1])
    for name in ("provenance", "download", "install", "start", "tests", "cleanup"):
        parser.add_argument(f"--{name}", choices=OUTCOMES, default="unavailable")
    args = parser.parse_args()
    try:
        if args.command == "resolve":
            print(resolve(args.root))
        elif args.command == "changes":
            for name, value in changes(args.root).items():
                print(f"{name}={str(value).lower()}")
        else:
            print(summary(args.root, args))
    except (OSError, UnicodeError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Hermes contracts: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
