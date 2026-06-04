// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_button_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customButtonStoreHash() => r'5c26a7ca5594c48c0f0f116df47ef6c108fc9318';

/// See also [customButtonStore].
@ProviderFor(customButtonStore)
final customButtonStoreProvider = Provider<CustomButtonStore>.internal(
  customButtonStore,
  name: r'customButtonStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$customButtonStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CustomButtonStoreRef = ProviderRef<CustomButtonStore>;
String _$editableBoardsHash() => r'1617d417f5335e0b98ebea8a53afc0d197816131';

/// Every known board with custom buttons already overlaid, for the editor to
/// show each board's display name and remaining empty slots. Re-resolves when
/// the custom-button list changes.
///
/// Copied from [editableBoards].
@ProviderFor(editableBoards)
final editableBoardsProvider =
    AutoDisposeFutureProvider<List<AACBoard>>.internal(
      editableBoards,
      name: r'editableBoardsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$editableBoardsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EditableBoardsRef = AutoDisposeFutureProviderRef<List<AACBoard>>;
String _$customButtonsHash() => r'0f08130c89896c760b2e2c11266a3fa0de870ebf';

/// See also [CustomButtons].
@ProviderFor(CustomButtons)
final customButtonsProvider =
    AsyncNotifierProvider<CustomButtons, List<CustomButton>>.internal(
      CustomButtons.new,
      name: r'customButtonsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$customButtonsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CustomButtons = AsyncNotifier<List<CustomButton>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
