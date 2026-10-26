/// In-memory stand-ins for the parent-customization stores, for widget and
/// provider tests. Every method completes via a microtask (never real file IO,
/// which does not complete under pumpAndSettle's fake async). Semantics mirror
/// the real stores closely enough for the flows under test: add / update in
/// place / delete many / never-reused ids.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';

class FakeCustomButtonStore implements CustomButtonStore {
  FakeCustomButtonStore([List<CustomButton>? seed]) : items = [...?seed];

  final List<CustomButton> items;
  final Map<String, int> counters = {};
  final List<String> deletedImages = [];
  int importedImages = 0;

  @override
  Future<List<CustomButton>> load() async => List.unmodifiable(items);

  @override
  Future<String> allocateId(String boardId) async {
    final n = counters[boardId] ?? 0;
    counters[boardId] = n + 1;
    return 'custom_${boardId}_$n';
  }

  @override
  Future<String> allocateCategoryBoardId() async {
    final n = counters[CustomButtonStore.categoryCounterKey] ?? 0;
    counters[CustomButtonStore.categoryCounterKey] = n + 1;
    return 'cat_$n';
  }

  @override
  Future<List<CustomButton>> add(CustomButton b) async {
    items
      ..removeWhere((x) => x.id == b.id)
      ..add(b);
    return List.unmodifiable(items);
  }

  @override
  Future<List<CustomButton>> update(CustomButton b) async {
    final i = items.indexWhere((x) => x.id == b.id);
    if (i >= 0) items[i] = b;
    return List.unmodifiable(items);
  }

  @override
  Future<List<CustomButton>> removeById(String id) async {
    items.removeWhere((b) => b.id == id);
    return List.unmodifiable(items);
  }

  @override
  Future<List<CustomButton>> removeMany(Set<String> ids) async {
    items.removeWhere((b) => ids.contains(b.id));
    return List.unmodifiable(items);
  }

  @override
  Future<List<CustomButton>> removeForBoard(String boardId) async {
    items.removeWhere((b) => b.boardId == boardId);
    return List.unmodifiable(items);
  }

  @override
  Future<List<CustomButton>> clearAll() async {
    items.clear();
    return List.unmodifiable(items);
  }

  @override
  Future<String> importImage(File source,
      {required String suggestedName}) async {
    importedImages++;
    return '/fake/custom_images/$suggestedName.png';
  }

  @override
  Future<void> deleteImage(String absolutePath) async {
    if (absolutePath.isNotEmpty) deletedImages.add(absolutePath);
  }
}

class FakeVoiceStore implements CustomVoiceStore {
  FakeVoiceStore([Map<String, String>? seed]) : m = {...?seed};
  final Map<String, String> m;

  @override
  Future<Map<String, String>> load() async => Map.of(m);

  @override
  Future<Map<String, String>> importClip(File source,
      {required String buttonId}) async {
    m[buttonId] = '$buttonId.m4a';
    return Map.of(m);
  }

  @override
  Future<Map<String, String>> remove(String buttonId) async {
    m.remove(buttonId);
    return Map.of(m);
  }

  @override
  Future<Map<String, String>> removeMany(Iterable<String> buttonIds) async {
    final s = buttonIds.toSet();
    m.removeWhere((k, _) => s.contains(k));
    return Map.of(m);
  }

  @override
  Future<Map<String, String>> clearAll() async {
    m.clear();
    return Map.of(m);
  }
}

class FakeFavStore implements FavouritesStore {
  FakeFavStore([List<ButtonRef>? seed]) : pinsList = [...?seed];
  final List<ButtonRef> pinsList;

  @override
  Future<List<ButtonRef>> pins() async => List.unmodifiable(pinsList);

  @override
  Future<List<ButtonRef>> pin(ButtonRef ref) async {
    if (!pinsList.contains(ref)) pinsList.add(ref);
    return List.unmodifiable(pinsList);
  }

  @override
  Future<List<ButtonRef>> unpin(ButtonRef ref) async {
    pinsList.removeWhere((r) => r == ref);
    return List.unmodifiable(pinsList);
  }
}

class FakeHiddenStore implements HiddenTilesStore {
  FakeHiddenStore([HiddenTiles? seed]) : h = seed ?? const HiddenTiles.empty();
  HiddenTiles h;

  @override
  Future<HiddenTiles> load() async => h;

  @override
  Future<void> save(HiddenTiles hidden) async => h = hidden;
}

class FakeLayoutStore implements BoardLayoutStore {
  FakeLayoutStore([BoardLayout? seed]) : l = seed ?? const BoardLayout.empty();
  BoardLayout l;

  @override
  Future<BoardLayout> load() async => l;

  @override
  Future<void> save(BoardLayout layout) async => l = layout;
}

class FakeIconStore implements IconOverrideStore {
  final Map<String, String> m = {};

  @override
  Future<Map<String, String>> load() async => Map.of(m);

  @override
  Future<Map<String, String>> setImage(File source,
      {required String boardId, required String buttonId}) async {
    m[IconOverrideStore.key(boardId, buttonId)] = 'x';
    return Map.of(m);
  }

  @override
  Future<Map<String, String>> clear(String boardId, String buttonId) async {
    m.remove(IconOverrideStore.key(boardId, buttonId));
    return Map.of(m);
  }

  @override
  Future<Map<String, String>> resetBoard(String boardId) async {
    m.removeWhere((k, _) => k.startsWith(IconOverrideStore.key(boardId, '')));
    return Map.of(m);
  }

  @override
  Future<Map<String, String>> resetAll() async {
    m.clear();
    return Map.of(m);
  }
}

/// The overrides that swap every parent-customization store for an
/// in-memory fake.
List<Override> fakeStoreOverrides({
  FakeCustomButtonStore? buttons,
  FakeVoiceStore? voices,
  FakeFavStore? favourites,
  FakeHiddenStore? hidden,
  FakeLayoutStore? layout,
  FakeIconStore? icons,
}) =>
    [
      customButtonStoreProvider
          .overrideWithValue(buttons ?? FakeCustomButtonStore()),
      customVoiceStoreProvider.overrideWithValue(voices ?? FakeVoiceStore()),
      favouritesStoreProvider.overrideWithValue(favourites ?? FakeFavStore()),
      hiddenTilesStoreProvider.overrideWithValue(hidden ?? FakeHiddenStore()),
      boardLayoutStoreProvider.overrideWithValue(layout ?? FakeLayoutStore()),
      iconOverrideStoreProvider.overrideWithValue(icons ?? FakeIconStore()),
    ];
