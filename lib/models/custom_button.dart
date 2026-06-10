/// A parent-authored custom button (ADR 0012, identity amended by ADR 0014).
///
/// Persisted separately from the read-only bundled boards and overlaid at read
/// time by [applyCustomButtons]. Stores the board, a STABLE slot-independent
/// [id], its creation/default slot ([row]/[col]), the word, and an image path
/// (a photo the parent picked, copied into the app support directory). The
/// in-memory [imagePath] is ALWAYS absolute so the tile can render it; on disk
/// it is persisted RELATIVE (bare filename) and re-resolved on load, so it
/// survives a device restore where the container UUID changes (see
/// CustomButtonStore). Speech uses system TTS, since arbitrary words have no
/// pre-rendered neural clip.
///
/// ADR 0014, Decision 9: the [id] no longer encodes the slot. It is assigned
/// once at creation from a persisted per-board high-water-mark counter and never
/// changes, so the layout overlay can move the button freely without colliding
/// ids or orphaning its bandit posteriors. [row]/[col] stay the creation slot
/// and are NOT rewritten by a move (the layout overlay is the sole source of
/// position deltas); a legacy entry persisted before this change has no stored
/// id and keeps its old slot-derived id once, on load.
library;

import 'aac_board.dart';
import 'aac_button.dart';

/// Category tag for custom buttons (drives tile color fallback + lets the rest
/// of the app recognize parent-authored buttons).
const String kCustomCategory = 'custom';

class CustomButton {
  const CustomButton({
    required this.id,
    required this.boardId,
    required this.row,
    required this.col,
    required this.label,
    required this.voiceOut,
    required this.imagePath,
  });

  /// Stable, slot-INDEPENDENT id, assigned once at creation (ADR 0014). Never
  /// re-derived from the slot, so a layout move keeps the button's identity and
  /// its learned bandit posteriors.
  final String id;

  final String boardId;

  /// Creation/default slot. The displayed position may differ if the parent
  /// moved the tile (that delta lives in the layout overlay, not here).
  final int row;
  final int col;
  final String label;
  final String voiceOut;

  /// Absolute path to the copied image file, or empty for a text-only button.
  final String imagePath;

  Position get position => (row: row, col: col);

  /// The slot-derived id scheme used before ADR 0014. Retained only to migrate
  /// a legacy persisted entry that has no stored [id].
  static String legacyIdFor(String boardId, int row, int col) =>
      'custom_${boardId}_${row}_$col';

  /// Materializes this into an [AACButton] for overlay onto a board.
  AACButton toAacButton() => AACButton(
        id: id,
        label: label,
        labelByLocale: const {},
        type: AACButtonType.word,
        position: position,
        category: kCustomCategory,
        baseWeight: 0.5,
        iconUri: imagePath,
        voiceOut: voiceOut,
        voiceOutByLocale: const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'board_id': boardId,
        'row': row,
        'col': col,
        'label': label,
        'voice_out': voiceOut,
        'image_path': imagePath,
      };

  factory CustomButton.fromJson(Map<String, dynamic> json) {
    final boardId = json['board_id'] as String?;
    final row = json['row'];
    final col = json['col'];
    if (boardId == null || boardId.isEmpty || row is! int || col is! int) {
      throw const FormatException('CustomButton: missing board_id/row/col');
    }
    final label = json['label'] as String? ?? '';
    // ADR 0014 migration: a legacy entry has no stored id, so derive the old
    // slot-derived one once. It is then persisted on the next save and never
    // changes, preserving any bandit posteriors keyed on it.
    final storedId = json['id'] as String?;
    final id = (storedId == null || storedId.isEmpty)
        ? legacyIdFor(boardId, row, col)
        : storedId;
    return CustomButton(
      id: id,
      boardId: boardId,
      row: row,
      col: col,
      label: label,
      voiceOut: json['voice_out'] as String? ?? label,
      imagePath: json['image_path'] as String? ?? '',
    );
  }
}

/// Overlays [customs] belonging to [base] onto it, returning a new board.
/// Pure: no IO. A custom button takes its slot WHEN THAT SLOT IS FREE; on a
/// collision with ANY live button (word, folder, or another custom) it NEVER
/// evicts the occupant: it is relocated to the first free slot instead, and
/// dropped only if the board is completely full.
///
/// This is the hard "Augment, Don't Rearrange" safety net (P0-1). Slots are
/// minted by the editor from the LAYOUT-COMPOSED board, but this merge runs on
/// the BASE board (before applyLayout), so once the parent has rearranged a
/// board a display-empty slot can be base-occupied. Evicting the occupant there
/// silently destroyed a word the child relies on, dropped its favourites pin,
/// and orphaned its bandit posteriors. addButton now resolves creation slots in
/// base coordinates so a collision is not expected in normal flow, but this
/// guarantees that even a legacy entry or OTA layout skew (ADR 0017) can never
/// delete a live button: a folder (the only path into a sub-board) and every
/// existing word are preserved, and the new custom button still appears.
AACBoard applyCustomButtons(AACBoard base, List<CustomButton> customs) {
  final mine = customs.where((c) => c.boardId == base.boardId).toList();
  if (mine.isEmpty) return base;

  final rows = base.gridDimensions.rows;
  final cols = base.gridDimensions.cols;
  final bySlot = <Position, AACButton>{
    for (final b in base.buttons) b.position: b,
  };

  Position? firstFreeSlot() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = (row: r, col: c);
        if (!bySlot.containsKey(p)) return p;
      }
    }
    return null;
  }

  for (final c in mine) {
    final button = c.toAacButton();
    if (!bySlot.containsKey(c.position)) {
      bySlot[c.position] = button; // normal path: the stored slot is free
    } else {
      // Occupied: never evict the live occupant. Place this custom button at the
      // first free slot; if the board is full, drop the NEW button rather than
      // displace an existing one.
      final free = firstFreeSlot();
      if (free != null) bySlot[free] = button.withPosition(free);
    }
  }
  return base.copyWithButtons(bySlot.values.toList(growable: false));
}
