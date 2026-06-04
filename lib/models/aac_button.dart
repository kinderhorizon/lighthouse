/// A single tappable cell on an AAC board.
///
/// Three kinds of buttons exist (see [AACButtonType]):
/// - [AACButtonType.word]: speaks a single word (e.g., "Want").
/// - [AACButtonType.phrase]: speaks a full phrase (e.g., "I need help").
/// - [AACButtonType.folder]: navigates to another board.
///
/// Localized labels and voice-out text are stored in [labelByLocale] /
/// [voiceOutByLocale], keyed by ISO 639-1 language codes (e.g., "ar", "es").
/// Use [labelFor] / [voiceOutFor] to resolve with fallback to the default.
library;

enum AACButtonType {
  word,
  phrase,
  folder;

  static AACButtonType fromJson(String value) {
    return switch (value) {
      'word' => AACButtonType.word,
      'phrase' => AACButtonType.phrase,
      'folder' => AACButtonType.folder,
      _ => throw FormatException('Unknown button type: "$value"'),
    };
  }

  /// Inverse of [fromJson]. The enum member names ('word'/'phrase'/'folder')
  /// are exactly the wire values, so [name] round-trips.
  String toJson() => name;
}

typedef Position = ({int row, int col});

/// Upper bound on free-text fields parsed from an (untrusted) imported board:
/// a label or voice-out string longer than this is rejected so a crafted pack
/// cannot bloat memory or the render. Generous for any real word/phrase.
const int kMaxButtonTextLength = 4096;

/// Upper bound on an icon URI string from an imported board.
const int kMaxIconUriLength = 1024;

/// Upper bound on a button's base weight. A base weight is a Bernoulli mean
/// (the cold-start bandit prior is `alpha = 2 * w`, `beta = 2 * (1 - w)`), so
/// the only meaningful range is [0, 1]; anything above is rejected at parse and
/// NaN/Infinity always are. This is parse hygiene: the load-bearing safety is
/// the clamp in `coldStartPrior` (lib/logic/bandit/cold_start_prior.dart),
/// which also handles the 0.0/1.0 endpoints this bound deliberately lets
/// through. (Was 1e6, the wrong ceiling: it admitted the entire (1, 1e6] band,
/// which produced a negative `beta` and a NaN draw that pinned the button to
/// the top of the suggestions.)
const double kMaxBaseWeight = 1.0;

class AACButton {
  const AACButton({
    required this.id,
    required this.label,
    required this.labelByLocale,
    required this.type,
    required this.position,
    required this.category,
    required this.baseWeight,
    required this.iconUri,
    this.voiceOut,
    this.voiceOutByLocale = const {},
    this.linkId,
  });

  final String id;
  final String label;
  final Map<String, String> labelByLocale;
  final AACButtonType type;
  final Position position;
  final String category;
  final double baseWeight;
  final String iconUri;

  /// Default voice-out text. Null for [AACButtonType.folder].
  final String? voiceOut;

  /// Localized voice-out by ISO 639-1 language code.
  final Map<String, String> voiceOutByLocale;

  /// Target board id for [AACButtonType.folder]. Null otherwise.
  final String? linkId;

  /// Returns the localized label for [languageCode], or [label] as fallback.
  String labelFor(String languageCode) =>
      labelByLocale[languageCode] ?? label;

  /// Returns the localized voice-out for [languageCode], or [voiceOut] if
  /// localized version absent, or null for folder buttons.
  String? voiceOutFor(String languageCode) =>
      voiceOutByLocale[languageCode] ?? voiceOut;

  /// Returns a copy with [iconUri] replaced; identity (id/category) and
  /// everything else unchanged. Used to repoint a button at an OTA-overlaid
  /// pictogram file (ADR 0017) without touching its identity, so bandit
  /// learning and glow are unaffected.
  AACButton withIconUri(String iconUri) => AACButton(
        id: id,
        label: label,
        labelByLocale: labelByLocale,
        type: type,
        position: position,
        category: category,
        baseWeight: baseWeight,
        iconUri: iconUri,
        voiceOut: voiceOut,
        voiceOutByLocale: voiceOutByLocale,
        linkId: linkId,
      );

  /// Returns a copy at [position], everything else unchanged. Used by the
  /// layout overlay (ADR 0014) to reposition a button without touching its
  /// identity (id/category), so bandit learning and glow are unaffected.
  AACButton withPosition(Position position) => AACButton(
        id: id,
        label: label,
        labelByLocale: labelByLocale,
        type: type,
        position: position,
        category: category,
        baseWeight: baseWeight,
        iconUri: iconUri,
        voiceOut: voiceOut,
        voiceOutByLocale: voiceOutByLocale,
        linkId: linkId,
      );

  /// Exact inverse of [fromJson] (ADR 0015): re-parsing the output yields an
  /// equal button. Localized maps are flattened back to `label_<code>` /
  /// `voice_out_<code>` keys; `voice_out` and `link_id` are omitted when null
  /// so they parse back to null rather than the empty string.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'label': label,
      'type': type.toJson(),
      'position': {'row': position.row, 'col': position.col},
      'category': category,
      'base_weight': baseWeight,
      'icon_uri': iconUri,
    };
    if (voiceOut != null) json['voice_out'] = voiceOut;
    if (linkId != null) json['link_id'] = linkId;
    labelByLocale.forEach((code, value) => json['label_$code'] = value);
    voiceOutByLocale.forEach((code, value) => json['voice_out_$code'] = value);
    return json;
  }

  factory AACButton.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('AACButton: missing "id"');
    }

    if (id.length > kMaxButtonTextLength) {
      throw FormatException('AACButton "$id": "id" exceeds length cap');
    }

    final label = json['label'] as String?;
    if (label == null) {
      throw FormatException('AACButton "$id": missing "label"');
    }
    if (label.length > kMaxButtonTextLength) {
      throw FormatException('AACButton "$id": "label" exceeds length cap');
    }

    final type = AACButtonType.fromJson(json['type'] as String? ?? '');

    final positionMap = json['position'] as Map<String, dynamic>?;
    if (positionMap == null) {
      throw FormatException('AACButton "$id": missing "position"');
    }
    final rowRaw = positionMap['row'];
    final colRaw = positionMap['col'];
    if (rowRaw is! int || colRaw is! int) {
      throw FormatException(
          'AACButton "$id": "position" must have integer "row" and "col"');
    }
    // Non-negative: a button is placed in a grid; the per-board parser also
    // bounds it ABOVE by the board's rows/cols. Negative indices would break
    // grid math (aac_grid) and motor-memory keying.
    if (rowRaw < 0 || colRaw < 0) {
      throw FormatException(
          'AACButton "$id": "position" row/col must be non-negative');
    }
    final row = rowRaw;
    final col = colRaw;

    final baseWeight = (json['base_weight'] as num?)?.toDouble() ?? 0.5;
    if (!baseWeight.isFinite || baseWeight < 0 || baseWeight > kMaxBaseWeight) {
      throw FormatException(
          'AACButton "$id": "base_weight" must be finite in [0, $kMaxBaseWeight]');
    }

    final iconUri = json['icon_uri'] as String? ?? '';
    if (!_isSafeIconUri(iconUri)) {
      throw FormatException('AACButton "$id": unsafe or oversized "icon_uri"');
    }

    // Every free-text string is individually length-capped (not just bounded by
    // the whole-file size limit): a single pathological field should be rejected
    // on its own. Applies to voice_out, category, link_id, and the per-locale
    // label_/voice_out_ values, mirroring the label/id caps above.
    final voiceOut = _capped(json['voice_out'], id, 'voice_out');
    final category = _capped(json['category'], id, 'category') ?? 'unknown';
    final linkId = _capped(json['link_id'], id, 'link_id');

    final labelByLocale = <String, String>{};
    final voiceOutByLocale = <String, String>{};
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is! String) continue;
      if (value.length > kMaxButtonTextLength) {
        throw FormatException('AACButton "$id": "$key" exceeds length cap');
      }
      if (key.startsWith('label_')) {
        labelByLocale[key.substring('label_'.length)] = value;
      } else if (key.startsWith('voice_out_')) {
        voiceOutByLocale[key.substring('voice_out_'.length)] = value;
      }
    }

    return AACButton(
      id: id,
      label: label,
      labelByLocale: Map.unmodifiable(labelByLocale),
      type: type,
      position: (row: row, col: col),
      category: category,
      baseWeight: baseWeight,
      iconUri: iconUri,
      voiceOut: voiceOut,
      voiceOutByLocale: Map.unmodifiable(voiceOutByLocale),
      linkId: linkId,
    );
  }

  /// Reads an optional string field, rejecting it if it exceeds the text cap.
  /// Returns null when the field is absent or not a string.
  static String? _capped(Object? value, String id, String field) {
    if (value is! String) return null;
    if (value.length > kMaxButtonTextLength) {
      throw FormatException('AACButton "$id": "$field" exceeds length cap');
    }
    return value;
  }

  /// An icon URI is safe to keep from an untrusted board if it is bounded, has
  /// no control characters or backslashes, and contains no `..` path segment
  /// (traversal). Empty is fine (no icon). Absolute and `assets/` paths are
  /// allowed: bundled boards and app-generated overlays legitimately use them,
  /// and the renderer only ever reads it as an image.
  static bool _isSafeIconUri(String uri) {
    if (uri.isEmpty) return true;
    if (uri.length > kMaxIconUriLength) return false;
    if (uri.contains('\\')) return false;
    for (final r in uri.runes) {
      if (r < 0x20 || r == 0x7f) return false; // control chars
    }
    for (final seg in uri.split('/')) {
      if (seg == '..') return false;
    }
    return true;
  }
}
