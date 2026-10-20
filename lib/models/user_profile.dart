/// Domain model for multi-user / multi-child AAC profiles.
library;

import '../logic/bandit/glow_style.dart';
import '../logic/hitbox/hitbox_expansion.dart';
import '../services/settings/settings_repository.dart' show TtsMode;

enum AccessMethod {
  directTouch,
  switchSingle,
  switchDual;

  String toJson() => name;
  static AccessMethod tryParse(String? v) {
    for (final m in AccessMethod.values) {
      if (m.name == v) return m;
    }
    return directTouch;
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.avatarUri,
    this.interfaceLocale,
    this.speechLocale,
    this.voiceRate = 1.0,
    this.voicePitch = 1.0,
    this.voiceVolume = 1.0,
    this.ttsMode = TtsMode.on,
    this.accessMethod = AccessMethod.directTouch,
    this.dwellMs = 0,
    this.highContrast = false,
    this.gridColumns,
    this.gridRows,
    this.glowStyle = GlowStyle.halo,
    this.hitboxMagnitude = HitboxMagnitude.subtle,
    this.autoReturnToHome = true,
    this.hideTileText = false,
    this.hidePictogram = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? avatarUri;

  /// Interface language override ('en', 'ar', 'ar-DZ', 'de', null = follow system).
  final String? interfaceLocale;

  /// Independent speech output language override ('en', 'ar', 'ar-DZ', 'de', null = match interface).
  final String? speechLocale;

  final double voiceRate;
  final double voicePitch;
  final double voiceVolume;
  final TtsMode ttsMode;
  final AccessMethod accessMethod;
  final int dwellMs;
  final bool highContrast;
  final int? gridColumns;
  final int? gridRows;
  final GlowStyle glowStyle;
  final HitboxMagnitude hitboxMagnitude;
  final bool autoReturnToHome;
  final bool hideTileText;
  final bool hidePictogram;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? id,
    String? name,
    String? avatarUri,
    bool clearAvatarUri = false,
    String? interfaceLocale,
    bool clearInterfaceLocale = false,
    String? speechLocale,
    bool clearSpeechLocale = false,
    double? voiceRate,
    double? voicePitch,
    double? voiceVolume,
    TtsMode? ttsMode,
    AccessMethod? accessMethod,
    int? dwellMs,
    bool? highContrast,
    int? gridColumns,
    bool clearGridColumns = false,
    int? gridRows,
    bool clearGridRows = false,
    GlowStyle? glowStyle,
    HitboxMagnitude? hitboxMagnitude,
    bool? autoReturnToHome,
    bool? hideTileText,
    bool? hidePictogram,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUri: clearAvatarUri ? null : (avatarUri ?? this.avatarUri),
      interfaceLocale: clearInterfaceLocale
          ? null
          : (interfaceLocale ?? this.interfaceLocale),
      speechLocale:
          clearSpeechLocale ? null : (speechLocale ?? this.speechLocale),
      voiceRate: voiceRate ?? this.voiceRate,
      voicePitch: voicePitch ?? this.voicePitch,
      voiceVolume: voiceVolume ?? this.voiceVolume,
      ttsMode: ttsMode ?? this.ttsMode,
      accessMethod: accessMethod ?? this.accessMethod,
      dwellMs: dwellMs ?? this.dwellMs,
      highContrast: highContrast ?? this.highContrast,
      gridColumns:
          clearGridColumns ? null : (gridColumns ?? this.gridColumns),
      gridRows: clearGridRows ? null : (gridRows ?? this.gridRows),
      glowStyle: glowStyle ?? this.glowStyle,
      hitboxMagnitude: hitboxMagnitude ?? this.hitboxMagnitude,
      autoReturnToHome: autoReturnToHome ?? this.autoReturnToHome,
      hideTileText: hideTileText ?? this.hideTileText,
      hidePictogram: hidePictogram ?? this.hidePictogram,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (avatarUri != null) 'avatar_uri': avatarUri,
      if (interfaceLocale != null) 'interface_locale': interfaceLocale,
      if (speechLocale != null) 'speech_locale': speechLocale,
      'voice_rate': voiceRate,
      'voice_pitch': voicePitch,
      'voice_volume': voiceVolume,
      'tts_mode': ttsMode.toJson(),
      'access_method': accessMethod.toJson(),
      'dwell_ms': dwellMs,
      'high_contrast': highContrast,
      if (gridColumns != null) 'grid_columns': gridColumns,
      if (gridRows != null) 'grid_rows': gridRows,
      'glow_style': glowStyle.toJson(),
      'hitbox_magnitude': hitboxMagnitude.toJson(),
      'auto_return_to_home': autoReturnToHome,
      'hide_tile_text': hideTileText,
      'hide_pictogram': hidePictogram,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'User',
      avatarUri: json['avatar_uri']?.toString(),
      interfaceLocale: json['interface_locale']?.toString(),
      speechLocale: json['speech_locale']?.toString(),
      voiceRate: (json['voice_rate'] as num?)?.toDouble() ?? 1.0,
      voicePitch: (json['voice_pitch'] as num?)?.toDouble() ?? 1.0,
      voiceVolume: (json['voice_volume'] as num?)?.toDouble() ?? 1.0,
      ttsMode: TtsMode.tryParse(json['tts_mode']?.toString()) ?? TtsMode.on,
      accessMethod:
          AccessMethod.tryParse(json['access_method']?.toString()),
      dwellMs: (json['dwell_ms'] as num?)?.toInt() ?? 0,
      highContrast: json['high_contrast'] == true,
      gridColumns: (json['grid_columns'] as num?)?.toInt(),
      gridRows: (json['grid_rows'] as num?)?.toInt(),
      glowStyle: GlowStyle.tryParse(json['glow_style']?.toString()) ??
          GlowStyle.halo,
      hitboxMagnitude:
          HitboxMagnitude.tryParse(json['hitbox_magnitude']?.toString()) ??
              HitboxMagnitude.subtle,
      autoReturnToHome: json['auto_return_to_home'] != false,
      hideTileText: json['hide_tile_text'] == true,
      hidePictogram: json['hide_pictogram'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static UserProfile createDefault() {
    final now = DateTime.now();
    return UserProfile(
      id: 'default',
      name: 'Default User',
      createdAt: now,
      updatedAt: now,
    );
  }
}
