"""The language-universal grammatical scaffold.

This is the formalised, expanded successor to the app's hand-curated
`lib/logic/bandit/semantic_boost.dart` (ADR 0011): instead of six verbs mapping
to object categories, it is a full category->category affinity matrix plus
per-button overrides for the verbs that have a strong object domain.

It is deliberately CATEGORY level and LOCALE INDEPENDENT, exactly as ADR 0008 /
the existing boost establish: a button keeps its `id` and `category` in every
language; only its words are translated. "You do not say want-yes" holds in en /
es / ar alike, so this scaffold needs no per-locale variant. The thin
locale-specific signal lives in proposals.py instead.

An affinity is a MULTIPLIER on the prior odds (see blend.py): >1 boosts a
candidate given the previous button, <1 suppresses it, 1.0 leaves the unigram
base_weight untouched. Lookup precedence for (prev, candidate):
  1. a per-prev-button override keyed by the candidate's category
  2. else the category->category matrix entry
  3. else 1.0 (neutral: behave exactly like today's context-blind prior)
"""

from __future__ import annotations

import json
from pathlib import Path

from .board import Button


class Grammar:
    def __init__(self, scaffold: dict):
        self._matrix = scaffold.get("category_affinity", {})
        self._overrides = scaffold.get("prev_button_overrides", {})
        self._default = float(scaffold.get("default_affinity", 1.0))

    def affinity(self, prev: Button | None, cand: Button) -> float:
        """Multiplier on cand's prior odds given the previous button.

        prev is None for the sentence-start (no previous button) context, where
        we apply no grammatical shaping (the unigram base_weight stands).
        """
        if prev is None:
            return 1.0
        override = self._overrides.get(prev.id)
        if override is not None and cand.category in override:
            return float(override[cand.category])
        row = self._matrix.get(prev.category)
        if row is not None and cand.category in row:
            return float(row[cand.category])
        return self._default


def load_grammar(data_dir: Path) -> Grammar:
    raw = json.loads((data_dir / "grammar_scaffold.json").read_text(encoding="utf-8"))
    return Grammar(raw)
