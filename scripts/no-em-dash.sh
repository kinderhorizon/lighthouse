#!/usr/bin/env bash
#
# Em-dash guard for Lighthouse AAC.
#
# Em dashes (U+2014) and en dashes (U+2013) are forbidden in Kinder Horizon
# Foundation copy and code: they undermine the foundation's brand voice. Use
# commas, parens, colons, regular hyphens, or
# sentence splits instead.
#
# Run manually:   bash scripts/no-em-dash.sh
# Run as a hook:  see .githooks/pre-commit (enable with `git config core.hooksPath .githooks`)
#
# Exits non-zero if any em or en dash is found in tracked source files.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Paths we care about. Skip build artifacts, vendored, generated, and lockfiles.
TARGETS=(
  "lib"
  "test"
  "docs"
  "boards"
  "assets/arasaac/manifest.json"
  "scripts"
  "README.md"
  "LICENSE"
  "NOTICE"
  "LICENSES"
  "pubspec.yaml"
)

EXISTING=()
for path in "${TARGETS[@]}"; do
  if [ -e "$path" ]; then
    EXISTING+=("$path")
  fi
done

if [ ${#EXISTING[@]} -eq 0 ]; then
  echo "no-em-dash: nothing to scan, skipping"
  exit 0
fi

# Match em dash (U+2014, UTF-8 0xE2 0x80 0x94) and en dash (U+2013, UTF-8 0xE2 0x80 0x93).
# Expressed as byte patterns so the script itself doesn't trip the check.
HITS=$(LC_ALL=C grep -rIn --color=never -E $'\xE2\x80\x93|\xE2\x80\x94' "${EXISTING[@]}" || true)

if [ -n "$HITS" ]; then
  echo "no-em-dash: forbidden em or en dash found, replace with comma, parens, colon, regular hyphen, or sentence split"
  echo
  echo "$HITS"
  exit 1
fi

echo "no-em-dash: clean"
