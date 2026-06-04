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
/// Pure: no IO. A custom button takes its slot; on a collision with an existing
/// WORD the custom one wins (the editor only offers empty slots, so this is
/// robustness, not normal flow). A collision with a FOLDER preserves the folder:
/// under ADR 0017 OTA layout skew a bundled folder can shift onto a custom's
/// target slot, and a folder is the only path into a sub-board, so a custom word
/// must never silently evict it (applyLayout's folder-protection runs later and
/// cannot recover a folder no longer in board.buttons). Review M6.
AACBoard applyCustomButtons(AACBoard base, List<CustomButton> customs) {
  final mine = customs.where((c) => c.boardId == base.boardId).toList();
  if (mine.isEmpty) return base;

  final bySlot = <Position, AACButton>{
    for (final b in base.buttons) b.position: b,
  };
  for (final c in mine) {
    if (bySlot[c.position]?.type == AACButtonType.folder) continue;
    bySlot[c.position] = c.toAacButton();
  }
  return base.copyWithButtons(bySlot.values.toList(growable: false));
}
