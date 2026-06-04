/// User settings persistence.
///
/// Small key-value preferences (TTS mode, glow style, hitbox magnitude,
/// locale override). Defaults match the clinical lead's locked input:
/// TTS=On, glow=pulse, hitbox=Subtle. See ADR 0003 § Settings and
/// ADR 0004 § Voice-output behavior.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../logic/logic.dart';

// GlowStyle and HitboxMagnitude live in lib/logic/ (domain layer) and
// are re-exported below so existing imports of services keep working.
export '../../logic/bandit/glow_style.dart' show GlowStyle;
export '../../logic/hitbox/hitbox_expansion.dart' show HitboxMagnitude;

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
    autoReturnToHome: true,
    hideTileText: false,
    hidePictogram: false,
  );

  final TtsMode ttsMode;
  final GlowStyle glowStyle;
  final HitboxMagnitude hitboxMagnitude;

  /// Two-letter ISO 639-1 code (en, ar, es). null means "follow system".
  final String? localeOverride;

  /// After speaking a fringe word inside a sub-board, return to the home board
  /// automatically (WordPower-style; cuts navigation burden and avoids
  /// stranding a child in a folder). Clinician-configurable; default on.
  /// See ADR 0009.
  final bool autoReturnToHome;

  /// Hide the text label under each tile, leaving only the pictogram. Default
  /// off (text shows). Clinician-configurable: a symbol-only grid suits
  /// pre-literate children or reduces reliance on text for some learners.
  final bool hideTileText;

  /// Hide the pictogram on each tile, leaving only the text label. Default off
  /// (pictogram shows). The complement of [hideTileText]: a text-only grid
  /// suits literate AAC users. INVARIANT: [hideTileText] and [hidePictogram]
  /// are never both true (a blank tile is unusable); the settings notifier
  /// enforces this by forcing the other back on. See
  /// [[project-lighthouse-board-engine]].
  final bool hidePictogram;

  SettingsState copyWith({
    TtsMode? ttsMode,
    GlowStyle? glowStyle,
    HitboxMagnitude? hitboxMagnitude,
    String? localeOverride,
    bool clearLocaleOverride = false,
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
}
