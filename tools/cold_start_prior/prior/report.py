"""Human-readable report (optional eyeball).

The machine artifact (out/<locale>.json) is for the app. THIS is for a human who
wants to glance at the result: for each meaningful previous-button context it
shows, in that locale's words, which tiles the prior will BOOST (gold vs shimmer)
and which it SUPPRESSES below the glow line. Not required reading; reviewing is
optional. To change a specific pair, pin it in proposals.json (applied by default).
"""

from __future__ import annotations

from .blend import GOLD_AT_OBS0, SHIMMER_AT_OBS0
from .board import Roster

# Contexts worth showing a reviewer first (the high-traffic verbs / cores). The
# rest still appear, after these, so nothing is hidden.
_PRIORITY_PREV = [
    "_NONE", "btn_i", "btn_you", "btn_want", "btn_need", "btn_like",
    "btn_eat", "btn_drink", "btn_go", "btn_play", "btn_more", "btn_get",
]


def _glow_word(w: float) -> str:
    if w >= GOLD_AT_OBS0:
        return "GOLD"
    if w >= SHIMMER_AT_OBS0:
        return "shimmer"
    return "(below glow)"


def render_report(
    locale: str,
    roster: Roster,
    transitions: dict,
    note: str,
) -> str:
    by_id = roster.by_id()

    def lbl(bid: str) -> str:
        b = by_id.get(bid)
        return b.label(locale) if b else bid

    lines: list = []
    lines.append(f"# Cold-start prior -- locale: {locale}")
    lines.append("")
    lines.append("> Model-generated (causal-LM PMI). Optional eyeball: to override a")
    lines.append("> specific pair, pin it in data/proposals.json and rebuild.")
    lines.append("")
    if note:
        lines.append(f"**Locale note:** {note}")
        lines.append("")
    lines.append(
        "For each previous button, the tiles whose cold-start glow this context "
        "changes. GOLD >= 0.75, shimmer >= 0.50, below 0.50 is suppressed out of "
        "the glow. Tiles not listed keep their default base_weight."
    )
    lines.append("")

    ordered = [p for p in _PRIORITY_PREV if p in transitions]
    ordered += sorted(p for p in transitions if p not in _PRIORITY_PREV)

    for prev_id in ordered:
        row = transitions[prev_id]
        prev_name = "(sentence start)" if prev_id == "_NONE" else lbl(prev_id)
        lines.append(f"## After: {prev_name}  `{prev_id}`")
        ranked = sorted(row.items(), key=lambda kv: kv[1], reverse=True)
        boosts = [(c, w) for c, w in ranked if w >= SHIMMER_AT_OBS0]
        suppress = [(c, w) for c, w in ranked if w < SHIMMER_AT_OBS0]
        if boosts:
            lines.append("")
            lines.append("| glow | tile | id | w' |")
            lines.append("|---|---|---|---|")
            for c, w in boosts:
                lines.append(f"| {_glow_word(w)} | {lbl(c)} | `{c}` | {w:.2f} |")
        if suppress:
            names = ", ".join(f"{lbl(c)} ({w:.2f})" for c, w in suppress[:12])
            extra = "" if len(suppress) <= 12 else f", +{len(suppress) - 12} more"
            lines.append("")
            lines.append(f"_Suppressed below glow:_ {names}{extra}")
        lines.append("")
    return "\n".join(lines)
