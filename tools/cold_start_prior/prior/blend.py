"""Blend the signals into a context-adjusted prior mean w'(prev, candidate).

The app's cold-start prior (ADR 0003, lib/logic/bandit/cold_start_prior.dart) is
  alpha = 2 * w,  beta = 2 * (1 - w),  mean = w
where w is today the button's context-blind base_weight. This builder produces a
CONTEXT-AWARE replacement mean w'(prev, cand): the same Beta shape, same prior
strength (2 observations, so the obs-count-aware glow thresholds are undisturbed),
but a mean that depends on the previously tapped button.

How w' is computed for a (prev, cand) pair:
  1. base = cand.base_weight                          (the unigram, unchanged)
  2. grammar gives a multiplier m on the prior ODDS:
         odds  = base / (1 - base)
         odds' = odds * m
         w'    = odds' / (1 + odds')
     Working in odds space keeps w' in (0,1) for any m, shifts symmetrically, and
     leaves base untouched when m == 1 (neutral). m < 1 suppresses below the
     shimmer line; m > 1 boosts toward gold.
  3. if a tile-level proposal target t exists for (prev, cand), it WINS:
         w' = t
     (the proposal is the most specific, human-reviewable signal; it is what an
     an operator pins. Clamped into [w_min, w_max].)
  4. w' is clamped to [w_min, w_max] so no pair is a hard 0/1 (which would pin or
     forbid a tile regardless of learning), matching the app's epsilon clamp.

Only pairs whose w' differs MATERIALLY from base are emitted: the artifact is a
sparse override table. Absent (prev, cand) -> the app falls back to base_weight,
i.e. exactly today's behaviour. This keeps the file small and the semantics
crisp: "an entry means this context changes this tile's cold-start glow."
"""

from __future__ import annotations

from dataclasses import dataclass

from .board import Roster
from .grammar import Grammar
from .proposals import Proposals

# Shimmer / gold cold-start thresholds (ADR 0003, obs-count 0 band) so the
# builder reasons in the same units as the app's glow_level.dart.
SHIMMER_AT_OBS0 = 0.50
GOLD_AT_OBS0 = 0.75


@dataclass
class BuildParams:
    prior_strength: float = 2.0
    w_min: float = 0.05
    w_max: float = 0.95
    material_delta: float = 0.05  # min |w' - base| to bother emitting an override
    gate_threshold: float = 0.5   # grammar affinity below this -> POS-gate the pair
    gate_cap: float = 0.45        # gated pairs capped below the shimmer line (0.50)


def _odds_adjust(base: float, mult: float, lo: float, hi: float) -> float:
    base = min(max(base, 1e-9), 1 - 1e-9)
    odds = base / (1.0 - base)
    odds *= mult
    w = odds / (1.0 + odds)
    return min(max(w, lo), hi)


def build_transitions(
    roster: Roster,
    grammar: Grammar,
    proposals: Proposals,
    params: BuildParams,
) -> dict:
    """Return {prev_id: {cand_id: w'}} for material overrides only.

    prev ranges over every non-folder button (a tap on any word/phrase becomes
    the next context's `Prev:`) plus the special "_NONE" sentence-start context.
    cand ranges over every non-folder button across all boards, so a transition
    into a sub-board (eat -> apple) is covered even though apple is not on home.
    """
    cands = roster.candidates()
    by_id = roster.by_id()
    prev_ids = ["_NONE"] + [b.id for b in cands]

    out: dict = {}
    for prev_id in prev_ids:
        prev_btn = None if prev_id == "_NONE" else by_id[prev_id]
        row: dict = {}
        for cand in cands:
            # A tile is never its own most-likely successor; skip self so we do
            # not seed "eat -> eat". (The bandit can still learn a repeat.)
            if prev_btn is not None and cand.id == prev_btn.id:
                continue
            base = cand.base_weight
            target = proposals.target(prev_id, cand.id)
            if target is not None:
                # An explicit tile-level proposal is an intentional, operator-pinned
                # value: ALWAYS emit it, even when it sits within material_delta
                # of the base weight (float subtraction would otherwise drop e.g.
                # a 0.85 proposal over a 0.80 base). The proposal wins outright.
                w = min(max(float(target), params.w_min), params.w_max)
                row[cand.id] = round(w, 4)
                continue
            # Grammar-only adjustment: emit only when it moves the prior enough
            # to matter, so the artifact stays a sparse override table.
            mult = grammar.affinity(prev_btn, cand)
            w = _odds_adjust(base, mult, params.w_min, params.w_max)
            if abs(w - base) >= params.material_delta:
                row[cand.id] = round(w, 4)
        if row:
            out[prev_id] = row
    return out
