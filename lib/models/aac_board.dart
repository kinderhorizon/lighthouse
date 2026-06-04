/// An AAC communication board (e.g., the Home Core 48 default).
///
/// Loaded from the v1.3 JSON schema in `boards/`. See
/// `docs/adr/0003-cold-start-glow-and-onboarding.md` for cold-start semantics
/// and `docs/CONTEXT.md` for the locked product decisions.
library;

import 'aac_button.dart';

typedef GridDimensions = ({int rows, int cols});

/// Maximum rows or columns a board grid may declare. A defensive ceiling on
/// (untrusted) imported boards: real AAC grids are far smaller (the bundled
/// Core 48 home board is 7x8), and a huge grid would let a crafted pack OOM the
/// renderer. 64 leaves generous headroom.
const int kMaxGridSide = 64;

class AACBoard {
  AACBoard({
    required this.schemaVersion,
    required this.boardId,
    required this.boardName,
    required this.gridDimensions,
    required this.colorKey,
    required this.buttons,
    this.boardNameByLocale = const {},
  }) {
    _buttonsByPosition = {
      for (final b in buttons) b.position: b,
    };
  }

  final String schemaVersion;
  final String boardId;
  final String boardName;

  /// Localized board names keyed by ISO 639-1 code (e.g., "ar", "es"), from the
  /// `board_name_<code>` JSON fields. Use [boardNameFor] to resolve with
  /// fallback to the default [boardName].
  final Map<String, String> boardNameByLocale;

  final GridDimensions gridDimensions;

  /// Maps category name (e.g., "verb", "needs") to hex color string
  /// (e.g., "#C2FFC2"). Buttons resolve their color via this map.
  final Map<String, String> colorKey;

  final List<AACButton> buttons;

  late final Map<Position, AACButton> _buttonsByPosition;

  /// O(1) lookup. Returns null if the position is empty (sparse boards).
  AACButton? buttonAt(Position position) => _buttonsByPosition[position];

  /// A `board_id` must be a bare slug: it is used unescaped as a filename when
  /// an imported pack is persisted (`<importDir>/<board_id>.json`) and as part
  /// of a custom-image filename. Restricting it to this character class closes
  /// a path-traversal vector (e.g. `../../lighthouse_db`) from an untrusted
  /// imported board. Bundled board ids all satisfy this.
  static final RegExp _boardIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Whether [boardId] is a safe-to-use board identifier (see [_boardIdPattern]).
  static bool isValidBoardId(String boardId) =>
      _boardIdPattern.hasMatch(boardId);

  /// Resolves the board name for [languageCode], falling back to the default.
  String boardNameFor(String languageCode) =>
      boardNameByLocale[languageCode] ?? boardName;

  /// Returns a copy with [newButtons] replacing the button list; all other
  /// metadata is preserved. Used to overlay parent-authored custom buttons
  /// (ADR 0012) onto a bundled board without mutating the loaded asset.
  AACBoard copyWithButtons(List<AACButton> newButtons) => AACBoard(
        schemaVersion: schemaVersion,
        boardId: boardId,
        boardName: boardName,
        boardNameByLocale: boardNameByLocale,
        gridDimensions: gridDimensions,
        colorKey: colorKey,
        buttons: List.unmodifiable(newButtons),
      );

  /// Empty (unoccupied) grid slots in row-major order, up to [limit] if given.
  /// The custom-button editor offers these as the available placements.
  List<Position> emptySlots({int? limit}) {
    final out = <Position>[];
    for (var r = 0; r < gridDimensions.rows; r++) {
      for (var c = 0; c < gridDimensions.cols; c++) {
        if (_buttonsByPosition[(row: r, col: c)] == null) {
          out.add((row: r, col: c));
          if (limit != null && out.length >= limit) return out;
        }
      }
    }
    return out;
  }

  /// Exact inverse of [fromJson] (ADR 0015): re-parsing the output yields an
  /// equal board. Localized names are flattened back to `board_name_<code>`
  /// keys; buttons serialize via [AACButton.toJson].
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'schema_version': schemaVersion,
      'board_id': boardId,
      'board_name': boardName,
      'grid_dimensions': [gridDimensions.rows, gridDimensions.cols],
      'color_key': colorKey,
      'buttons': [for (final b in buttons) b.toJson()],
    };
    boardNameByLocale
        .forEach((code, value) => json['board_name_$code'] = value);
    return json;
  }

  factory AACBoard.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version'] as String? ?? '';
    final boardId = json['board_id'] as String?;
    if (boardId == null || boardId.isEmpty) {
      throw const FormatException('AACBoard: missing "board_id"');
    }
    if (!isValidBoardId(boardId)) {
      throw FormatException(
          'AACBoard: invalid "board_id" (must match ${_boardIdPattern.pattern}): '
          '$boardId');
    }
    final boardName = json['board_name'] as String? ?? boardId;
    final boardNameByLocale = <String, String>{};
    for (final entry in json.entries) {
      if (entry.key.startsWith('board_name_') && entry.value is String) {
        boardNameByLocale[entry.key.substring('board_name_'.length)] =
            entry.value as String;
      }
    }

    final dims = json['grid_dimensions'];
    if (dims is! List || dims.length != 2) {
      throw FormatException(
          'AACBoard "$boardId": "grid_dimensions" must be a [rows, cols] array');
    }
    final rows = dims[0];
    final cols = dims[1];
    if (rows is! int || cols is! int) {
      throw FormatException(
          'AACBoard "$boardId": "grid_dimensions" must be integers');
    }
    // Bound the grid so an untrusted imported board cannot request a giant or
    // degenerate grid that the renderer (aac_grid) would divide-by-zero or
    // allocate to death. Real boards are well within this (Core 48 is 7x8).
    if (rows < 1 || rows > kMaxGridSide || cols < 1 || cols > kMaxGridSide) {
      throw FormatException(
          'AACBoard "$boardId": "grid_dimensions" must be 1..$kMaxGridSide per '
          'side, got ${rows}x$cols');
    }

    final colorKeyRaw = json['color_key'];
    final colorKey = <String, String>{};
    if (colorKeyRaw is Map) {
      for (final entry in colorKeyRaw.entries) {
        if (entry.key is String && entry.value is String) {
          colorKey[entry.key as String] = entry.value as String;
        }
      }
    }

    final buttonsRaw = json['buttons'];
    if (buttonsRaw is! List) {
      throw FormatException('AACBoard "$boardId": "buttons" must be an array');
    }
    final buttons = <AACButton>[
      for (final b in buttonsRaw)
        if (b is Map<String, dynamic>) AACButton.fromJson(b),
    ];
    // Each button must sit inside the declared grid (its position is already
    // non-negative, enforced in AACButton.fromJson) and ids/positions must be
    // unique. Duplicates would otherwise be silently collapsed by the
    // position/id maps, hiding a malformed (or malicious) imported board.
    final seenIds = <String>{};
    final seenPositions = <Position>{};
    for (final b in buttons) {
      if (!seenIds.add(b.id)) {
        throw FormatException(
            'AACBoard "$boardId": duplicate button id "${b.id}"');
      }
      if (b.position.row >= rows || b.position.col >= cols) {
        throw FormatException(
            'AACBoard "$boardId": button "${b.id}" at row ${b.position.row}, '
            'col ${b.position.col} is outside the ${rows}x$cols grid');
      }
      if (!seenPositions.add(b.position)) {
        throw FormatException(
            'AACBoard "$boardId": two buttons share position row '
            '${b.position.row}, col ${b.position.col}');
      }
    }

    return AACBoard(
      schemaVersion: schemaVersion,
      boardId: boardId,
      boardName: boardName,
      boardNameByLocale: Map.unmodifiable(boardNameByLocale),
      gridDimensions: (rows: rows, cols: cols),
      colorKey: Map.unmodifiable(colorKey),
      buttons: List.unmodifiable(buttons),
    );
  }
}
