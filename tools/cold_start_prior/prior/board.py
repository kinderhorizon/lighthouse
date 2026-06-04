"""Board parsing: turn the shipped board JSON files into a flat roster.

The app's source of truth for the vocabulary is `boards/*.json` (core_main plus
the eight sub-boards). Each button carries a stable, locale-independent `id`
(btn_eat, btn_want, ...), a `category`, a `base_weight` (the current unigram
prior mean in [0,1]), and per-locale `label` / `label_es` / `label_ar` fields.

The cold-start prior is keyed on those stable ids, so this loader is the single
bridge between the app's data and the builder. If the board schema changes, this
is the one file to update; everything downstream speaks in `Button` objects.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

# Locales the builder supports. Each maps to the JSON field suffix the board
# files use. The empty suffix is English (the unsuffixed `label` / `voice_out`).
LOCALE_SUFFIX = {"en": "", "es": "_es", "ar": "_ar"}


@dataclass(frozen=True)
class Button:
    """One board button, flattened across locales."""

    id: str
    category: str
    btype: str  # "word" | "phrase" | "folder"
    board_id: str
    base_weight: float
    labels: dict = field(default_factory=dict)  # locale -> display label

    @property
    def is_folder(self) -> bool:
        # Folders are navigation, not communication (ADR 0003): the ranker never
        # scores them, so the cold-start prior never targets them either.
        return self.btype == "folder"

    def label(self, locale: str) -> str:
        return self.labels.get(locale) or self.labels.get("en") or self.id


@dataclass
class Roster:
    """Every button across every bundled board, indexed for lookup."""

    buttons: list  # list[Button]
    board_version: str
    board_ids: list  # list[str], in load order

    def by_id(self):
        return {b.id: b for b in self.buttons}

    def candidates(self):
        """Buttons the bandit can rank (everything the ranker sees): non-folder."""
        return [b for b in self.buttons if not b.is_folder]


def _label_for(raw: dict, locale: str) -> str | None:
    suffix = LOCALE_SUFFIX[locale]
    key = f"label{suffix}"
    val = raw.get(key)
    return val if isinstance(val, str) and val.strip() else None


def load_roster(boards_dir: Path) -> Roster:
    """Load core_main first (it sets board_version), then every other board.

    A button id can appear on only one board in the bundled set, so the flat
    roster has no id collisions; we assert that to catch a future authoring slip.
    """
    files = sorted(boards_dir.glob("*.json"))
    if not files:
        raise FileNotFoundError(f"no board JSON files under {boards_dir}")

    # core_main first so its schema_version is authoritative for the artifact.
    files.sort(key=lambda p: (p.stem != "core_main", p.stem))

    buttons: list = []
    seen_ids: set = set()
    board_ids: list = []
    board_version = ""

    for path in files:
        doc = json.loads(path.read_text(encoding="utf-8"))
        bid = doc.get("board_id", path.stem)
        board_ids.append(bid)
        if path.stem == "core_main":
            board_version = str(doc.get("schema_version", ""))
        for raw in doc.get("buttons", []):
            bid_btn = raw["id"]
            if bid_btn in seen_ids:
                raise ValueError(
                    f"duplicate button id {bid_btn!r} (in {path.name}); the "
                    "cold-start prior keys on unique ids"
                )
            seen_ids.add(bid_btn)
            labels = {}
            for loc in LOCALE_SUFFIX:
                lbl = _label_for(raw, loc)
                if lbl:
                    labels[loc] = lbl
            buttons.append(
                Button(
                    id=bid_btn,
                    category=raw.get("category", ""),
                    btype=raw.get("type", "word"),
                    board_id=bid,
                    base_weight=float(raw.get("base_weight", 0.5)),
                    labels=labels,
                )
            )

    return Roster(buttons=buttons, board_version=board_version, board_ids=board_ids)
