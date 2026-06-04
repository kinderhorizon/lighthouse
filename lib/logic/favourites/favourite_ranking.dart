/// Favourite-candidate ranking (ADR 0013).
///
/// Pure aggregation over tap events for the "used a lot, pin it?" suggestion
/// surface. This drives a parent-facing SUGGESTION only; it never reorders the
/// child's home strip (which renders pinned items in stable order). Computed on
/// demand in the editor, never on the home hot path.
library;

/// A reference to a button by its board + id. Records have value equality, so
/// these work directly as map keys / set members.
typedef ButtonRef = ({String boardId, String buttonId});

/// Ranks [taps] by descending frequency and returns the top [limit] refs.
/// Ties keep first-seen order (stable), so the result is deterministic.
List<ButtonRef> rankByFrequency(Iterable<ButtonRef> taps, {required int limit}) {
  final counts = <ButtonRef, int>{};
  final firstSeen = <ButtonRef, int>{};
  var i = 0;
  for (final t in taps) {
    counts[t] = (counts[t] ?? 0) + 1;
    firstSeen.putIfAbsent(t, () => i++);
  }
  final refs = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : firstSeen[a]!.compareTo(firstSeen[b]!);
    });
  return refs.take(limit).toList(growable: false);
}
