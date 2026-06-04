"""Golden-frame validation: the one automated quality gate.

There is no production usage signal to validate against (the app collects no
telemetry, by design), so "correct" cannot mean "fits observed clicks." It means
the prior obeys a set of known-good linguistic expectations (chiefly: off-topic
tiles must not glow). Those expectations live in data/golden.json as frames:

  {
    "prev": "btn_eat",
    "must_glow":     ["btn_more", "btn_water"],   # w' >= shimmer (0.50)
    "must_gold":     ["btn_food_apple"],          # w' >= gold    (0.75) [optional]
    "must_suppress": ["btn_happy", "btn_yes"],    # w' <  shimmer
    "locales": ["en", "es", "ar"]                 # optional; default all
  }

The frames are NEGATIVE-heavy on purpose: the original bug is that off-topic
tiles glow, so most assertions check suppression. A frame fails if any listed
expectation is violated for the locale under test. build_prior exits non-zero on
any failure, so a regression in the scaffold or proposals breaks the build.
"""

from __future__ import annotations

import json
from pathlib import Path

from .blend import GOLD_AT_OBS0, SHIMMER_AT_OBS0
from .board import Roster


def _effective_w(transitions: dict, roster_by_id: dict, prev_id: str, cand_id: str) -> float:
    row = transitions.get(prev_id, {})
    if cand_id in row:
        return row[cand_id]
    # No override -> the app falls back to the candidate's base_weight.
    b = roster_by_id.get(cand_id)
    return b.base_weight if b else 0.5


def run_golden(locale: str, roster: Roster, transitions: dict, data_dir: Path) -> tuple:
    """Return (passed: bool, lines: list[str]) describing each checked frame."""
    frames = json.loads((data_dir / "golden.json").read_text(encoding="utf-8"))
    by_id = roster.by_id()
    lines: list = []
    ok = True

    for frame in frames:
        locs = frame.get("locales")
        if locs and locale not in locs:
            continue
        prev = frame["prev"]

        for cid in frame.get("must_gold", []):
            w = _effective_w(transitions, by_id, prev, cid)
            if w < GOLD_AT_OBS0:
                ok = False
                lines.append(f"FAIL {prev} -> {cid}: w'={w:.2f} < gold {GOLD_AT_OBS0}")
        for cid in frame.get("must_glow", []):
            w = _effective_w(transitions, by_id, prev, cid)
            if w < SHIMMER_AT_OBS0:
                ok = False
                lines.append(f"FAIL {prev} -> {cid}: w'={w:.2f} < shimmer {SHIMMER_AT_OBS0}")
        for cid in frame.get("must_suppress", []):
            w = _effective_w(transitions, by_id, prev, cid)
            if w >= SHIMMER_AT_OBS0:
                ok = False
                lines.append(f"FAIL {prev} -> {cid}: w'={w:.2f} >= shimmer {SHIMMER_AT_OBS0} (should be suppressed)")

    lines.append("PASS: all golden frames satisfied" if ok else "FAILED: see above")
    return ok, lines
