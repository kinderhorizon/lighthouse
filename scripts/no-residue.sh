#!/usr/bin/env bash
#
# Residue guard for the public repo.
#
# Blocks pre-public-cleanup residue from re-entering tracked files: personal
# first names, AI-assistant / AI-editor names, AI co-author trailers, and
# absolute home-directory paths. Runs in CI (cannot be bypassed) and as part of
# the pre-commit hook (best effort, skippable with --no-verify locally).
#
# Run manually:   bash scripts/no-residue.sh
#
# Keep this list in sync with CONTRIBUTING.md.

set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Policy / meta files that legitimately name the forbidden terms. They are
# maintained by hand and excluded from the scan to avoid self-tripping.
EXCLUDES=(
  ":(exclude)scripts/no-residue.sh"
  ":(exclude).githooks/pre-commit"
  ":(exclude).githooks/commit-msg"
  ":(exclude).github/workflows/ci.yml"
  ":(exclude)CONTRIBUTING.md"
  ":(exclude)pubspec.lock"
)

PATTERN='\bclaude\b|\bcodex\b|\bcopilot\b|\banthropic\b|\bchatgpt\b|\bopenai\b|gpt-?[0-9]|\bgemini\b|cursor\.(sh|so|ai|com)|cursorrules|cursor ai|/Users/|/home/[a-z]|~/dev/|\.claude\b'

if git grep -nIiE "$PATTERN" -- . "${EXCLUDES[@]}"; then
  echo ""
  echo "ERROR: forbidden residue found above (personal first name, AI-tool name, or local path)."
  echo "This repo is public. See CONTRIBUTING.md. If it is a genuine false positive,"
  echo "scope the pattern in scripts/no-residue.sh rather than disabling the guard."
  exit 1
fi

echo "residue guard: clean"
