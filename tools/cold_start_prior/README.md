# Cold-start prior builder (offline, ML)

Builds the per-locale **context-aware cold-start prior** that seeds the glow
bandit so suggestions are sensible from the very first tap, instead of the
current context-blind per-button `base_weight` (which makes unrelated tiles
shimmer after "Eat").

Offline, on-laptop. Runs a multilingual language model over the board
vocabulary and emits a data artifact the app bakes in. Never runs on device.

## The transition values come from a language model, not from hand-authoring

For a previous button `prev` and a candidate `cand`, the score is the
**pointwise mutual information** under a multilingual causal LM:

    PMI(prev -> cand) = mean over per-locale frames f of
        [ logP(cand | f.with_prev) - logP(cand | f.baseline) ]

The baseline divides out the candidate's raw frequency, so only words the
previous word actually pulls up score high. Frames are per-locale
(`data/frames.json`: "I want to ___" / "Quiero ___" / "أريد أن ___"), so the
model scores real sequences in each language and en/es/ar genuinely differ.

Why a causal LM and not embeddings: embeddings rank by *similarity* (eat ~ drink)
which is the wrong axis -- glow needs what *follows* (eat -> apple). This was
verified empirically: pure-embedding similarity ranked the objects of "want"
LAST. PMI from an LM measures the transition, which is what we want.

## Run

```sh
# Production (you run this, outside the dev sandbox):
python3 build_prior.py --all --model bigscience/bloom-1b7

# Faster / lower quality (CI smoke, or a quick look):
python3 build_prior.py --all --model bigscience/bloom-560m

# Higher quality if you have the time / a GPU:
python3 build_prior.py --all --model facebook/xglm-2.9B
```

Flags: `--locale <xx>` for one language; `--no-gate` to disable the POS gate
(raw model); `--no-overrides` to ignore the clinical pins in `data/proposals.json` (which are applied by default).

### What you will see while it runs

A heartbeat line every ~1.5s on stdout AND appended to `out/build.log`, during
model download/load and during scoring, e.g.:

```
[22:09:18] scoring en [bigscience/bloom-1b7] | 53/172 | 2.1/s | elapsed 25s | ETA 57s
...
===== BUILD SUMMARY =====
  [OK ] en: 172 contexts, 25092 overrides, 81.3s
  OVERALL: SUCCESS (all golden passed)
```

Scoring is FULL-SEQUENCE (every sub-token of each candidate), batched, on the Mac
GPU (MPS) / CUDA when available, else CPU. Rough time with bloom-1b7 on MPS: tens
of minutes for all three locales (Arabic slowest). Tune with `--batch-size`
(default 64; lower if you hit memory limits, higher if you have RAM/VRAM to
spare) and `--device`. PMI is cached per (locale, model, method) under
`out/_cache/`, so re-running to retune the gate/calibration/golden does NOT
reload the model or re-score (the model loads lazily, only on a cache miss). A
change to the scoring method bumps the cache tag so a stale cache is never
reused.

## Outputs (in `out/`)

- `<locale>.json`        - the artifact the app bakes in (the product)
- `review_<locale>.md`   - human-readable per-context (optional eyeball)
- `golden_<locale>.txt`  - validation result
- `build.log`            - full timestamped run log

## The golden gate

`data/golden.json` encodes robust, model-agnostic expectations -- chiefly
SUPPRESSION (the original bug: off-topic tiles must not glow after "eat"/"want")
plus a few high-confidence boosts. The build exits non-zero if any fail. It is a
floor, not a quality ceiling: passing means "no obvious nonsense," not "optimal."

## Provenance

Artifacts are stamped `MODEL_GENERATED`. The values are model-derived. There is
no human review step, by design. The safety net is structural, not procedural:
this is a COLD-START prior that washes
out as the child uses the app, and it only changes which tiles GLOW, never their
position. The automated golden gate catches gross nonsense; the optional eyeball
of `out/review_<locale>.md` is there if you want it, not required.

To override a specific pair, pin it in `data/proposals.json` and rebuild; pins
are applied by default and always win over the model. Guard each pin with a
golden frame so a rebuild cannot silently drop it (see `data/golden.json`).

The POS gate (`prior/grammar.py` + `data/grammar_scaffold.json`) is the only
non-model structure: it caps grammatically-implausible transitions below the
glow line. Part-of-speech level, not per-tile values, optional (`--no-gate`).

### Arabic note (informational, not a gate)

Arabic labels are MSA; children often use dialect, so some suggestions may read
as a touch formal. Not a blocker. If a specific pair looks wrong, pin a
correction in `proposals.json`.

## Adding a new language

See **`ADDING_A_LANGUAGE.md`** for the full end-to-end runbook (tool + app), with
Urdu as a worked example and the head-final/SOV frame caveat. In short: add the
board `label_<xx>` fields, one `LOCALE_SUFFIX` entry, one `data/frames.json`
block, run `build_prior.py --locale <xx>`, copy the artifact into
`assets/cold_start/`, and register the locale app-side. No code changes.

## Plug-in points

The model is configurable (`--model`). To swap the signal source entirely
(corpus n-grams from CHILDES, or a different scorer), implement the same
`{prev_id: {cand_id: w'}}` output in place of `prior/mlscore.build_ml_transitions`;
the artifact schema, report, golden, and app integration are unchanged.
