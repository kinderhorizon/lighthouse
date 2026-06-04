/// Parent-authored per-board layout overrides (ADR 0014).
///
/// A POSITION-ONLY overlay: for each board, a map of `buttonId -> Position`.
/// Applied at read time by [applyLayout], AFTER custom buttons are merged
/// (ADR 0012), and BEFORE the board reaches the grid/glow. It never touches a
/// button's id or category, so it cannot scramble bandit learning or glow
/// (both key on id/category, never slot). It is the SOLE source of position
/// deltas: a custom button's creation slot in custom_buttons.json is never
/// rewritten by a move, so "reset layout" reverts it to that creation slot.
///
/// Persisted as one more backup-excluded JSON alongside custom_buttons.json and
/// home_favourites.json (see BoardLayoutStore), keeping all parent-authored
/// board customization on one backup posture (ADR 0002 / 0012 / 0013).
library;

import 'aac_board.dart';
import 'aac_button.dart';

class BoardLayout {
  const BoardLayout(this._byBoard);

  const BoardLayout.empty() : _byBoard = const {};

  /// boardId -> (buttonId -> desired Position).
  final Map<String, Map<String, Position>> _byBoard;

  bool get isEmpty => _byBoard.values.every((m) => m.isEmpty);

  /// The override map for [boardId] (empty if the board has none).
  Map<String, Position> forBoard(String boardId) =>
      _byBoard[boardId] ?? const {};

  Position? positionOf(String boardId, String buttonId) =>
      _byBoard[boardId]?[buttonId];

  Map<String, Map<String, Position>> _clone() => {
        for (final e in _byBoard.entries) e.key: {...e.value},
      };

  /// Returns a copy with [buttonId] on [boardId] pinned to [position].
  BoardLayout withPosition(String boardId, String buttonId, Position position) {
    final next = _clone();
    (next[boardId] ??= {})[buttonId] = position;
    return BoardLayout(next);
  }

  /// Returns a copy with every entry in [positions] applied on [boardId] (the
  /// drag-reorder commit, ADR 0019): a single insertion-reorder moves many word
  /// tiles at once, so they are written in one transaction rather than a burst
  /// of single [withPosition] saves.
  BoardLayout withPositions(String boardId, Map<String, Position> positions) {
    if (positions.isEmpty) return this;
    final next = _clone();
    (next[boardId] ??= {}).addAll(positions);
    return BoardLayout(next);
  }

  /// Returns a copy where two buttons exchange positions (the swap gesture):
  /// [idA] takes [posB] and [idB] takes [posA]. Permutation-preserving.
  BoardLayout withSwap(
    String boardId,
    String idA,
    Position posA,
    String idB,
    Position posB,
  ) {
    final next = _clone();
    final board = next[boardId] ??= {};
    board[idA] = posB;
    board[idB] = posA;
    return BoardLayout(next);
  }

  /// Returns a copy with all overrides for [boardId] removed (per-board reset).
  BoardLayout withoutBoard(String boardId) {
    if (!_byBoard.containsKey(boardId)) return this;
    final next = _clone()..remove(boardId);
    return BoardLayout(next);
  }

  /// The global reset: an empty layout.
  BoardLayout cleared() => const BoardLayout.empty();

  Map<String, dynamic> toJson() => {
        for (final e in _byBoard.entries)
          if (e.value.isNotEmpty)
            e.key: {
              for (final p in e.value.entries)
                p.key: {'row': p.value.row, 'col': p.value.col},
            },
      };

  factory BoardLayout.fromJson(Map<String, dynamic> json) {
    final out = <String, Map<String, Position>>{};
    for (final boardEntry in json.entries) {
      final v = boardEntry.value;
      if (v is! Map) continue;
      final board = <String, Position>{};
      for (final btnEntry in v.entries) {
        final pos = btnEntry.value;
        if (pos is Map && pos['row'] is int && pos['col'] is int) {
          board[btnEntry.key.toString()] =
              (row: pos['row'] as int, col: pos['col'] as int);
        }
      }
      if (board.isNotEmpty) out[boardEntry.key.toString()] = board;
    }
    return BoardLayout(out);
  }
}

bool _inGrid(Position p, int rows, int cols) =>
    p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

/// Applies [layout] to [board] (which already has custom buttons merged) and
/// returns a board where each button sits at its parent-chosen slot.
///
/// TOTAL FUNCTION guaranteeing one button per slot, even under bundled-content
/// skew (ADR 0014 Decision 5). The resolve is a deterministic two-phase pass,
/// NOT independent per-button drops:
///   1. keep only overrides whose buttonId still resolves on [board];
///   2. place buttons in a stable order (overridden ids first, then by bundled
///      row-major slot, then by id), each taking its desired slot if free, else
///      its bundled slot if free, else the lowest-index free slot.
/// In the no-skew case this reproduces the parent's arrangement exactly; under
/// skew it degrades deterministically and never overlaps two buttons on a slot.
AACBoard applyLayout(AACBoard board, BoardLayout layout) {
  final overrides = layout.forBoard(board.boardId);
  if (overrides.isEmpty) return board;

  final rows = board.gridDimensions.rows;
  final cols = board.gridDimensions.cols;
  int idx(Position p) => p.row * cols + p.col;

  bool isFolder(AACButton b) => b.type == AACButtonType.folder;

  // Phase 1: desired position per live button (override if it still resolves,
  // else the button's bundled/creation slot). Folders (subcategories) are fixed
  // (ADR 0014 / Amendment 1): they ignore any override and always want their
  // bundled slot, so a stray override can never relocate one.
  final desired = <String, Position>{
    for (final b in board.buttons)
      b.id: isFolder(b) ? b.position : (overrides[b.id] ?? b.position),
  };

  // Stable placement order: folders claim their bundled slots FIRST (so they
  // are never displaced to a free slot under content-update skew), then
  // overridden ids, then the rest; ties broken deterministically so the resolve
  // is reproducible across runs.
  int rank(AACButton b) =>
      isFolder(b) ? 0 : (overrides.containsKey(b.id) ? 1 : 2);
  final order = [...board.buttons]..sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra - rb;
      final ai = idx(a.position);
      final bi = idx(b.position);
      if (ai != bi) return ai - bi;
      return a.id.compareTo(b.id);
    });

  final occupied = <int>{};
  final placement = <String, Position>{};

  Position? firstFree() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!occupied.contains(r * cols + c)) return (row: r, col: c);
      }
    }
    return null;
  }

  for (final btn in order) {
    final want = desired[btn.id]!;
    Position chosen;
    if (_inGrid(want, rows, cols) && !occupied.contains(idx(want))) {
      chosen = want;
    } else if (_inGrid(btn.position, rows, cols) &&
        !occupied.contains(idx(btn.position))) {
      chosen = btn.position;
    } else {
      chosen = firstFree() ?? btn.position;
    }
    occupied.add(idx(chosen));
    placement[btn.id] = chosen;
  }

  final moved = [
    for (final b in board.buttons)
      placement[b.id] == b.position ? b : b.withPosition(placement[b.id]!),
  ];
  return board.copyWithButtons(moved);
}
