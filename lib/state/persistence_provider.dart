/// Riverpod handles for the persistence layer.
///
/// Isar is opened once at app startup (main.dart) and exposed as a
/// keepAlive provider. The bandit repository is derived from it.
library;

import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../persistence/persistence.dart';

part 'persistence_provider.g.dart';

@Riverpod(keepAlive: true)
Isar isar(IsarRef ref) {
  throw UnimplementedError(
    'isarProvider must be overridden at app startup with the live Isar',
  );
}

@Riverpod(keepAlive: true)
BanditRepository banditRepository(BanditRepositoryRef ref) {
  return BanditRepository(ref.watch(isarProvider));
}
