/// Open Board Format (OBF) Converter.
///
/// Implements import and export between Lighthouse AACBoard and the
/// open-board-0.1 specification for international interoperability.
library;

import '../../models/models.dart';

class OpenBoardFormat {
  const OpenBoardFormat();

  static const String formatIdentifier = 'open-board-0.1';

  /// Determines if a JSON map represents an Open Board Format board.
  static bool isOBF(Map<String, dynamic> json) {
    final format = json['format'];
    if (format is String && format.startsWith('open-board')) return true;
    if (json.containsKey('grid') && json.containsKey('buttons') && json.containsKey('name')) {
      final grid = json['grid'];
      if (grid is Map && grid.containsKey('rows') && grid.containsKey('columns')) {
        return true;
      }
    }
    return false;
  }

  /// Converts an Open Board Format JSON map to an [AACBoard].
  static AACBoard toAACBoard(Map<String, dynamic> json) {
    final rawId = json['id'] as String? ?? 'obf_board';
    final safeBoardId = rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
    final boardName = json['name'] as String? ?? 'Imported Board';

    final grid = json['grid'] as Map<String, dynamic>? ?? {};
    final rows = (grid['rows'] as num?)?.toInt() ?? 3;
    final cols = (grid['columns'] as num?)?.toInt() ?? 4;
    final order = grid['order'] as List<dynamic>?;

    final rawButtons = json['buttons'] as List<dynamic>? ?? [];
    final buttonsById = <String, Map<String, dynamic>>{};
    for (final item in rawButtons) {
      if (item is Map<String, dynamic> && item['id'] != null) {
        buttonsById[item['id'].toString()] = item;
      }
    }

    final outButtons = <AACButton>[];
    final colorKey = <String, String>{
      'general': '#E0E0E0',
      'needs': '#FFE0B2',
      'actions': '#C8E6C9',
      'things': '#FFF59D',
      'people': '#FFF9C4',
    };

    if (order != null && order.isNotEmpty) {
      for (var r = 0; r < order.length && r < rows; r++) {
        final rowList = order[r];
        if (rowList is List) {
          for (var c = 0; c < rowList.length && c < cols; c++) {
            final buttonId = rowList[c]?.toString();
            if (buttonId == null || !buttonsById.containsKey(buttonId)) continue;
            final bMap = buttonsById[buttonId]!;
            outButtons.add(_parseButton(bMap, row: r, col: c, boardId: safeBoardId));
          }
        }
      }
    } else {
      var idx = 0;
      for (final bMap in buttonsById.values) {
        if (idx >= rows * cols) break;
        final r = idx ~/ cols;
        final c = idx % cols;
        outButtons.add(_parseButton(bMap, row: r, col: c, boardId: safeBoardId));
        idx++;
      }
    }

    return AACBoard(
      schemaVersion: '1.3',
      boardId: safeBoardId,
      boardName: boardName,
      gridDimensions: (rows: rows, cols: cols),
      colorKey: colorKey,
      buttons: outButtons,
    );
  }

  static AACButton _parseButton(
    Map<String, dynamic> map, {
    required int row,
    required int col,
    required String boardId,
  }) {
    final rawId = map['id']?.toString() ?? 'btn_${row}_$col';
    final safeId = '${boardId}__${rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    final label = map['label'] as String? ?? '';
    final vocalization = map['vocalization'] as String? ?? label;

    final loadBoard = map['load_board'] as Map<String, dynamic>?;
    final isFolder = loadBoard != null;
    final linkId = isFolder ? loadBoard['id']?.toString() : null;

    final image = map['image_id'] ?? map['image_url'] ?? map['image_path'] ?? '';
    final iconUri = image.toString().startsWith('assets/') ? image.toString() : '';

    return AACButton(
      id: safeId,
      label: label,
      labelByLocale: {},
      type: isFolder ? AACButtonType.folder : AACButtonType.word,
      position: (row: row, col: col),
      category: isFolder ? 'folder' : 'general',
      baseWeight: 1.0,
      iconUri: iconUri,
      voiceOut: isFolder ? null : vocalization,
      voiceOutByLocale: {},
      linkId: linkId,
    );
  }

  /// Converts an [AACBoard] to an Open Board Format JSON map.
  static Map<String, dynamic> toOBF(AACBoard board) {
    final buttonsList = <Map<String, dynamic>>[];
    final order = List.generate(
      board.gridDimensions.rows,
      (_) => List<String?>.filled(board.gridDimensions.cols, null),
    );

    for (final btn in board.buttons) {
      if (btn.position.row < board.gridDimensions.rows &&
          btn.position.col < board.gridDimensions.cols) {
        order[btn.position.row][btn.position.col] = btn.id;
      }

      final btnMap = <String, dynamic>{
        'id': btn.id,
        'label': btn.label,
        if (btn.voiceOut != null) 'vocalization': btn.voiceOut,
        if (btn.iconUri.isNotEmpty) 'image_url': btn.iconUri,
        if (btn.type == AACButtonType.folder && btn.linkId != null)
          'load_board': {'id': btn.linkId},
      };
      buttonsList.add(btnMap);
    }

    return {
      'format': formatIdentifier,
      'id': board.boardId,
      'name': board.boardName,
      'grid': {
        'rows': board.gridDimensions.rows,
        'columns': board.gridDimensions.cols,
        'order': order,
      },
      'buttons': buttonsList,
    };
  }
}
