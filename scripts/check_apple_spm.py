#!/usr/bin/env python3
"""Reject native Apple plugins that would make Flutter fall back to CocoaPods."""
import json
from pathlib import Path
import sys


def missing_spm(manifest: dict) -> list[str]:
    missing = []
    for platform in ("ios", "macos"):
        for plugin in manifest.get("plugins", {}).get(platform, []):
            if not plugin.get("native_build", True):
                continue
            folder = "darwin" if plugin.get("shared_darwin_source", False) else platform
            package = Path(plugin["path"]) / folder / plugin["name"] / "Package.swift"
            if not package.is_file():
                missing.append(f"{platform}: {plugin['name']}")
    return missing


def main() -> int:
    path = Path(".flutter-plugins-dependencies")
    if not path.is_file():
        print("Run flutter pub get before checking Apple SPM support.", file=sys.stderr)
        return 1
    missing = missing_spm(json.loads(path.read_text()))
    if missing:
        print("Native Apple plugins without Swift Package Manager support:", file=sys.stderr)
        print("\n".join(missing), file=sys.stderr)
        return 1
    print("All native iOS and macOS plugins support Swift Package Manager.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
