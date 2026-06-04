/// ContextManager + bandit-updater providers.
///
/// One ContextManager instance lives for the lifetime of the app; the
/// in-memory `previousButtonId` + semantic decay state belongs to it.
/// The bandit updater is a thin wrapper over the persistence repo.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../logic/logic.dart';
import 'cold_start_provider.dart';
import 'persistence_provider.dart';

part 'context_provider.g.dart';

@Riverpod(keepAlive: true)
ContextManager contextManager(ContextManagerRef ref) => ContextManager();

@Riverpod(keepAlive: true)
BanditUpdater banditUpdater(BanditUpdaterRef ref) {
  return BanditUpdater(
    store: ref.watch(banditRepositoryProvider),
    // Same artifact instance the ranker scores with (one provider), so a row is
    // never seeded under a different prior than it was ranked under. Empty ->
    // base_weight until the artifact loads (today's behaviour).
    coldStart: ref.watch(contextualColdStartProvider).valueOrNull ??
        const ContextualColdStart.empty(),
  );
}
