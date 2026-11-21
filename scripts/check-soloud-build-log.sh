#!/usr/bin/env bash
# Checks that a verbose desktop build did not fetch what flutter_soloud's build
# hook can: scripts/check-soloud-build-log.sh <flutter build -v log> [hook dir].
#
# The hook prints "[flutter_soloud] Building on Linux (x64) with Xiph libs
# [disabled]" to its own stdout, which Flutter keeps in
# .dart_tool/hooks_runner/flutter_soloud/<hash>/stdout.txt and does not copy to
# the build log, so this reads both. The line must be there, with no ", VST3
# [prebuilt]" after it, and none of the strings a download or a source build of
# Opus, Ogg, Vorbis or FLAC leaves may appear anywhere. A failure means
# pubspec.yaml's hooks.user_defines for flutter_soloud or the pinned version
# changed: see docs/architecture/native.md (flutter_soloud).
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: $0 <build log> [hooks_runner/flutter_soloud dir]" >&2
  exit 64
fi
log=$1
hooks=${2:-.dart_tool/hooks_runner/flutter_soloud}

[ -f "$log" ] || { echo "no build log at $log" >&2; exit 1; }

files=("$log")
while IFS= read -r file; do
  files+=("$file")
done < <(find "$hooks" -type f \( -name stdout.txt -o -name stderr.txt \) 2>/dev/null | LC_ALL=C sort)

failed=0

forbidden='Downloading prebuild archive|Extracting archive|releases/download|Configuring (ogg|opus|vorbis|flac)|Cloning'
if hits=$(grep -nE "$forbidden" "${files[@]}"); then
  echo "flutter_soloud fetched or built a Xiph library:" >&2
  echo "$hits" | head -20 >&2
  failed=1
fi

line='\[flutter_soloud\] Building on Linux \([A-Za-z0-9_]+\) with Xiph libs \[disabled\]'
if ! found=$(grep -hE "$line" "${files[@]}"); then
  echo "missing '[flutter_soloud] Building on Linux (<arch>) with Xiph libs [disabled]'" >&2
  echo "(hook stdout is read from $hooks/*/stdout.txt)" >&2
  failed=1
elif echo "$found" | grep -qE "$line, VST3"; then
  echo "flutter_soloud built with VST3: $(echo "$found" | grep -E ', VST3' | head -1)" >&2
  failed=1
fi
# A hook run that reports Xiph libs in any other mode is no pass either.
if grep -hE '\[flutter_soloud\] Building on .* with Xiph libs \[' "${files[@]}" |
  grep -vqE "with Xiph libs \[disabled\]"; then
  echo "flutter_soloud built with Xiph libs in a mode other than [disabled]" >&2
  failed=1
fi
if [ "$failed" -ne 0 ]; then exit 1; fi
echo "flutter_soloud build: Xiph libs disabled, no VST3, no download"
