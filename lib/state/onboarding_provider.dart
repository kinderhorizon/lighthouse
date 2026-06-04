/// Onboarding state provider.
///
/// Reads OnboardingRepository on first observe and exposes a typed
/// AsyncValue<OnboardingState>. Mutations (setHomeLabel, markComplete,
/// reset) write through the repository, then refresh local state.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';

part 'onboarding_provider.g.dart';

@Riverpod(keepAlive: true)
OnboardingRepository onboardingRepository(OnboardingRepositoryRef ref) =>
    OnboardingRepository();

@Riverpod(keepAlive: true)
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  Future<OnboardingState> build() {
    return ref.read(onboardingRepositoryProvider).read();
  }

  Future<void> setHomeLabel(OnboardingHomeLabel? label) async {
    await ref.read(onboardingRepositoryProvider).setHomeLabel(label);
    state = AsyncData(
      (state.valueOrNull ?? OnboardingState.initial)
          .copyWith(homeLabel: label, clearHomeLabel: label == null),
    );
  }

  Future<void> markComplete() async {
    await ref.read(onboardingRepositoryProvider).markComplete();
    state = AsyncData(
      (state.valueOrNull ?? OnboardingState.initial)
          .copyWith(completed: true),
    );
  }

  Future<void> reset() async {
    await ref.read(onboardingRepositoryProvider).reset();
    state = const AsyncData(OnboardingState.initial);
  }
}
