/// Context-aware cold-start prior (ADR 0003 + offline `tools/cold_start_prior/`).
///
/// The bandit already keys learning on a `stateKey` that contains the previous
/// button (`Prev:btn_id`); only the COLD-START prior was context-blind, so an
/// unrelated mid-weight tile could shimmer after "Eat". This resolver feeds the
/// prior a per-`(locale, prevButtonId, candidateButtonId)` mean `w'` produced
/// offline (a bundled, signed-able static artifact, `assets/cold_start/
/// <locale>.json`), so glow is sensible from the first tap.
///
/// It changes ONLY the prior mean fed to [coldStartPrior]; the Beta shape, the
/// clamp, and prior strength 2 are unchanged. A missing `(prev, cand)` entry, a
/// missing/unsupported-locale artifact, or sentence-start (no previous button)
/// all fall back to the button's `base_weight`, i.e. EXACTLY today's behaviour.
///
/// Both the ranker (which scores a no-row button under the prior) and the
/// updater (which seeds a fresh persisted row from the same prior) MUST resolve
/// the prior identically, or a button is ranked under one prior and learned
/// under another (see the warning in `cold_start_prior.dart`). They both call
/// [priorFor] with the same `stateKey`, so they cannot diverge.
library;

import 'dart:math' as math;

import '../../models/models.dart';
import 'cold_start_prior.dart';

/// Sentinel prev-key for sentence start (no previous button). The shipped
/// artifacts carry no `_NONE` row, so this resolves to `null` -> `base_weight`,
/// which is the intended sentence-start behaviour (unchanged from today).
const String _kNoPrevKey = '_NONE';

/// Mean used for a candidate that is ABSENT from a KNOWN context row. When the
/// artifact has a row for the previous button, that row IS the model's
/// suggestion set for the context; a candidate missing from it was not endorsed
/// (POS-gated as ungrammatical, e.g. "want" -> "go"/"I", or simply unranked).
/// Such a candidate must not glow on its intrinsic `base_weight` (high-weight
/// verbs and safety words otherwise leak into every context), so it is capped to
/// this floor, just below the obs-0 shimmer threshold (0.50, ADR 0003) and equal
/// to the tool's own explicit-suppression value. It is not pinned to zero: the
/// child can still tap it and it learns normally from real observations.
const double _kSuppressedInContextMean = 0.45;

/// Resolves the context-aware cold-start mean `w'` for a
/// `(previousButton, candidate)` pair from a per-locale transitions artifact.
class ContextualColdStart {
  const ContextualColdStart(this._transitions);

  /// The no-data resolver: every lookup misses, so every prior falls back to
  /// `base_weight` (today's context-blind behaviour). Used as the fail-safe
  /// default everywhere, so a missing/unparseable artifact is never an error.
  const ContextualColdStart.empty()
      : _transitions = const <String, Map<String, double>>{};

  /// Parses the `transitions` object of a cold-start artifact. Tolerant by
  /// design: any malformed shape (missing `transitions`, non-string keys,
  /// non-finite weights) is skipped rather than thrown, degrading to fewer
  /// entries (and thus more `base_weight` fallbacks), never to a crash. The
  /// loader catches IO; this never throws on shape.
  factory ContextualColdStart.fromArtifactJson(Map<String, dynamic> json) {
    final raw = json['transitions'];
    if (raw is! Map) return const ContextualColdStart.empty();
    final out = <String, Map<String, double>>{};
    raw.forEach((prev, cands) {
      if (prev is String && cands is Map) {
        final inner = <String, double>{};
        cands.forEach((cand, w) {
          if (cand is String && w is num && w.toDouble().isFinite) {
            inner[cand] = w.toDouble();
          }
        });
        if (inner.isNotEmpty) out[prev] = inner;
      }
    });
    return ContextualColdStart(out);
  }

  final Map<String, Map<String, double>> _transitions;

  /// `w'` for `(prevKey, candidateId)`, or `null` to fall back to `base_weight`.
  /// O(1).
  double? meanFor({required String prevKey, required String candidateId}) =>
      _transitions[prevKey]?[candidateId];

  /// The cold-start `(alpha, beta)` for [button] under [stateKey]: the
  /// context-aware mean when the artifact has an entry for
  /// `(prevButton, button.id)`, else the button's `base_weight` (today's
  /// behaviour). [coldStartPrior] is unchanged (same Beta shape + clamp +
  /// strength 2); only its input mean becomes context-aware.
  ///
  /// THE shared entry point for both the ranker and the updater, so they can
  /// never disagree on a no-row button's prior.
  ///
  /// Resolution:
  /// - KNOWN context (the artifact has a row for the previous button): use the
  ///   candidate's mean if the row lists it; if it is ABSENT, the model did not
  ///   endorse it for this context (POS-gated / unranked) so cap it to
  ///   [_kSuppressedInContextMean] rather than letting a high `base_weight`
  ///   surface a word the context excludes ("want" -> "go"/"I").
  /// - UNKNOWN context (no row for the previous button: sentence start with no
  ///   `_NONE` row, a custom/imported button, or a prev the artifact never
  ///   scored): fall back to the button's `base_weight` (today's behaviour),
  ///   because there is no contextual signal to suppress against.
  ({double alpha, double beta}) priorFor(String stateKey, AACButton button) {
    final prevKey = prevButtonIdFromStateKey(stateKey) ?? _kNoPrevKey;
    final row = _transitions[prevKey];
    final double w;
    if (row == null) {
      w = button.baseWeight;
    } else {
      // `math.min` never RAISES a low base_weight; it only caps a high one, so
      // an absent low-weight candidate stays at its (already non-glowing) base.
      w = row[button.id] ??
          math.min(button.baseWeight, _kSuppressedInContextMean);
    }
    return coldStartPrior(w);
  }
}

/// Extracts the previous-button id from [stateKey]
/// (`"TimeBlock_DayType|WifiHash|Prev:btn_id|Context:Category"`), or `null` when
/// there is no previous button (sentence start; the segment is a bare `Prev:`).
///
/// ONE shared helper used by every prior resolution, so the contextual key is
/// derived identically everywhere. Matches the `Prev:` segment by prefix rather
/// than by position, so it is robust to the (fixed) segment order.
String? prevButtonIdFromStateKey(String stateKey) {
  const prefix = 'Prev:';
  for (final segment in stateKey.split('|')) {
    if (segment.startsWith(prefix)) {
      final id = segment.substring(prefix.length);
      return id.isEmpty ? null : id;
    }
  }
  return null;
}
