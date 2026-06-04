/// The cold-start Beta prior for a button that has no learned row yet (ADR
/// 0003): `alpha = 2 * w`, `beta = 2 * (1 - w)`, where `w` is the button's
/// base weight treated as a Bernoulli mean in [0, 1].
///
/// This is the SINGLE definition of that prior. The ranker scores a no-row
/// button under this synthetic prior; the updater seeds the persisted
/// cold-start row from it. If those two ever diverged, a button would be
/// ranked under one prior and learned under another, so they MUST stay
/// identical. Sharing one function makes divergence impossible (it used to be
/// two textually-identical copies, identical only by luck).
///
/// The clamp here is load-bearing, not cosmetic. A base weight can originate
/// from an UNTRUSTED imported pack (ADR 0015 device-to-device vocab sharing),
/// and `BetaSampler.sample` documents a precondition that both parameters are
/// strictly positive. Without the clamp:
///   - `w > 1`  -> `beta < 0`  -> the sampler's `sqrt(9 * d)` of a negative
///     yields a NaN draw, and NaN sorts ABOVE every real value in the ranker's
///     descending sort, pinning a crafted button to the top of the suggestions
///     over genuinely-learned buttons. Worst case for a non-speaking child.
///   - `w == 1` -> `beta == 0` -> the button always glows.
///   - `w == 0` -> `alpha == 0` -> the button can never glow.
/// The parse bound in `AACButton.fromJson` rejects `w` outside [0, 1], but it
/// lets the endpoints 0.0 and 1.0 through; only this clamp closes those.
///
/// The epsilon is tiny (1e-6) so it does NOT distort a legitimate low weight:
/// ADR 0003 deliberately contemplates priors as low as `2 * 0.05 = 0.1`, and
/// the sampler's shape-< 1 path exists for exactly that. A high-but-valid
/// weight glowing strongly at cold start is the intended feature; the bug is
/// only the NaN pinning and the degenerate 0/1 endpoints, and a tiny epsilon
/// removes those without changing real priors.
library;

const double _coldStartEpsilon = 1e-6;

/// Returns the cold-start `(alpha, beta)` for [baseWeight], clamped so both are
/// finite and strictly positive. A non-finite weight (which the parser already
/// rejects, but a directly-constructed button could carry) falls back to the
/// neutral 0.5 prior rather than propagating NaN.
({double alpha, double beta}) coldStartPrior(double baseWeight) {
  final w = baseWeight.isFinite
      ? baseWeight.clamp(_coldStartEpsilon, 1.0 - _coldStartEpsilon)
      : 0.5;
  return (alpha: 2.0 * w, beta: 2.0 * (1.0 - w));
}
