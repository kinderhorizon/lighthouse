/// Tile-picture override providers (ADR 0019, "Replace picture").
///
/// Holds the parent-chosen `key(boardId,buttonId) -> absolute image path` map
/// and its store. Applied in BOTH `activeBoardProvider` (child) and
/// `editableBoardsProvider` (editor) via [AACButton.withIconUri]. Manual
/// Riverpod API (like [boardLayoutProvider]) so it needs no build_runner pass.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';

final iconOverrideStoreProvider = Provider<IconOverrideStore>(
  (ref) => IconOverrideStore(),
);

final iconOverridesProvider =
    AsyncNotifierProvider<IconOverridesNotifier, Map<String, String>>(
  IconOverridesNotifier.new,
);

class IconOverridesNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() =>
      ref.read(iconOverrideStoreProvider).load();

  /// Sets [image] as the picture for (boardId, buttonId), replacing any prior.
  Future<void> setImage(String boardId, String buttonId, File image) async {
    await future;
    final next = await ref
        .read(iconOverrideStoreProvider)
        .setImage(image, boardId: boardId, buttonId: buttonId);
    state = AsyncData(next);
  }

  /// Clears the override for (boardId, buttonId), restoring the original art.
  Future<void> clear(String boardId, String buttonId) async {
    await future;
    final next =
        await ref.read(iconOverrideStoreProvider).clear(boardId, buttonId);
    state = AsyncData(next);
  }

  /// Clears every picture override on [boardId] ("reset this board").
  Future<void> resetBoard(String boardId) async {
    await future;
    final next = await ref.read(iconOverrideStoreProvider).resetBoard(boardId);
    state = AsyncData(next);
  }

  /// Clears every picture override on every board ("reset everything").
  Future<void> resetAll() async {
    await future;
    final next = await ref.read(iconOverrideStoreProvider).resetAll();
    state = AsyncData(next);
  }
}
