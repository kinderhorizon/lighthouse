/// Recency-weighted semantic category tracker.
///
/// Per PRD section 3.1: "Decaying counter for semantic categories.
/// On every tap, multiply all category scores by 0.8." The currently
/// dominant category (if any score exceeds a small threshold) is
/// embedded in the state key as `Context:<Category>`. If no category
/// is dominant the state key reads `Context:` (empty), which the
/// bandit indexes as a distinct context.
///
/// In-memory only. The bandit's persisted state derives from this
/// transient tracker via the resulting state keys; the tracker
/// itself doesn't need to be saved.
library;

class SemanticContext {
  SemanticContext({
    this.decayFactor = 0.8,
    this.dominantThreshold = 0.3,
  });

  /// Multiplier applied to ALL category scores on every tick.
  /// Lower = forgets faster. 0.8 from PRD; tuning lives here.
  final double decayFactor;

  /// Minimum mean score for a category to be considered "dominant".
  /// Same value as ADR 0003's shimmer-threshold lower bound, which
  /// is not a coincidence; if the category is too cold for shimmer
  /// it should not be the embedded context either.
  final double dominantThreshold;

  final Map<String, double> _scores = <String, double>{};

  /// Snapshot of current scores. Read-only; the public API mutates
  /// through [recordTap].
  Map<String, double> get snapshot => Map.unmodifiable(_scores);

  /// Record a tap on a button whose Fitzgerald category is [category].
  /// First multiplies all existing scores by [decayFactor], then sets
  /// the tapped category to 1.0. Order is documented because the
  /// other ordering (set first, then decay) would erase the just-set
  /// signal on the same tick.
  void recordTap(String category) {
    final updated = <String, double>{};
    for (final entry in _scores.entries) {
      final decayed = entry.value * decayFactor;
      // Drop entries whose decayed value is too small to ever matter.
      // Prevents the map from growing forever as the child explores
      // many categories.
      if (decayed >= 0.05) {
        updated[entry.key] = decayed;
      }
    }
    updated[category] = 1.0;
    _scores
      ..clear()
      ..addAll(updated);
  }

  /// Returns the dominant category (highest score) if its score is at
  /// or above [dominantThreshold]; null otherwise. Ties broken by
  /// alphabetical order on the category name so state keys are stable.
  String? dominant() {
    if (_scores.isEmpty) return null;
    String? topKey;
    double topScore = -1;
    for (final entry in _scores.entries) {
      if (entry.value > topScore ||
          (entry.value == topScore &&
              (topKey == null || entry.key.compareTo(topKey) < 0))) {
        topKey = entry.key;
        topScore = entry.value;
      }
    }
    if (topKey == null || topScore < dominantThreshold) return null;
    return topKey;
  }

  /// Reset for tests + "Reset learned state" path.
  void clear() => _scores.clear();
}
