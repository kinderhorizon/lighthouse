/// User settings persistence.
///
/// Small key-value preferences (TTS mode, glow style, hitbox magnitude,
/// locale override). Defaults match the clinical lead's locked input:
/// TTS=On, glow=pulse, hitbox=Subtle. See ADR 0003 § Settings and
/// ADR 0004 § Voice-output behavior.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../logic/logic.dart';
import '../../models/user_profile.dart' show AccessMethod;

// GlowStyle and HitboxMagnitude live in lib/logic/ (domain layer) and
// are re-exported below so existing imports of services keep working.
export '../../logic/bandit/glow_style.dart' show GlowStyle;
export '../../logic/hitbox/hitbox_expansion.dart' show HitboxMagnitude;
export '../../models/user_profile.dart' show AccessMethod;


enum TtsMode {
  on,
  onRequest,
  off,
  als;

  String toJson() => name;
  static TtsMode? tryParse(String? v) {
    for (final m in TtsMode.values) {
      if (m.name == v) return m;
    }
    return null;
  }
}

class SettingsState {
  const SettingsState({
    required this.ttsMode,
    required this.glowStyle,
    required this.hitboxMagnitude,
    required this.localeOverride,
    this.speechLocaleOverride,
    this.voiceRate = 1.0,
    this.voicePitch = 1.0,
    this.voiceVolume = 1.0,
    this.highContrast = false,
    this.enableAiPrediction = false,
    this.accessMethod = AccessMethod.directTouch,
    this.switchDwellMs = 1000,
    required this.autoReturnToHome,
    required this.hideTileText,
    required this.hidePictogram,
  });

  /// Clinically locked defaults (see ADR 0003 / ADR 0004 / ADR 0009).
  static const defaults = SettingsState(
    ttsMode: TtsMode.on,
    glowStyle: GlowStyle.halo,
    hitboxMagnitude: HitboxMagnitude.subtle,
    localeOverride: null,
    speechLocaleOverride: null,
    voiceRate: 1.0,
    voicePitch: 1.0,
    voiceVolume: 1.0,
    highContrast: false,
    enableAiPrediction: false,
    accessMethod: AccessMethod.directTouch,
    switchDwellMs: 1000,
    autoReturnToHome: true,
    hideTileText: false,
    hidePictogram: false,
  );



  final TtsMode ttsMode;
  final GlowStyle glowStyle;
  final HitboxMagnitude hitboxMagnitude;

  /// Interface language override (e.g. 'en', 'ar', 'ar_dz', 'de'). null means "follow system".
  final String? localeOverride;

  /// Speech-output language override independent of interface language.
  /// null means "match interface language".
  final String? speechLocaleOverride;

  /// Speech rate multiplier (0.5 to 2.0).
  final double voiceRate;

  /// Speech pitch multiplier (0.5 to 2.0).
  final double voicePitch;

  /// Speech output volume (0.0 to 1.0).
  final double voiceVolume;

  /// Accessibility high-contrast theme flag.
  final bool highContrast;

  /// Enable optional offline AI word prediction and sentence assistance strip.
  final bool enableAiPrediction;

  /// Accessibility access method (direct touch, single-switch auto scan, dual-switch step scan).
  final AccessMethod accessMethod;

  /// Switch scanning dwell time in milliseconds (500ms to 2000ms).
  final int switchDwellMs;

  /// After speaking a fringe word inside a sub-board, return to the home board
  /// automatically (WordPower-style; cuts navigation burden and avoids
  /// stranding a child in a folder). Clinician-configurable; default on.
  /// See ADR 0009.
  final bool autoReturnToHome;

  /// Hide the text label under each tile, leaving only the pictogram.
  final bool hideTileText;

  /// Hide the pictogram on each tile, leaving only the text label.
  final bool hidePictogram;

  SettingsState copyWith({
    TtsMode? ttsMode,
    GlowStyle? glowStyle,
    HitboxMagnitude? hitboxMagnitude,
    String? localeOverride,
    bool clearLocaleOverride = false,
    String? speechLocaleOverride,
    bool clearSpeechLocaleOverride = false,
    double? voiceRate,
    double? voicePitch,
    double? voiceVolume,
    bool? highContrast,
    bool? enableAiPrediction,
    AccessMethod? accessMethod,
    int? switchDwellMs,
    bool? autoReturnToHome,
    bool? hideTileText,
    bool? hidePictogram,
  }) {
    return SettingsState(
      ttsMode: ttsMode ?? this.ttsMode,
      glowStyle: glowStyle ?? this.glowStyle,
      hitboxMagnitude: hitboxMagnitude ?? this.hitboxMagnitude,
      localeOverride: clearLocaleOverride
          ? null
          : (localeOverride ?? this.localeOverride),
      speechLocaleOverride: clearSpeechLocaleOverride
          ? null
          : (speechLocaleOverride ?? this.speechLocaleOverride),
      voiceRate: voiceRate ?? this.voiceRate,
      voicePitch: voicePitch ?? this.voicePitch,
      voiceVolume: voiceVolume ?? this.voiceVolume,
      highContrast: highContrast ?? this.highContrast,
      enableAiPrediction: enableAiPrediction ?? this.enableAiPrediction,
      accessMethod: accessMethod ?? this.accessMethod,
      switchDwellMs: switchDwellMs ?? this.switchDwellMs,
      autoReturnToHome: autoReturnToHome ?? this.autoReturnToHome,
      hideTileText: hideTileText ?? this.hideTileText,
      hidePictogram: hidePictogram ?? this.hidePictogram,
    );
  }
}


class SettingsRepository {
  SettingsRepository({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const _keyTts = 'settings.tts_mode';
  static const _keyGlow = 'settings.glow_style';
  static const _keyHit = 'settings.hitbox_magnitude';
  static const _keyLocale = 'settings.locale_override';
  static const _keySpeechLocale = 'settings.speech_locale_override';
  static const _keyVoiceRate = 'settings.voice_rate';
  static const _keyVoicePitch = 'settings.voice_pitch';
  static const _keyVoiceVolume = 'settings.voice_volume';
  static const _keyHighContrast = 'settings.high_contrast';
  static const _keyEnableAiPrediction = 'settings.enable_ai_prediction';
  static const _keyAccessMethod = 'settings.access_method';
  static const _keySwitchDwellMs = 'settings.switch_dwell_ms';
  static const _keyAutoReturn = 'settings.auto_return_to_home';
  static const _keyHideTileText = 'settings.hide_tile_text';
  static const _keyHidePictogram = 'settings.hide_pictogram';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _cached;

  Future<SharedPreferences> _prefs() async {
    if (_cached != null) return _cached!;
    _cached = _prefsOverride ?? await SharedPreferences.getInstance();
    return _cached!;
  }

  Future<SettingsState> read() async {
    final p = await _prefs();
    return SettingsState(
      ttsMode: TtsMode.tryParse(p.getString(_keyTts)) ??
          SettingsState.defaults.ttsMode,
      glowStyle: GlowStyle.tryParse(p.getString(_keyGlow)) ??
          SettingsState.defaults.glowStyle,
      hitboxMagnitude: HitboxMagnitude.tryParse(p.getString(_keyHit)) ??
          SettingsState.defaults.hitboxMagnitude,
      localeOverride: p.getString(_keyLocale),
      speechLocaleOverride: p.getString(_keySpeechLocale),
      voiceRate: p.getDouble(_keyVoiceRate) ?? SettingsState.defaults.voiceRate,
      voicePitch:
          p.getDouble(_keyVoicePitch) ?? SettingsState.defaults.voicePitch,
      voiceVolume:
          p.getDouble(_keyVoiceVolume) ?? SettingsState.defaults.voiceVolume,
      highContrast:
          p.getBool(_keyHighContrast) ?? SettingsState.defaults.highContrast,
      enableAiPrediction: p.getBool(_keyEnableAiPrediction) ??
          SettingsState.defaults.enableAiPrediction,
      accessMethod: AccessMethod.tryParse(p.getString(_keyAccessMethod)),
      switchDwellMs: p.getInt(_keySwitchDwellMs) ??
          SettingsState.defaults.switchDwellMs,
      autoReturnToHome: p.getBool(_keyAutoReturn) ??
          SettingsState.defaults.autoReturnToHome,
      hideTileText: p.getBool(_keyHideTileText) ??
          SettingsState.defaults.hideTileText,
      hidePictogram: p.getBool(_keyHidePictogram) ??
          SettingsState.defaults.hidePictogram,
    );
  }

  Future<void> setAutoReturnToHome(bool value) async {
    final p = await _prefs();
    await p.setBool(_keyAutoReturn, value);
  }

  Future<void> setHideTileText(bool value) async {
    final p = await _prefs();
    await p.setBool(_keyHideTileText, value);
  }

  Future<void> setHidePictogram(bool value) async {
    final p = await _prefs();
    await p.setBool(_keyHidePictogram, value);
  }

  Future<void> setTtsMode(TtsMode mode) async {
    final p = await _prefs();
    await p.setString(_keyTts, mode.toJson());
  }

  Future<void> setGlowStyle(GlowStyle style) async {
    final p = await _prefs();
    await p.setString(_keyGlow, style.toJson());
  }

  Future<void> setHitboxMagnitude(HitboxMagnitude h) async {
    final p = await _prefs();
    await p.setString(_keyHit, h.toJson());
  }

  Future<void> setLocaleOverride(String? code) async {
    final p = await _prefs();
    if (code == null) {
      await p.remove(_keyLocale);
    } else {
      await p.setString(_keyLocale, code);
    }
  }

  Future<void> setSpeechLocaleOverride(String? code) async {
    final p = await _prefs();
    if (code == null) {
      await p.remove(_keySpeechLocale);
    } else {
      await p.setString(_keySpeechLocale, code);
    }
  }

  Future<void> setVoiceRate(double rate) async {
    final p = await _prefs();
    await p.setDouble(_keyVoiceRate, rate);
  }

  Future<void> setVoicePitch(double pitch) async {
    final p = await _prefs();
    await p.setDouble(_keyVoicePitch, pitch);
  }

  Future<void> setVoiceVolume(double volume) async {
    final p = await _prefs();
    await p.setDouble(_keyVoiceVolume, volume);
  }

  Future<void> setHighContrast(bool value) async {
    final p = await _prefs();
    await p.setBool(_keyHighContrast, value);
  }

  Future<void> setEnableAiPrediction(bool value) async {
    final p = await _prefs();
    await p.setBool(_keyEnableAiPrediction, value);
  }

  Future<void> setAccessMethod(AccessMethod method) async {
    final p = await _prefs();
    await p.setString(_keyAccessMethod, method.toJson());
  }

  Future<void> setSwitchDwellMs(int ms) async {
    final p = await _prefs();
    await p.setInt(_keySwitchDwellMs, ms);
  }
}

