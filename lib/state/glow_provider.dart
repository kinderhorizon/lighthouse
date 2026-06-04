/// Glow / predictions provider.
///
/// Composes the active stateKey, asks the bandit ranker for top-K
/// predictions, and maps each prediction to a [GlowLevel] using the
/// observation-count-aware thresholds in ADR 0003.
///
/// `currentGlowProvider` is the single source of truth the widget tree
/// consumes. It re-evaluates when its inputs change (board, settings
/// locale, ContextManager state via [contextEpochProvider]) and is
/// invalidated explicitly by `_recordTap` after each communication act
/// so the next tap sees a fresh prediction set under the evolved
/// context.
library;

import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../i18n/locale_registry.dart';
import '../logic/logic.dart';
import '../models/models.dart';
import 'board_stack.dart';
import 'cold_start_provider.dart';
import 'context_provider.dart';
import 'persistence_provider.dart';
import 'settings_provider.dart';
import 'utterance_provider.dart';
import 'wifi_provider.dart';

part 'glow_provider.g.dart';

/// Maximum simultaneous glows on the board at any one moment. ADR 0003
/// section 2 caps this at 3 to 4 per PRD. We use 4 (gold + shimmer
/// combined never exceeds this).
const int kMaxGlows = 4;

/// RNG factory seam. Retained for tests / future use; `currentPredictions` now
/// seeds its own [math.Random] from (stateKey, epoch) so the Thompson draw is
/// stable per context (review NEW-B / ADR 0006), rather than drawing from a
/// fresh unseeded generator each frame.
@Riverpod(keepAlive: true)
math.Random Function() rngFactory(RngFactoryRef ref) =>
    () => math.Random();

@Riverpod(keepAlive: true)
BanditRanker banditRanker(BanditRankerRef ref) => BanditRanker(
      store: ref.watch(banditRepositoryProvider),
      // Same artifact instance the updater seeds from (one provider). Until it
      // loads, the empty resolver -> base_weight (today's behaviour); the
      // ranker rebuilds when the artifact resolves.
      coldStart: ref.watch(contextualColdStartProvider).valueOrNull ??
          const ContextualColdStart.empty(),
    );

/// Monotonically increasing counter that rotates whenever a tap has
/// been recorded. The glow provider watches this so it re-fetches
/// predictions after each tap (the ContextManager mutates in place;
/// Riverpod cannot otherwise observe the change).
@Riverpod(keepAlive: true)
class ContextEpoch extends _$ContextEpoch {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// Predictions for the currently active board under the current
/// context. Returned map is keyed by button id; only IDs with a
/// non-[GlowLevel.none] level appear. Buttons not in the map default
/// to no-glow.
/// Ranked predictions for the active board under the current context.
/// The list has at most [kMaxGlows] entries, ordered by Thompson draw
/// descending. Empty when no board is active.
@Riverpod(keepAlive: true)
Future<List<RankedPrediction>> currentPredictions(
  CurrentPredictionsRef ref,
) async {
  final epoch = ref.watch(contextEpochProvider);

  final board = ref.watch(activeBoardProvider);
  if (board == null) return const [];

  final ctx = ref.watch(contextManagerProvider);
  final settings = ref.watch(settingsNotifierProvider).valueOrNull;
  // When there is no explicit override, model the device locale (resolved
  // against the supported set), not a hardcoded 'en' (which would give an
  // Arabic-by-system user the wrong weekend semantics in the day-type).
  final locale = LocaleRegistry.effectiveLocale(settings?.localeOverride);

  final wifiHash =
      await ref.read(wifiSourceProvider).hashOfCurrentSsid();

  final stateKey = ctx.currentStateKey(
    now: DateTime.now(),
    locale: locale,
    wifiHash: wifiHash,
  );

  final ranker = ref.watch(banditRankerProvider);
  // Seed the Thompson draw by (stateKey, epoch) so a given context samples the
  // SAME top-K every time it is re-evaluated, until a tap advances the epoch
  // (ADR 0006: rank once per stateKey change, not per frame). With a fresh
  // unseeded Random the glow re-shuffled on every board navigation even though
  // the context was identical, so suggestions visibly jumped around (review
  // NEW-B). A tap bumps the epoch -> new seed -> the draw refreshes against the
  // updated posteriors.
  final rng = math.Random(Object.hash(stateKey, epoch));

  return ranker.topK(
    stateKey: stateKey,
    buttons: board.buttons,
    k: kMaxGlows,
    rng: rng,
  );
}

@Riverpod(keepAlive: true)
Future<Map<String, GlowLevel>> currentGlow(CurrentGlowRef ref) async {
  final ranked = await ref.watch(currentPredictionsProvider.future);
  final board = ref.watch(activeBoardProvider);
  // The last word in the sentence bar drives the semantic boost (ADR 0011):
  // after a verb with an object domain, light up the matching words/folder on
  // the current board. Watching the utterance makes the glow re-evaluate the
  // moment a word is tapped.
  final utterance = ref.watch(utteranceProvider);
  final lastTokenId = utterance.isEmpty ? null : utterance.last.id;
  return buildGlowMap(ranked, board: board, lastTokenId: lastTokenId);
}

/// Maps a list of ranked predictions to the glow-level map the widget
/// tree consumes. Extracted as a pure function so the threshold
/// integration is unit-testable without the full Riverpod plumbing.
///
/// When [board] and [lastTokenId] are supplied, a semantic boost (ADR 0011) is
/// layered on top: if the last-tapped word has a curated object domain (e.g.
/// "eat" -> food), the matching buttons on [board] are force-glowed gold
/// (folders included, a deliberate scoped exception to ADR 0003's
/// folders-never-glow rule). The boost is a DISPLAY concern only; the bandit's
/// learning snapshot (`currentPredictions`) stays pure.
Map<String, GlowLevel> buildGlowMap(
  List<RankedPrediction> ranked, {
  AACBoard? board,
  String? lastTokenId,
  int max = kMaxGlows,
}) {
  // After a transitive verb ("want", "need", ...), drop suggestions whose
  // category cannot grammatically follow it (responses, feelings, social,
  // questions), so a cold-start glow does not surface "want yes" / "want happy"
  // (clinical review). The child can still tap those; this only curbs the SUGGESTION.
  final suppressed = postVerbSuppressedCategories(lastTokenId);

  final base = <String, GlowLevel>{};
  for (final p in ranked) {
    if (suppressed.contains(p.button.category)) continue;
    final level = computeGlowLevel(
      posteriorMean: p.posteriorMean,
      observationCount: p.observationCount,
    );
    if (level.isGlowing) {
      base[p.button.id] = level;
    }
  }

  final boostCats = verbObjectBoosts(lastTokenId);
  if (board == null || boostCats.isEmpty) return base;

  final boosted = board.buttons
      .where((b) => boostCats.contains(b.category))
      .toList(growable: false);
  // Nothing to point at, or so many matches that we are clearly already on the
  // target sub-board (boosting half the grid is noise): defer to the bandit.
  if (boosted.isEmpty || boosted.length > max) return base;

  final out = <String, GlowLevel>{};
  for (final b in boosted.take(max)) {
    out[b.id] = GlowLevel.gold;
  }
  for (final entry in base.entries) {
    if (out.length >= max) break;
    out.putIfAbsent(entry.key, () => entry.value);
  }
  return out;
}
