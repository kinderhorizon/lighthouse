/// Offline AI Next-Word Predictor for AAC.
///
/// Computes likely next communication words based on active context, preceding
/// selection, and communicative intent transition models.
library;

import '../../models/models.dart';

class AIWordPredictor {
  const AIWordPredictor();

  /// Curated contextual transition matrix for essential AAC communication.
  static const Map<String, List<String>> _transitions = {
    'btn_i': [
      'btn_want',
      'btn_need',
      'btn_like',
      'btn_hungry',
      'btn_tired',
      'btn_happy',
      'btn_water',
      'btn_help',
    ],
    'btn_want': [
      'btn_water',
      'btn_eat',
      'btn_drink',
      'btn_go',
      'btn_home',
      'btn_play',
      'btn_bathroom',
      'btn_more',
    ],
    'btn_need': [
      'btn_help',
      'btn_bathroom',
      'btn_water',
      'btn_break',
      'btn_mom',
      'btn_dad',
    ],
    'btn_go': [
      'btn_home',
      'btn_outside',
      'btn_school',
      'btn_bathroom',
    ],
    'btn_eat': [
      'btn_water',
      'btn_food_folder',
      'btn_more',
      'btn_all_done',
    ],
    'btn_drink': [
      'btn_water',
      'btn_more',
      'btn_all_done',
    ],
    'btn_help': [
      'btn_please',
      'btn_thankyou',
    ],
  };

  /// Predicts the top candidate buttons to follow [precedingTokens] on [board].
  List<AACButton> predictNextWords({
    required List<AACButton> precedingTokens,
    required AACBoard board,
    int limit = 4,
  }) {
    if (board.buttons.isEmpty) return const [];

    final buttonMap = {for (final b in board.buttons) b.id: b};
    final candidates = <AACButton>[];

    if (precedingTokens.isNotEmpty) {
      final lastToken = precedingTokens.last;
      final transitionList = _transitions[lastToken.id] ?? const [];

      for (final id in transitionList) {
        final btn = buttonMap[id];
        if (btn != null && btn.type != AACButtonType.folder && !candidates.contains(btn)) {
          candidates.add(btn);
          if (candidates.length >= limit) return candidates;
        }
      }
    }

    // Default: Sort by baseWeight for highest clinical utility starter words
    final sorted = List<AACButton>.from(
      board.buttons.where((b) => b.type != AACButtonType.folder),
    )..sort((a, b) => b.baseWeight.compareTo(a.baseWeight));

    for (final btn in sorted) {
      if (!candidates.contains(btn)) {
        candidates.add(btn);
        if (candidates.length >= limit) break;
      }
    }

    return candidates;
  }
}
