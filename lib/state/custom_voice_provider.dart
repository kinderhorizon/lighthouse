/// Custom-voice providers (ADR 0019).
///
/// Exposes the persisted `buttonId -> clip path` map, the store that mutates it,
/// and the player used both at speak time (in place of TTS) and for the editor's
/// preview. Manual Riverpod API (like [boardLayoutProvider]) so adding it needs
/// no build_runner pass that would churn the generated bandit/Isar files.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';

final customVoiceStoreProvider = Provider<CustomVoiceStore>(
  (ref) => CustomVoiceStore(),
);

/// One shared player for custom-voice playback. Disposed with the provider.
final customVoicePlayerProvider = Provider<CustomVoicePlayer>((ref) {
  final player = CustomVoicePlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// `buttonId -> absolute clip path` for tiles with a parent-recorded voice.
/// Read synchronously at tap time (via `valueOrNull`) so the speak path can
/// prefer a custom clip over TTS without an await on the hot tap.
final customVoiceProvider =
    AsyncNotifierProvider<CustomVoiceNotifier, Map<String, String>>(
  CustomVoiceNotifier.new,
);

class CustomVoiceNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() =>
      ref.read(customVoiceStoreProvider).load();

  /// Saves the freshly recorded [clip] for [buttonId] (replacing any prior).
  Future<void> save(String buttonId, File clip) async {
    await future; // ensure the initial load resolved
    final next =
        await ref.read(customVoiceStoreProvider).importClip(clip, buttonId: buttonId);
    state = AsyncData(next);
  }

  /// Deletes the custom voice for [buttonId], restoring the built-in voice.
  Future<void> remove(String buttonId) async {
    await future;
    final next = await ref.read(customVoiceStoreProvider).remove(buttonId);
    state = AsyncData(next);
  }

  /// Deletes the custom voice for each of [buttonIds] ("reset this board": the
  /// ids currently on the board being reset).
  Future<void> removeMany(Iterable<String> buttonIds) async {
    await future;
    final next =
        await ref.read(customVoiceStoreProvider).removeMany(buttonIds);
    state = AsyncData(next);
  }

  /// Deletes every custom voice across all tiles ("reset everything").
  Future<void> resetAll() async {
    await future;
    final next = await ref.read(customVoiceStoreProvider).clearAll();
    state = AsyncData(next);
  }

  /// Absolute clip path for [buttonId], or null if it has no custom voice.
  String? pathFor(String buttonId) => state.valueOrNull?[buttonId];
}
