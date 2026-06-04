// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'glow_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$rngFactoryHash() => r'633081db91c378dd83d17917531935fcc6f0b5fa';

/// RNG factory. Production passes a fresh non-seeded [math.Random] each
/// ranking call. Tests override with a seeded factory for determinism.
///
/// Copied from [rngFactory].
@ProviderFor(rngFactory)
final rngFactoryProvider = Provider<math.Random Function()>.internal(
  rngFactory,
  name: r'rngFactoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$rngFactoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RngFactoryRef = ProviderRef<math.Random Function()>;
String _$banditRankerHash() => r'0d1b00dc4f52a08b5cb97338e858c574a0427f76';

/// See also [banditRanker].
@ProviderFor(banditRanker)
final banditRankerProvider = Provider<BanditRanker>.internal(
  banditRanker,
  name: r'banditRankerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$banditRankerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BanditRankerRef = ProviderRef<BanditRanker>;
String _$currentPredictionsHash() =>
    r'21bd0420b5c7ac2dd03303e4118d0c24ab13152e';

/// Predictions for the currently active board under the current
/// context. Returned map is keyed by button id; only IDs with a
/// non-[GlowLevel.none] level appear. Buttons not in the map default
/// to no-glow.
/// Ranked predictions for the active board under the current context.
/// The list has at most [kMaxGlows] entries, ordered by Thompson draw
/// descending. Empty when no board is active.
///
/// Copied from [currentPredictions].
@ProviderFor(currentPredictions)
final currentPredictionsProvider =
    FutureProvider<List<RankedPrediction>>.internal(
  currentPredictions,
  name: r'currentPredictionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentPredictionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentPredictionsRef = FutureProviderRef<List<RankedPrediction>>;
String _$currentGlowHash() => r'b0df118c4df0172d032845b76e63ec5b473b4f71';

/// See also [currentGlow].
@ProviderFor(currentGlow)
final currentGlowProvider = FutureProvider<Map<String, GlowLevel>>.internal(
  currentGlow,
  name: r'currentGlowProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentGlowHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentGlowRef = FutureProviderRef<Map<String, GlowLevel>>;
String _$contextEpochHash() => r'4ce6976475d3b977ed0fd7b0ae6c1399a07c025c';

/// Monotonically increasing counter that rotates whenever a tap has
/// been recorded. The glow provider watches this so it re-fetches
/// predictions after each tap (the ContextManager mutates in place;
/// Riverpod cannot otherwise observe the change).
///
/// Copied from [ContextEpoch].
@ProviderFor(ContextEpoch)
final contextEpochProvider = NotifierProvider<ContextEpoch, int>.internal(
  ContextEpoch.new,
  name: r'contextEpochProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$contextEpochHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ContextEpoch = Notifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
