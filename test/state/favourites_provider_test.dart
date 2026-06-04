/// Home-favourites provider resolution (ADR 0013).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';

class _FakeFavStore implements FavouritesStore {
  _FakeFavStore([List<ButtonRef>? seed]) : _items = [...?seed];
  final List<ButtonRef> _items;
  @override
  Future<List<ButtonRef>> pins() async => List.unmodifiable(_items);
  @override
  Future<List<ButtonRef>> pin(ButtonRef ref) async {
    if (!_items.contains(ref)) _items.add(ref);
    return List.unmodifiable(_items);
  }

  @override
  Future<List<ButtonRef>> unpin(ButtonRef ref) async {
    _items.remove(ref);
    return List.unmodifiable(_items);
  }
}

AACBoard _foodBoard() => AACBoard.fromJson({
      'schema_version': '1.0',
      'board_id': 'board_food',
      'board_name': 'Food',
      'grid_dimensions': [2, 2],
      'color_key': {},
      'buttons': [
        {
          'id': 'btn_food_apple',
          'label': 'Apple',
          'type': 'word',
          'voice_out': 'apple',
          'position': {'row': 0, 'col': 0},
          'category': 'food',
        },
        {
          'id': 'btn_food_folder',
          'label': 'Food',
          'type': 'folder',
          'voice_out': 'food',
          'position': {'row': 0, 'col': 1},
          'category': 'food_nav',
        },
      ],
    });

ProviderContainer _container(List<ButtonRef> pins) => ProviderContainer(
      overrides: [
        favouritesStoreProvider.overrideWithValue(_FakeFavStore(pins)),
        editableBoardsProvider.overrideWith((ref) async => [_foodBoard()]),
      ],
    );

void main() {
  test('no pins -> empty home strip (and boards not required)', () async {
    final c = _container(const []);
    addTearDown(c.dispose);
    expect(await c.read(homeFavouritesProvider.future), isEmpty);
  });

  test('a pin resolves to its live button', () async {
    final c = _container([(boardId: 'board_food', buttonId: 'btn_food_apple')]);
    addTearDown(c.dispose);
    final favs = await c.read(homeFavouritesProvider.future);
    expect(favs.map((b) => b.id), ['btn_food_apple']);
  });

  test('a folder pin is dropped', () async {
    final c =
        _container([(boardId: 'board_food', buttonId: 'btn_food_folder')]);
    addTearDown(c.dispose);
    expect(await c.read(homeFavouritesProvider.future), isEmpty);
  });

  test('an unresolvable pin is dropped', () async {
    final c = _container([(boardId: 'board_food', buttonId: 'btn_missing')]);
    addTearDown(c.dispose);
    expect(await c.read(homeFavouritesProvider.future), isEmpty);
  });
}
