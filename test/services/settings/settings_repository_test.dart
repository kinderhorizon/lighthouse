import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('initial read returns clinically locked defaults', () async {
    final state = await SettingsRepository().read();
    expect(state.ttsMode, TtsMode.on);
    expect(state.glowStyle, GlowStyle.halo);
    expect(state.hitboxMagnitude, HitboxMagnitude.subtle);
    expect(state.localeOverride, isNull);
    // Both tile-content toggles default ON (nothing hidden).
    expect(state.hideTileText, isFalse);
    expect(state.hidePictogram, isFalse);
  });

  test('hideTileText / hidePictogram round-trip independently', () async {
    final w = SettingsRepository();
    await w.setHideTileText(true);
    await w.setHidePictogram(false);
    final r = await SettingsRepository().read();
    expect(r.hideTileText, isTrue);
    expect(r.hidePictogram, isFalse);
  });

  test('setters round-trip via a fresh repository instance', () async {
    final w = SettingsRepository();
    await w.setTtsMode(TtsMode.als);
    await w.setGlowStyle(GlowStyle.halo);
    await w.setHitboxMagnitude(HitboxMagnitude.maximum);
    await w.setLocaleOverride('ar');

    final r = await SettingsRepository().read();
    expect(r.ttsMode, TtsMode.als);
    expect(r.glowStyle, GlowStyle.halo);
    expect(r.hitboxMagnitude, HitboxMagnitude.maximum);
    expect(r.localeOverride, 'ar');
  });

  test('setLocaleOverride(null) clears the stored locale', () async {
    final w = SettingsRepository();
    await w.setLocaleOverride('es');
    await w.setLocaleOverride(null);
    final r = await SettingsRepository().read();
    expect(r.localeOverride, isNull);
  });

  test('enum tryParse returns null for unknown strings', () {
    expect(TtsMode.tryParse('shout'), isNull);
    expect(GlowStyle.tryParse(''), isNull);
    expect(HitboxMagnitude.tryParse(null), isNull);
  });

  test('reading unknown stored values falls back to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.tts_mode': 'shout',
      'settings.glow_style': 'rainbow',
      'settings.hitbox_magnitude': 'bigly',
    });
    final state = await SettingsRepository().read();
    expect(state.ttsMode, SettingsState.defaults.ttsMode);
    expect(state.glowStyle, SettingsState.defaults.glowStyle);
    expect(state.hitboxMagnitude, SettingsState.defaults.hitboxMagnitude);
  });
}
