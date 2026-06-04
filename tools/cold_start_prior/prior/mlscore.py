"""ML transition scorer: causal-LM pointwise mutual information (PMI).

THIS is the part that decides the numbers. For a previous button `prev` and a
candidate `cand`, the score answers "how much more likely is `cand` right after
`prev` than in general?" - a transition, not a similarity. From a multilingual
causal LM:

    PMI(prev -> cand) = mean over frames f of
        [ logP(cand | f.with_prev) - logP(cand | f.baseline) ]

logP(cand | context) is the mean log-probability over ALL of the candidate's
sub-tokens (FULL-SEQUENCE scoring). This matters: an earlier version scored only
the candidate's FIRST sub-token, which silently mis-scored every multi-token
word. e.g. "Toe" tokenizes to [' To', 'e']; its first piece ' To' is the start of
"to/today/tomorrow", so after "I want to ___" it scored as if it were the
preposition "to" and shot to the top ("want Toe"). On this board 61 of 172
candidates are multi-token, so first-token scoring was wrong for a THIRD of them.
Full-sequence scoring fixes it (Toe's PMI drops from ~+6 to ~+1, i.e. to the
bottom). The baseline (same frame without `prev`) divides out the candidate's raw
frequency. Frames are per-locale (data/frames.json), so en/es/ar differ for real.

Why a causal LM and not embeddings: embeddings rank by similarity (eat ~ drink),
the wrong axis -- glow needs what FOLLOWS (eat -> apple). Verified empirically.

Speed: candidates are scored in BATCHES (one forward pass per chunk of
candidates) and on the Mac GPU (MPS) / CUDA when available. Baselines do not
depend on `prev`, so they are computed once per locale.

Model is configurable. bloom-1b7 is the default; a larger multilingual model
(xglm-2.9B) is cleaner. Covers en/es/ar.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

DEFAULT_MODEL = "bigscience/bloom-1b7"
DEFAULT_BATCH = 64


class MLScorer:
    def __init__(self, model_name: str, device: str | None = None,
                 batch_size: int = DEFAULT_BATCH):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer

        self._torch = torch
        self.model_name = model_name
        self.batch_size = batch_size
        if device is None:
            if torch.backends.mps.is_available():
                device = "mps"
            elif torch.cuda.is_available():
                device = "cuda"
            else:
                device = "cpu"
        self.device = device

        self.tok = AutoTokenizer.from_pretrained(model_name)
        if self.tok.pad_token_id is None:
            self.tok.pad_token = self.tok.eos_token or self.tok.bos_token
        self.model = AutoModelForCausalLM.from_pretrained(model_name).to(device)
        self.model.eval()

    def _seq_logprobs(self, context: str, cands: list) -> dict:
        """Mean log P(cand tokens | context) for every candidate, batched.

        All candidates share the same `context` prefix, so the candidate tokens
        begin at a fixed position; we sum the LM log-probs over exactly those
        tokens (ignoring right padding) and divide by their count.
        """
        torch = self._torch
        prefix_len = len(self.tok(context).input_ids)
        full = [(c, self.tok(context + " " + c).input_ids) for c in cands]
        out: dict = {}

        for i in range(0, len(full), self.batch_size):
            chunk = full[i:i + self.batch_size]
            maxlen = max(len(ids) for _c, ids in chunk)
            input_ids, masks = [], []
            for _c, ids in chunk:
                pad = maxlen - len(ids)
                input_ids.append(ids + [self.tok.pad_token_id] * pad)
                masks.append([1] * len(ids) + [0] * pad)
            ii = torch.tensor(input_ids, device=self.device)
            am = torch.tensor(masks, device=self.device)
            with torch.no_grad():
                logits = self.model(input_ids=ii, attention_mask=am).logits
                logp = torch.log_softmax(logits, dim=-1)
            for r, (c, ids) in enumerate(chunk):
                ctoks = ids[prefix_len:]
                if not ctoks:
                    out[c] = -50.0
                    continue
                s = 0.0
                for k, t in enumerate(ctoks):
                    s += logp[r, prefix_len + k - 1, t].item()
                out[c] = s / len(ctoks)
        return out

    def baseline_seq_logprobs(self, frames: list, cands: list) -> list:
        """Full-sequence logprobs for each frame's baseline context (prev-free).

        Independent of `prev`, so computed once per locale and reused.
        """
        return [self._seq_logprobs(base, cands) for _with, base in frames]

    def pmi_scores(self, prev_label, cand_labels, frames, baselines, on_pass=None) -> dict:
        """{cand_label: PMI} for one previous word, averaged over frames."""
        acc = {c: 0.0 for c in cand_labels}
        for i, (with_tmpl, _base) in enumerate(frames):
            withs = self._seq_logprobs(with_tmpl.format(p=prev_label), cand_labels)
            if on_pass:
                on_pass()
            base = baselines[i]
            for c in cand_labels:
                acc[c] += withs[c] - base[c]
        n = len(frames)
        return {c: acc[c] / n for c in cand_labels}


def load_frames(data_dir: Path, locale: str) -> list:
    doc = json.loads((data_dir / "frames.json").read_text(encoding="utf-8"))
    if locale not in doc:
        raise KeyError(f"no frames for locale {locale!r} in frames.json")
    return doc[locale]


# --- calibration: PMI (unbounded) -> w' prior mean in (0,1) -------------------

def pmi_to_mean(pmi: float, k: float = 0.55, c: float = 0.0) -> float:
    """Logistic squash, slightly steeper than the first pass (k 0.43 -> 0.55),
    with NO center shift (c=0): PMI 0 -> 0.50 so a neutral-but-valid transition
    stays at the shimmer line rather than dropping out. The actual noise removal
    is done by the POS gate (it caps grammatically-implausible pairs at 0.45),
    not by squashing the calibration; a center shift over-punished weak-but-real
    transitions (e.g. Spanish ir->afuera) and is avoided.
    """
    return 1.0 / (1.0 + math.exp(-k * (pmi - c)))


def build_ml_transitions(roster, scorer, frames, locale, params,
                         grammar=None, overrides=None, cache_path=None,
                         progress=None):
    """Compute {prev_id: {cand_id: w'}} where w' comes from the LM PMI.

    - w' = pmi_to_mean(PMI)                     (the model decides the strength)
    - optional POS gate: a grammatically-implausible transition (grammar
      affinity < gate_threshold) is capped below the glow line.
    - optional manual overrides (proposals.json) win outright; default none.
    PMI is cached per (prev, model, locale) so re-running to retune calibration
    or the gate does NOT re-invoke the model.
    """
    import json as _json

    cands = roster.candidates()
    cand_labels = [b.label(locale) for b in cands]

    cache = {}
    if cache_path and Path(cache_path).exists():
        cache = _json.loads(Path(cache_path).read_text(encoding="utf-8"))

    baselines = None
    if any(prev.id not in cache for prev in cands):
        baselines = scorer.baseline_seq_logprobs(frames, cand_labels)

    if progress is not None:
        progress.set_phase(f"scoring {locale} [{scorer.model_name}]", total=len(cands))

    out = {}
    for prev in cands:
        if prev.id in cache:
            pmi_by_id = cache[prev.id]
        else:
            scores = scorer.pmi_scores(prev.label(locale), cand_labels, frames, baselines)
            pmi_by_id = {cands[i].id: scores[cand_labels[i]] for i in range(len(cands))}
            cache[prev.id] = pmi_by_id
        if progress is not None:
            progress.step()

        row = {}
        for cand in cands:
            if cand.id == prev.id:
                continue
            base = cand.base_weight
            w = pmi_to_mean(pmi_by_id[cand.id])
            gated = False
            if grammar is not None and grammar.affinity(prev, cand) < params.gate_threshold:
                w = min(w, params.gate_cap)
                gated = True
            if overrides:
                t = overrides.get(prev.id, {}).get(cand.id)
                if t is not None:
                    w = float(t)
                    gated = False
            w = min(max(w, params.w_min), params.w_max)
            if abs(w - base) >= params.material_delta or (gated and w < base):
                row[cand.id] = round(w, 4)
        if row:
            out[prev.id] = row

    if cache_path:
        Path(cache_path).parent.mkdir(parents=True, exist_ok=True)
        Path(cache_path).write_text(
            _json.dumps(cache, ensure_ascii=False), encoding="utf-8"
        )
    return out
