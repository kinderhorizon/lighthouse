/// Settings provider.
///
/// AsyncNotifier wrapping [SettingsRepository]. Reads once at startup;
/// mutations write through the repository, then update local state. See
/// ADR 0003 § Settings and ADR 0004 § Voice-output behavior.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(SettingsRepositoryRef ref) =>
    SettingsRepository();

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<SettingsState> build() {
    return ref.read(settingsRepositoryProvider).read();
  }

  SettingsState get _current =>
      state.valueOrNull ?? SettingsState.defaults;

  Future<void> setTtsMode(TtsMode mode) async {
    await ref.read(settingsRepositoryProvider).setTtsMode(mode);
    state = AsyncData(_current.copyWith(ttsMode: mode));
  }

  Future<void> setGlowStyle(GlowStyle style) async {
    await ref.read(settingsRepositoryProvider).setGlowStyle(style);
    state = AsyncData(_current.copyWith(glowStyle: style));
  }

  Future<void> setHitboxMagnitude(HitboxMagnitude h) async {
    await ref.read(settingsRepositoryProvider).setHitboxMagnitude(h);
    state = AsyncData(_current.copyWith(hitboxMagnitude: h));
  }

  Future<void> setLocaleOverride(String? code) async {
    await ref.read(settingsRepositoryProvider).setLocaleOverride(code);
    state = AsyncData(_current.copyWith(
      localeOverride: code,
      clearLocaleOverride: code == null,
    ));
  }

  Future<void> setAutoReturnToHome(bool value) async {
    await ref.read(settingsRepositoryProvider).setAutoReturnToHome(value);
    state = AsyncData(_current.copyWith(autoReturnToHome: value));
  }

  // Tile text and pictogram can never BOTH be hidden (a blank tile is unusable
  // for a non-speaking child). Both show by default; the parent may turn off
  // exactly one. Turning one off therefore forces the other back on, and the
  // forced-on write is persisted too so the invariant survives a restart.
  Future<void> setHideTileText(bool value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setHideTileText(value);
    if (value && _current.hidePictogram) {
      await repo.setHidePictogram(false);
      state = AsyncData(
          _current.copyWith(hideTileText: true, hidePictogram: false));
    } else {
      state = AsyncData(_current.copyWith(hideTileText: value));
    }
  }

  Future<void> setHidePictogram(bool value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setHidePictogram(value);
    if (value && _current.hideTileText) {
      await repo.setHideTileText(false);
      state = AsyncData(
          _current.copyWith(hidePictogram: true, hideTileText: false));
    } else {
      state = AsyncData(_current.copyWith(hidePictogram: value));
    }
  }
}
