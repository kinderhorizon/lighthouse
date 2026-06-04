// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favourites_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$favouritesStoreHash() => r'dd89048e95d4b063236ef91bf617be71babd2fa8';

/// See also [favouritesStore].
@ProviderFor(favouritesStore)
final favouritesStoreProvider = Provider<FavouritesStore>.internal(
  favouritesStore,
  name: r'favouritesStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$favouritesStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FavouritesStoreRef = ProviderRef<FavouritesStore>;
String _$homeFavouritesHash() => r'9e636f4ffdad94b91366cf7772b42a85e4d0b011';

/// The pinned buttons to render in the home strip, in pin order. Resolves
/// against the loaded boards; folders and unresolvable refs are dropped.
/// Returns empty (without loading boards) when there are no pins, so the
/// common no-pins case adds no startup cost or home chrome.
///
/// Copied from [homeFavourites].
@ProviderFor(homeFavourites)
final homeFavouritesProvider =
    AutoDisposeFutureProvider<List<AACButton>>.internal(
      homeFavourites,
      name: r'homeFavouritesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$homeFavouritesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeFavouritesRef = AutoDisposeFutureProviderRef<List<AACButton>>;
String _$favouriteSuggestionsHash() =>
    r'a6687638de38d855e2339c825404f25faa03ec87';

/// On-demand "used a lot" suggestions for the editor: most-tapped buttons not
/// already pinned, each with the board it lives on (so the editor can pin it).
/// Resolved to live buttons; folders dropped.
///
/// Copied from [favouriteSuggestions].
@ProviderFor(favouriteSuggestions)
final favouriteSuggestionsProvider =
    AutoDisposeFutureProvider<
      List<({ButtonRef ref, AACButton button})>
    >.internal(
      favouriteSuggestions,
      name: r'favouriteSuggestionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$favouriteSuggestionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FavouriteSuggestionsRef =
    AutoDisposeFutureProviderRef<List<({ButtonRef ref, AACButton button})>>;
String _$favouritesHash() => r'd856c6615ae0ded7d122fa9636036edf8f49d5ef';

/// See also [Favourites].
@ProviderFor(Favourites)
final favouritesProvider =
    AsyncNotifierProvider<Favourites, List<ButtonRef>>.internal(
      Favourites.new,
      name: r'favouritesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$favouritesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Favourites = AsyncNotifier<List<ButtonRef>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
