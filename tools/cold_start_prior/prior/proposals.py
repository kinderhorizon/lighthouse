"""Clinical/operator override layer (applied by default; --no-overrides to skip).

The transition VALUES come from the language model (prior/mlscore.py). This file
is empty by default and exists only so an operator can PIN or correct a specific
(prev_button -> candidate_button) pair after looking at the model's output. A pin
here wins over the model.

File schema (data/proposals.json):
  {
    "_shared":  { "<prev_id>": { "<cand_id>": <target 0..1>, ... }, ... },
    "en":       { ...overrides/additions on top of _shared... },
    "es":       { ... },
    "ar":       { ... },
    "_notes":   { "ar": "free-text note", ... }
  }
"""

from __future__ import annotations

import json
from pathlib import Path


class Proposals:
    def __init__(self, doc: dict, locale: str):
        shared = doc.get("_shared", {})
        per_locale = doc.get(locale, {})
        merged: dict = {}
        for prev_id, row in shared.items():
            merged[prev_id] = dict(row)
        for prev_id, row in per_locale.items():
            merged.setdefault(prev_id, {})
            merged[prev_id].update(row)  # locale wins over shared
        self._table = merged
        self.note = (doc.get("_notes", {}) or {}).get(locale, "")

    def target(self, prev_id: str | None, cand_id: str) -> float | None:
        if prev_id is None:
            prev_id = "_NONE"
        row = self._table.get(prev_id)
        if row is None:
            return None
        return row.get(cand_id)

    def as_dict(self) -> dict:
        """Merged {prev_id: {cand_id: target}} for use as ML overrides."""
        return self._table


def load_proposals(data_dir: Path, locale: str) -> Proposals:
    doc = json.loads((data_dir / "proposals.json").read_text(encoding="utf-8"))
    return Proposals(doc, locale)
