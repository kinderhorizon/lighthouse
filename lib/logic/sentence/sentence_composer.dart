/// Sentence composition (ADR 0010).
///
/// Turns the ordered list of tapped buttons in the utterance bar into the
/// single string the TTS engine replays. Pure and locale-aware so it can be
/// unit-tested in isolation and grown rule by rule without touching the
/// widget tree or the engine.
///
/// Scope for alpha is deliberately small: word-joining, first-word
/// capitalization, and the one grammar rule the clinical lead asked for
/// (English infinitive linking between two consecutive verbs, item #7).
/// Articles, agreement, and conjugation are out of scope.
library;

import '../../models/models.dart';

/// Category tag used for verbs in the board JSON `category` field. Two
/// consecutive verbs trigger the English "to" link (e.g., want + go ->
/// "want to go").
const String kVerbCategory = 'verb';

/// The ordered word forms to speak for [tokens] in [languageCode], including
/// any inserted grammar words (e.g. the English "to" link).
///
/// This is the form the sentence-bar replay hands to
/// `TTSEngine.speakSequence`: each entry is one spoken unit, so the bundled
/// engine can concatenate per-word clips (ADR 0010). Each token contributes
/// its localized `voiceOutFor(languageCode)` (the bare word for word buttons,
/// the full phrase for phrase buttons). Folder buttons never reach the
/// utterance bar, so they are ignored defensively here.
List<String> composeUtteranceTokens(
  List<AACButton> tokens,
  String languageCode,
) {
  final words = <String>[];

  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.type == AACButtonType.folder) continue;

    final word = token.voiceOutFor(languageCode)?.trim() ?? '';
    if (word.isEmpty) continue;

    // English infinitive link: a verb immediately following another verb
    // reads with "to" between them ("want to go"). Locale-gated because
    // Romance/Arabic infinitive linking carries no "to" (ADR 0010). A future
    // refinement is an infinitive-taking-verb allowlist (want/need/like/try)
    // rather than "any verb pair"; the current rule slightly over-applies
    // (e.g. "go to play") but is correct on the common catenatives.
    if (languageCode == 'en' &&
        words.isNotEmpty &&
        token.category == kVerbCategory &&
        i > 0 &&
        tokens[i - 1].category == kVerbCategory) {
      words.add('to');
    }

    words.add(word);
  }

  return words;
}

/// Composes the spoken sentence from [tokens] as a single capitalized string.
///
/// Retained for display/diagnostic use; the audio replay path uses
/// [composeUtteranceTokens] so the bundled engine can concatenate per-word
/// clips rather than synthesize the whole string.
String composeUtterance(List<AACButton> tokens, String languageCode) {
  final words = composeUtteranceTokens(tokens, languageCode);
  if (words.isEmpty) return '';
  return _capitalizeFirst(words.join(' '));
}

String _capitalizeFirst(String s) {
  if (s.isEmpty) return s;
  final first = s.substring(0, 1).toUpperCase();
  return '$first${s.substring(1)}';
}
