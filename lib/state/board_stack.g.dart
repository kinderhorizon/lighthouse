// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board_stack.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$boardRegistryHash() => r'b31518efb85fd3e192b270f71dc7d1af61763e42';

/// Async because the registry hydrates from the persistent import
/// directory on startup so imported sub-boards survive across app
/// launches.
///
/// Copied from [boardRegistry].
@ProviderFor(boardRegistry)
final boardRegistryProvider = FutureProvider<BoardRegistry>.internal(
  boardRegistry,
  name: r'boardRegistryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$boardRegistryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BoardRegistryRef = FutureProviderRef<BoardRegistry>;
String _$activeBoardHash() => r'e383d287f1002d9efccb0a6bfd1b10768217a71e';

/// See also [activeBoard].
@ProviderFor(activeBoard)
final activeBoardProvider = AutoDisposeProvider<AACBoard?>.internal(
  activeBoard,
  name: r'activeBoardProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$activeBoardHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ActiveBoardRef = AutoDisposeProviderRef<AACBoard?>;
String _$boardStackHash() => r'e63c170010414362888e74a6e7707c345cd0673a';

/// See also [BoardStack].
@ProviderFor(BoardStack)
final boardStackProvider =
    NotifierProvider<BoardStack, List<AACBoard>>.internal(
  BoardStack.new,
  name: r'boardStackProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$boardStackHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BoardStack = Notifier<List<AACBoard>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
