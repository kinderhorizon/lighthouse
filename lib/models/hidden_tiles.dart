/// Parent-authored per-board tile visibility (ADR 0019, Board Editor redesign).
///
/// A HIDE-ONLY overlay: for each board, the set of `buttonId`s the parent has
/// hidden from the child. Applied at read time in `activeBoardProvider` (the
/// CHILD render path) AFTER the layout overlay, by dropping the hidden buttons
/// so their slots render empty. The button's grid position is untouched (it
/// lives in the board + layout overlay), so showing a tile again restores it to
/// exactly where it was: muscle memory is preserved (ADR 0006).
///
/// The editor (`editableBoardsProvider`) deliberately does NOT apply this, so a
/// parent still sees and can un-hide a hidden tile (greyed, eye-off badge).
///
/// Hiding never touches a button's id or category, so it cannot scramble bandit
/// learning or glow (both key on id/category). Persisted as one more
/// backup-excluded JSON alongside board_layout.json / custom_buttons.json /
/// home_favourites.json (ADR 0002 / 0012 / 0013 / 0014).
library;

import 'aac_board.dart';

/// Drops the buttons hidden on [board] (ADR 0019). Used on the CHILD render path
/// (`activeBoardProvider`) AFTER the layout overlay: a hidden button simply
/// leaves the board, so its slot renders empty while every other tile keeps its
/// exact position (muscle memory, ADR 0006). The editor does NOT call this, so a
/// parent still sees hidden tiles (greyed) to un-hide them.
AACBoard applyHiddenTiles(AACBoard board, HiddenTiles hidden) {
  final ids = hidden.forBoard(board.boardId);
  if (ids.isEmpty) return board;
  final visible = [for (final b in board.buttons) if (!ids.contains(b.id)) b];
  if (visible.length == board.buttons.length) return board;
  return board.copyWithButtons(visible);
}

class HiddenTiles {
  const HiddenTiles(this._byBoard);

  const HiddenTiles.empty() : _byBoard = const {};

  /// boardId -> set of hidden buttonIds.
  final Map<String, Set<String>> _byBoard;

  bool get isEmpty => _byBoard.values.every((s) => s.isEmpty);

  /// The hidden-id set for [boardId] (empty if none).
  Set<String> forBoard(String boardId) => _byBoard[boardId] ?? const {};

  bool isHidden(String boardId, String buttonId) =>
      _byBoard[boardId]?.contains(buttonId) ?? false;

  Map<String, Set<String>> _clone() => {
        for (final e in _byBoard.entries) e.key: {...e.value},
      };

  /// Returns a copy with [buttonId] on [boardId] hidden (true) or shown (false).
  HiddenTiles withVisibility(String boardId, String buttonId, bool hidden) {
    final next = _clone();
    final set = next[boardId] ??= {};
    if (hidden) {
      set.add(buttonId);
    } else {
      set.remove(buttonId);
      if (set.isEmpty) next.remove(boardId);
    }
    return HiddenTiles(next);
  }

  /// Returns a copy with every id in [buttonIds] on [boardId] set to [hidden].
  /// Used by the editor's batch Hide / Show action.
  HiddenTiles withBulkVisibility(
    String boardId,
    Iterable<String> buttonIds,
    bool hidden,
  ) {
    final next = _clone();
    final set = next[boardId] ??= {};
    if (hidden) {
      set.addAll(buttonIds);
    } else {
      set.removeAll(buttonIds);
      if (set.isEmpty) next.remove(boardId);
    }
    return HiddenTiles(next);
  }

  /// Returns a copy with all hides for [boardId] cleared (per-board reset).
  HiddenTiles withoutBoard(String boardId) {
    if (!_byBoard.containsKey(boardId)) return this;
    final next = _clone()..remove(boardId);
    return HiddenTiles(next);
  }

  Map<String, dynamic> toJson() => {
        for (final e in _byBoard.entries)
          if (e.value.isNotEmpty) e.key: [...e.value],
      };

  factory HiddenTiles.fromJson(Map<String, dynamic> json) {
    final out = <String, Set<String>>{};
    for (final entry in json.entries) {
      final v = entry.value;
      if (v is! List) continue;
      final set = <String>{
        for (final id in v)
          if (id is String && id.isNotEmpty) id,
      };
      if (set.isNotEmpty) out[entry.key.toString()] = set;
    }
    return HiddenTiles(out);
  }
}
