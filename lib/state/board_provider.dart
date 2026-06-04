/// Board provider.
///
/// Loads the default Home Core 48 board THROUGH the board registry, not the
/// asset bundle directly, so OTA content overlays (ADR 0017) apply to the home
/// board exactly as they do to sub-boards. Loading core_main via BoardLoader
/// here would silently bypass the overlay, leaving the most-used board the one
/// board OTA could never correct. Async result is the parsed (possibly
/// overlaid) [AACBoard]. Errors surface to the UI layer.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'board_stack.dart';

part 'board_provider.g.dart';

/// The home board id. Registered as a static asset source in the registry; an
/// OTA overlay for `boards/core_main.json` wins over the bundled asset.
const String kHomeBoardId = 'core_main';

@Riverpod(keepAlive: true)
Future<AACBoard> defaultBoard(DefaultBoardRef ref) async {
  final registry = await ref.watch(boardRegistryProvider.future);
  final board = await registry.tryLoad(kHomeBoardId);
  if (board == null) {
    // core_main is a static asset source, so this is unreachable in a healthy
    // build; surface it rather than substitute a board for a non-speaking child.
    throw StateError('home board "$kHomeBoardId" is not registered');
  }
  return board;
}
