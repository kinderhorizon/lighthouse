#!/usr/bin/env python3
"""Build the cold-start prior artifact for one or more locales, using a real ML
transition model (causal-LM PMI; see prior/mlscore.py).

Usage:
  python3 build_prior.py --all                                   # en, es, ar
  python3 build_prior.py --locale en
  python3 build_prior.py --all --model bigscience/bloom-560m      # fast/noisy demo
  python3 build_prior.py --all --model bigscience/bloom-1b7       # production quality
  python3 build_prior.py --all --no-gate                          # raw model, no POS gate
  python3 build_prior.py --all --no-overrides                     # ignore data/proposals.json pins

The transition VALUES are produced by the language model, not hand-authored. The
optional POS gate (on by default) only suppresses grammatically-implausible
pairs (verb->question etc.) and is part-of-speech level, not per-tile values.
PMI is cached under out/_cache/ so re-running to retune calibration or the gate
does not re-invoke the model.

Exit code is non-zero if any golden frame fails (informational with a small
model; expect a bigger model to satisfy more frames).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from prior.blend import BuildParams  # noqa: E402
from prior.board import LOCALE_SUFFIX, load_roster  # noqa: E402
from prior.golden import run_golden  # noqa: E402
from prior.grammar import load_grammar  # noqa: E402
from prior.mlscore import (  # noqa: E402
    DEFAULT_MODEL,
    MLScorer,
    build_ml_transitions,
    load_frames,
)
from prior.progress import HeartbeatLogger  # noqa: E402
from prior.proposals import load_proposals  # noqa: E402
from prior.report import render_report  # noqa: E402

HERE = Path(__file__).resolve().parent


class LazyScorer:
    """Defers the (expensive) model load until a cache MISS actually needs it.

    A re-run that only retunes the gate / calibration / golden frames reuses the
    cached PMI and never loads the multi-GB model. Exposes `model_name` for cache
    keys and provenance without loading anything.
    """

    def __init__(self, model_name, logger, device=None, batch_size=None):
        self.model_name = model_name
        self._logger = logger
        self._device = device
        self._batch_size = batch_size
        self._real = None

    def _ensure(self):
        if self._real is None:
            self._logger.set_phase(f"loading model {self.model_name} (one-time download+load)")
            kwargs = {}
            if self._device is not None:
                kwargs["device"] = self._device
            if self._batch_size is not None:
                kwargs["batch_size"] = self._batch_size
            self._real = MLScorer(self.model_name, **kwargs)
            self._logger.log(f"model loaded: {self.model_name} on {self._real.device}")
        return self._real

    def baseline_seq_logprobs(self, *a, **k):
        return self._ensure().baseline_seq_logprobs(*a, **k)

    def pmi_scores(self, *a, **k):
        return self._ensure().pmi_scores(*a, **k)


def build_one(locale, roster, scorer, data_dir, out_dir, params, use_gate,
              use_overrides, progress):
    import time
    t0 = time.monotonic()
    frames = load_frames(data_dir, locale)
    grammar = load_grammar(data_dir) if use_gate else None
    overrides = None
    note = ""
    if use_overrides:
        props = load_proposals(data_dir, locale)
        overrides = props.as_dict()
        note = props.note

    slug = scorer.model_name.replace("/", "_")
    # "fullseq" tags the scoring method: full-sequence PMI. A method change must
    # change this so a stale first-token cache is never silently reused.
    cache_path = out_dir / "_cache" / f"{locale}_{slug}_fullseq.json"

    transitions = build_ml_transitions(
        roster, scorer, frames, locale, params,
        grammar=grammar, overrides=overrides, cache_path=cache_path,
        progress=progress,
    )

    out_dir.mkdir(parents=True, exist_ok=True)
    artifact = {
        "schema_version": 1,
        "locale": locale,
        "board_version": roster.board_version,
        "generated_for_boards": roster.board_ids,
        "prior_strength": params.prior_strength,
        "status": "MODEL_GENERATED",
        "provenance": {
            "method": "causal_lm_pmi",
            "model": scorer.model_name,
            "frames": frames,
            "pos_gate": use_gate,
            "manual_overrides": use_overrides,
        },
        "fallback": "absent (prev,cand) -> app uses the button base_weight",
        "transitions": transitions,
    }
    (out_dir / f"{locale}.json").write_text(
        json.dumps(artifact, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (out_dir / f"review_{locale}.md").write_text(
        render_report(locale, roster, transitions, note), encoding="utf-8"
    )
    passed, lines = run_golden(locale, roster, transitions, data_dir)
    (out_dir / f"golden_{locale}.txt").write_text("\n".join(lines), encoding="utf-8")

    n_pairs = sum(len(r) for r in transitions.values())
    secs = time.monotonic() - t0
    progress.log(
        f"DONE [{locale}] {len(transitions)} contexts, {n_pairs} overrides, "
        f"golden {'PASS' if passed else 'FAIL'} ({secs:.0f}s) -> {locale}.json"
    )
    return {"locale": locale, "contexts": len(transitions), "overrides": n_pairs,
            "golden_pass": passed, "seconds": round(secs, 1)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--locale", choices=sorted(LOCALE_SUFFIX))
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--model", default=DEFAULT_MODEL,
                    help=f"HF causal LM id (default {DEFAULT_MODEL})")
    ap.add_argument("--no-gate", dest="gate", action="store_false",
                    help="disable the part-of-speech gate (raw model output)")
    ap.add_argument("--no-overrides", dest="overrides", action="store_false",
                    help="ignore data/proposals.json clinical pins (default: applied)")
    ap.add_argument("--device", default=None,
                    help="torch device (default auto: mps on Mac, else cuda/cpu)")
    ap.add_argument("--batch-size", type=int, default=None,
                    help="candidates scored per forward pass (default 64; lower if OOM)")
    ap.add_argument("--boards-dir", default=str(HERE.parent.parent / "boards"))
    ap.add_argument("--data-dir", default=str(HERE / "data"))
    ap.add_argument("--out-dir", default=str(HERE / "out"))
    args = ap.parse_args()

    if not args.all and not args.locale:
        ap.error("pass --locale <xx> or --all")

    locales = sorted(LOCALE_SUFFIX) if args.all else [args.locale]
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    roster = load_roster(Path(args.boards_dir))
    params = BuildParams()

    logger = HeartbeatLogger(logfile=out_dir / "build.log", interval=1.5).start()
    logger.log(f"config: model={args.model} gate={args.gate} overrides={args.overrides} "
               f"locales={locales} board_version={roster.board_version} "
               f"candidates={len(roster.candidates())}")
    try:
        scorer = LazyScorer(args.model, logger,
                            device=args.device, batch_size=args.batch_size)

        results = []
        for loc in locales:
            results.append(build_one(loc, roster, scorer, Path(args.data_dir),
                                     out_dir, params, args.gate, args.overrides, logger))
    finally:
        logger.stop()

    # Success summary (also written to build.log via logger before stop()).
    all_ok = all(r["golden_pass"] for r in results)
    print("\n===== BUILD SUMMARY =====")
    for r in results:
        flag = "OK " if r["golden_pass"] else "GOLDEN-FAIL"
        print(f"  [{flag}] {r['locale']}: {r['contexts']} contexts, "
              f"{r['overrides']} overrides, {r['seconds']}s")
    print(f"  artifacts: {out_dir}/<locale>.json | log: {out_dir}/build.log")
    print(f"  OVERALL: {'SUCCESS (all golden passed)' if all_ok else 'COMPLETED with golden failures (review out/golden_*.txt; expected on a small model)'}")
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
