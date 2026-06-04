/// Home-favourites providers (ADR 0013).
///
/// `favouritesProvider` holds the pinned refs. `homeFavouritesProvider`
/// resolves them to live buttons for the (stable, pinned-only) home strip.
/// `favouriteSuggestionsProvider` is the on-demand "used a lot, pin it?"
/// surface for the parental editor; it never feeds the child's strip.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../logic/logic.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'custom_button_provider.dart';
import 'persistence_provider.dart';

part 'favourites_provider.g.dart';

/// Max items shown in the home favourites strip (one glanceable row).
const int kMaxFavourites = 6;

@Riverpod(keepAlive: true)
FavouritesStore favouritesStore(FavouritesStoreRef ref) => FavouritesStore();

@Riverpod(keepAlive: true)
class Favourites extends _$Favourites {
  @override
  Future<List<ButtonRef>> build() => ref.read(favouritesStoreProvider).pins();

  Future<void> pin(String boardId, String buttonId) async {
    final next = await ref
        .read(favouritesStoreProvider)
        .pin((boardId: boardId, buttonId: buttonId));
    state = AsyncData(next);
  }

  Future<void> unpin(String boardId, String buttonId) async {
    final next = await ref
        .read(favouritesStoreProvider)
        .unpin((boardId: boardId, buttonId: buttonId));
    state = AsyncData(next);
  }
}

/// Builds a {ref -> button} lookup over every loaded board (custom overlays
/// included), so a promoted custom button resolves too.
Map<ButtonRef, AACButton> _index(List<AACBoard> boards) => {
      for (final b in boards)
        for (final btn in b.buttons)
          (boardId: b.boardId, buttonId: btn.id): btn,
    };

/// The pinned buttons to render in the home strip, in pin order. Resolves
/// against the loaded boards; folders and unresolvable refs are dropped.
/// Returns empty (without loading boards) when there are no pins, so the
/// common no-pins case adds no startup cost or home chrome.
@riverpod
Future<List<AACButton>> homeFavourites(HomeFavouritesRef ref) async {
  final pins = await ref.watch(favouritesProvider.future);
  if (pins.isEmpty) return const [];
  final index = _index(await ref.watch(editableBoardsProvider.future));
  final out = <AACButton>[];
  for (final pin in pins) {
    final btn = index[pin];
    if (btn == null || btn.type == AACButtonType.folder) continue;
    out.add(btn);
    if (out.length >= kMaxFavourites) break;
  }
  return out;
}

/// On-demand "used a lot" suggestions for the editor: most-tapped buttons not
/// already pinned, each with the board it lives on (so the editor can pin it).
/// Resolved to live buttons; folders dropped.
@riverpod
Future<List<({ButtonRef ref, AACButton button})>> favouriteSuggestions(
  FavouriteSuggestionsRef ref,
) async {
  final pins = (await ref.watch(favouritesProvider.future)).toSet();
  final top =
      await ref.watch(banditRepositoryProvider).topTappedButtons(limit: 24);
  final index = _index(await ref.watch(editableBoardsProvider.future));
  final out = <({ButtonRef ref, AACButton button})>[];
  for (final t in top) {
    if (pins.contains(t)) continue;
    final btn = index[t];
    if (btn == null || btn.type == AACButtonType.folder) continue;
    out.add((ref: t, button: btn));
    if (out.length >= 10) break;
  }
  return out;
}
