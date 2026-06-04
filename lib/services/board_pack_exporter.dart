/// Board pack exporter (ADR 0015): turns the board a parent is viewing into a
/// shareable JSON pack for offline device-to-device vocabulary sharing.
///
/// Two deliberate transforms before sharing:
///   - Folder buttons are dropped. Their target sub-boards do not travel in a
///     single-board v1 pack, so a kept folder would be a dead link.
///   - Custom photo buttons are degraded to text-only (the device `image_path`
///     is cleared). The child's photos never leave the tablet; the word, which
///     is the communicative core, is preserved. Pictogram/text buttons (whose
///     icon is a bundled asset reference) transfer unchanged.
///
/// The board id and button ids are exported as-is; the recipient's importer
/// re-ids and namespaces on import (see [BoardPackImporter.import] with
/// `assignFreshId`), so collisions are resolved on the receiving side.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Result of preparing an export: the file to share plus what was degraded, so
/// the UI can show an honest notice before the share sheet opens.
class BoardPackExport {
  const BoardPackExport({
    required this.file,
    required this.photosAsTextOnly,
    required this.foldersDropped,
  });

  final File file;

  /// Count of custom photo buttons shared as their word only (photo dropped).
  final int photosAsTextOnly;

  /// Count of folder buttons omitted (their sub-boards do not travel in v1).
  final int foldersDropped;
}

class BoardPackExporter {
  BoardPackExporter({Directory? tempDirOverride})
      : _tempOverride = tempDirOverride;

  final Directory? _tempOverride;

  /// Pure transform: the board that will actually be shared, plus the
  /// degradation counts. No IO.
  static ({AACBoard board, int photosAsTextOnly, int foldersDropped})
      buildExportBoard(AACBoard merged) {
    var photos = 0;
    var folders = 0;
    final kept = <AACButton>[];
    for (final b in merged.buttons) {
      if (b.type == AACButtonType.folder) {
        folders++;
        continue;
      }
      // Share an icon reference ONLY if it points at a bundled asset. A custom
      // PHOTO carries a device path, and an OTA-overlaid pictogram carries an
      // absolute container path (e.g. /var/mobile/.../content_overlay/v/3/...);
      // either would embed an on-device path in a file handed to another family.
      // Blank every non-asset icon (symmetric with the importer, review L1); the
      // photo counter still tracks only genuine custom photos so the UI notice
      // stays honest.
      if (b.iconUri.isNotEmpty && !b.iconUri.startsWith('assets/')) {
        if (_isPhotoBacked(b)) photos++;
        kept.add(_stripPhoto(b));
      } else {
        kept.add(b);
      }
    }
    return (
      board: merged.copyWithButtons(kept),
      photosAsTextOnly: photos,
      foldersDropped: folders,
    );
  }

  /// Builds the export board and writes it to a temp `.json` for the OS share
  /// sheet. The caller MUST delete [BoardPackExport.file] after the share
  /// completes (ADR 0015: do not leave a child's vocabulary lingering in a
  /// readable cache).
  Future<BoardPackExport> prepare(AACBoard merged) async {
    final built = buildExportBoard(merged);
    final dir = _tempOverride ?? await getTemporaryDirectory();
    final safeId = AACBoard.isValidBoardId(built.board.boardId)
        ? built.board.boardId
        : 'board';
    final file = File('${dir.path}/lighthouse_vocab_$safeId.json');
    await file.writeAsString(jsonEncode(built.board.toJson()));
    return BoardPackExport(
      file: file,
      photosAsTextOnly: built.photosAsTextOnly,
      foldersDropped: built.foldersDropped,
    );
  }

  static bool _isPhotoBacked(AACButton b) =>
      b.category == kCustomCategory && b.iconUri.isNotEmpty;

  static AACButton _stripPhoto(AACButton b) => AACButton(
        id: b.id,
        label: b.label,
        labelByLocale: b.labelByLocale,
        type: b.type,
        position: b.position,
        category: b.category,
        baseWeight: b.baseWeight,
        iconUri: '',
        voiceOut: b.voiceOut,
        voiceOutByLocale: b.voiceOutByLocale,
        linkId: b.linkId,
      );
}
