#!/usr/bin/env bash
#
# Binary-source guard for Lighthouse AAC.
#
# Rejects raw NUL bytes in tracked TEXT source. A NUL makes a file binary and
# unreviewable: file(1) reports "data", git shows it as Bin, and grep/rg refuse
# to search it, so changes can't be line-diffed or grepped, even though the file
# may still compile (if the NUL sits in a comment or string). When a NUL CHAR is
# genuinely needed at runtime (e.g. a NUL-delimited map key), use a Unicode
# escape (backslash u 0000) or String.fromCharCode(0), never a raw NUL byte.
#
# Only text-source extensions are scanned; real binary assets (png/mp3/jks/...)
# under tools/ are skipped on purpose.
#
# Run manually:  bash scripts/no-binary-source.sh
#
# Exits non-zero if any scanned text-source file contains a NUL byte.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HITS=$(python3 - <<'PY'
import os
TEXT_EXTS = ('.dart', '.arb', '.json', '.yaml', '.yml', '.sh', '.md', '.txt',
             '.py', '.gradle', '.kts', '.plist', '.xml', '.html', '.ts')
SKIP_DIRS = {'node_modules', 'dist', '.dart_tool', 'build'}
bad = []
for root in ('lib', 'test', 'tools', 'scripts', 'cloud'):
    if not os.path.isdir(root):
        continue
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if not name.endswith(TEXT_EXTS):
                continue
            path = os.path.join(dirpath, name)
            try:
                with open(path, 'rb') as fh:
                    if b'\x00' in fh.read():
                        bad.append(path)
            except OSError:
                pass
print('\n'.join(sorted(bad)))
PY
)

if [ -n "$HITS" ]; then
  echo "no-binary-source: NUL byte in text source (use a backslash-u escape or String.fromCharCode(0), not a raw NUL byte):"
  echo
  echo "$HITS"
  exit 1
fi

echo "no-binary-source: clean"
