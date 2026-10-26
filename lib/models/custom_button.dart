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
import 'tile_color.dart';

/// Category tag for custom buttons (drives tile color fallback + lets the rest
/// of the app recognize parent-authored buttons).
const String kCustomCategory = 'custom';

/// True for a BUILT-IN folder (subcategory). Built-in folders are move-locked
/// (ADR 0014): never dragged, never replaced, and they always keep their own
/// slot, since a folder can be the only way into its page. A parent-made
/// category folder (ADR 0022) is not locked: it moves like a word.
bool isBuiltInFolder(AACButton b) =>
    b.type == AACButtonType.folder && b.category != kCustomCategory;

/// Grid of a parent-made category page (ADR 0022): the same 6 x 8 the bundled
/// sub-boards use, so it looks and sizes like them.
const GridDimensions kCategoryGrid = (rows: 6, cols: 8);

class CustomButton {
  const CustomButton({
    required this.id,
    required this.boardId,
    required this.row,
    required this.col,
    required this.label,
    required this.voiceOut,
    required this.imagePath,
    this.tileColor,
    this.replacesId,
    this.linkId,
  });

  /// Stable, slot-INDEPENDENT id, assigned once at creation (ADR 0014). Never
  /// re-derived from the slot, so a layout move keeps the button's identity and
  /// its learned bandit posteriors.
  final String id;

  final String boardId;

  /// Creation/default slot. The displayed position may differ if the parent
  /// moved the tile (that delta lives in the layout overlay, not here). A
  /// replacing button ([replacesId]) takes the replaced word's slot instead,
  /// and falls back to this one only if that word is gone.
  final int row;
  final int col;
  final String label;
  final String voiceOut;

  /// Absolute path to the copied image file, or empty for a text-only button.
  final String imagePath;

  /// The colour the parent chose for the tile (ADR 0022), or null for the
  /// default grey. Display only: the category stays [kCustomCategory].
  final TileColor? tileColor;

  /// The built-in word whose place this button takes (ADR 0022), typically on
  /// a full page. While this button exists that word is set aside (not shown,
  /// its learning kept); deleting this button brings it back, into the slot
  /// this button was in. Null for a button in an empty slot.
  final String? replacesId;

  /// When set, this is a CATEGORY folder that opens the parent-made page with
  /// this id (ADR 0022). Null for a word.
  final String? linkId;

  bool get isCategory => linkId != null;

  Position get position => (row: row, col: col);

  CustomButton _copy({String? imagePath, TileColor? tileColor, bool clearColor = false}) =>
      CustomButton(
        id: id,
        boardId: boardId,
        row: row,
        col: col,
        label: label,
        voiceOut: voiceOut,
        imagePath: imagePath ?? this.imagePath,
        tileColor: clearColor ? null : (tileColor ?? this.tileColor),
        replacesId: replacesId,
        linkId: linkId,
      );

  /// Returns a copy with [tileColor] replaced (null = back to grey); identity,
  /// slot, word, voice, image, replacement and link unchanged.
  CustomButton withTileColor(TileColor? tileColor) =>
      _copy(tileColor: tileColor, clearColor: tileColor == null);

  /// Returns a copy with [imagePath] replaced; everything else unchanged. Used
  /// by the store to switch between the stored (relative) and live (absolute)
  /// image path.
  CustomButton withImagePath(String imagePath) => _copy(imagePath: imagePath);

  /// The slot-derived id scheme used before ADR 0014. Retained only to migrate
  /// a legacy persisted entry that has no stored [id].
  static String legacyIdFor(String boardId, int row, int col) =>
      'custom_${boardId}_${row}_$col';

  /// Materializes this into an [AACButton] for overlay onto a board. A category
  /// becomes a folder that opens its page; a folder never speaks.
  AACButton toAacButton() => AACButton(
        id: id,
        label: label,
        labelByLocale: const {},
        type: isCategory ? AACButtonType.folder : AACButtonType.word,
        position: position,
        category: kCustomCategory,
        baseWeight: 0.5,
        iconUri: imagePath,
        voiceOut: isCategory ? null : voiceOut,
        voiceOutByLocale: const {},
        linkId: linkId,
        tileColor: tileColor,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'board_id': boardId,
        'row': row,
        'col': col,
        'label': label,
        'voice_out': voiceOut,
        'image_path': imagePath,
        if (tileColor != null) 'tile_color': tileColor!.hex,
        if (replacesId != null) 'replaces_id': replacesId,
        if (linkId != null) 'link_id': linkId,
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
    final replaces = json['replaces_id'];
    final link = json['link_id'];
    return CustomButton(
      id: id,
      boardId: boardId,
      row: row,
      col: col,
      label: label,
      voiceOut: json['voice_out'] as String? ?? label,
      imagePath: json['image_path'] as String? ?? '',
      tileColor: TileColor.fromHex(json['tile_color']),
      replacesId: replaces is String &&
              replaces.isNotEmpty &&
              replaces.length <= kMaxButtonTextLength
          ? replaces
          : null,
      // The page id is used as a board id, so it must be a safe slug; a
      // tampered value just leaves this a plain word.
      linkId: link is String && AACBoard.isValidBoardId(link) ? link : null,
    );
  }
}

/// The blank page a parent-made category folder opens (ADR 0022), named after
/// the folder. Its words are ordinary custom buttons on [CustomButton.linkId],
/// overlaid like any other board's.
AACBoard categoryBoardFor(CustomButton folder) => AACBoard(
      schemaVersion: '1.3',
      boardId: folder.linkId!,
      boardName: folder.label,
      gridDimensions: kCategoryGrid,
      colorKey: const {},
      buttons: const [],
    );

/// The parent-made category page with [boardId], or null when no category
/// folder in [customs] opens it.
AACBoard? categoryBoardById(String boardId, List<CustomButton> customs) {
  for (final c in customs) {
    if (c.linkId == boardId) return categoryBoardFor(c);
  }
  return null;
}

/// The colour a new button on [board] starts with (ADR 0022): the category's
/// own colour on a parent-made page, else the board's single group colour
/// (Food, People, ...), else null (grey; Home mixes colours).
TileColor? defaultTileColorFor(AACBoard board, List<CustomButton> customs) {
  for (final c in customs) {
    if (c.linkId == board.boardId) return c.tileColor;
  }
  return TileColor.soleColorOf(board.colorKey);
}

/// Everything that only exists because of the custom buttons [rootIds] (ADR
/// 0022): those buttons, and for each category among them its page, every
/// button on that page, and (recursively) any category nested inside. Used to
/// delete a category, or reset a board, without leaving orphans.
({Set<String> buttonIds, Set<String> boardIds}) customSubtree(
  Iterable<String> rootIds,
  List<CustomButton> customs,
) {
  final buttonIds = <String>{};
  final boardIds = <String>{};
  final byId = {for (final c in customs) c.id: c};
  final pending = [...rootIds];
  while (pending.isNotEmpty) {
    final c = byId[pending.removeLast()];
    if (c == null || !buttonIds.add(c.id)) continue;
    final page = c.linkId;
    if (page == null || !boardIds.add(page)) continue;
    for (final inner in customs) {
      if (inner.boardId == page) pending.add(inner.id);
    }
  }
  return (buttonIds: buttonIds, boardIds: boardIds);
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
///
/// The ONE deliberate exception is a replacement the parent chose (ADR 0022):
/// a button with [CustomButton.replacesId] sets that built-in word aside and
/// takes its slot. Only a built-in WORD can be set aside, never a folder or a
/// parent-made button; if the word is not on the board (a content update
/// removed it), the button is placed like any other.
AACBoard applyCustomButtons(AACBoard base, List<CustomButton> customs) {
  final mine = [
    for (final c in customs)
      if (c.boardId == base.boardId) c,
  ];
  if (mine.isEmpty) return base;

  final rows = base.gridDimensions.rows;
  final cols = base.gridDimensions.cols;
  final bySlot = <Position, AACButton>{
    for (final b in base.buttons) b.position: b,
  };

  // Replacements first, so a set-aside word's slot is never taken by an
  // ordinary custom button that happens to collide with it.
  final placed = <CustomButton>{};
  for (final c in mine) {
    final target = c.replacesId == null
        ? null
        : base.buttons.where((b) => b.id == c.replacesId).firstOrNull;
    if (target == null ||
        target.type == AACButtonType.folder ||
        bySlot[target.position]?.id != target.id) {
      continue;
    }
    bySlot[target.position] = c.toAacButton().withPosition(target.position);
    placed.add(c);
  }

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
    if (placed.contains(c)) continue;
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
