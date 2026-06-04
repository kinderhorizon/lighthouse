/// Guided onboarding tour (ADR 0020): state + the seven-step list.
///
/// A parent-facing coach-mark tour that spotlights real controls on the board
/// and explains the rest of the app. It is NEVER shown on the child surface: it
/// runs only when the parent starts it (the end-of-first-run offer, or the
/// Settings "Take the tour" row). No gamification, streaks, or completion bar.
///
/// Every step is on the Home board, pointing at a real widget via the
/// [tourBoardKey], [tourSentenceKey], [tourArrangeKey], or [tourSettingsKey]
/// GlobalKeys (attached in `_BoardScreen` / `_BoardView`). The tour must never
/// highlight or describe a control that is not on the current screen; anything
/// deeper is taught by contextual first-use tips, not the tour.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

/// Which on-board widget a step spotlights (or [none] for a centred card).
/// [arrange] is the "Arrange board" app-bar button; [settings] is the gear.
enum TourTarget { board, sentence, arrange, settings, none }

class TourStep {
  const TourStep(this.target, this.titleOf, this.bodyOf);

  final TourTarget target;
  final String Function(AppLocalizations) titleOf;
  final String Function(AppLocalizations) bodyOf;
}

/// The seven steps, in order, ALL on the Home board. After the board, sentence,
/// glow, colours, and folders, the two app-bar buttons get their OWN steps:
/// "Arrange board" (manage tiles, behind the child-lock) and the gear (Settings)
/// are distinct controls, so each is spotlighted and described separately
/// (clinical review: the old step 5 wrongly said the gear is where you manage the
/// board and that it is behind the check; both belong to the Arrange button).
final List<TourStep> kTourSteps = [
  TourStep(TourTarget.board, (l) => l.tourBoardTitle, (l) => l.tourBoardBody),
  TourStep(TourTarget.sentence, (l) => l.tourSentenceTitle,
      (l) => l.tourSentenceBody),
  TourStep(TourTarget.board, (l) => l.tourGlowTitle, (l) => l.tourGlowBody),
  TourStep(TourTarget.board, (l) => l.tourColorsTitle, (l) => l.tourColorsBody),
  TourStep(
      TourTarget.board, (l) => l.tourFoldersTitle, (l) => l.tourFoldersBody),
  TourStep(TourTarget.arrange, (l) => l.tourArrangeTitle,
      (l) => l.tourArrangeBody),
  TourStep(TourTarget.settings, (l) => l.tourSettingsTitle,
      (l) => l.tourSettingsBody),
];

/// GlobalKeys for the board-resident spotlight targets. Top-level so the board
/// widgets and the overlay reference the SAME instances.
final GlobalKey tourBoardKey = GlobalKey(debugLabel: 'tourBoard');
final GlobalKey tourSentenceKey = GlobalKey(debugLabel: 'tourSentence');
final GlobalKey tourArrangeKey = GlobalKey(debugLabel: 'tourArrange');
final GlobalKey tourSettingsKey = GlobalKey(debugLabel: 'tourSettings');

class TourState {
  const TourState({this.active = false, this.index = 0});

  final bool active;
  final int index;

  TourStep get step => kTourSteps[index];
  bool get isFirst => index == 0;
  bool get isLast => index == kTourSteps.length - 1;

  TourState copyWith({bool? active, int? index}) =>
      TourState(active: active ?? this.active, index: index ?? this.index);
}

class TourController extends StateNotifier<TourState> {
  TourController() : super(const TourState());

  int get stepCount => kTourSteps.length;

  void start() => state = const TourState(active: true, index: 0);

  void stop() => state = const TourState(active: false, index: 0);

  void next() {
    if (state.isLast) {
      stop();
    } else {
      state = state.copyWith(index: state.index + 1);
    }
  }

  void back() {
    if (!state.isFirst) state = state.copyWith(index: state.index - 1);
  }
}

final tourControllerProvider =
    StateNotifierProvider<TourController, TourState>((ref) => TourController());

/// Set true by the end-of-first-run "Take the quick tour" button; the board
/// reads it once on mount, starts the tour, and clears it.
final tourPendingStartProvider = StateProvider<bool>((ref) => false);
