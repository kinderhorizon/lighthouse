/// First-use tip provider (ADR 0020). Manual Riverpod API (no codegen) so it
/// adds a provider without a build_runner pass.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';

final firstUseTipsStoreProvider =
    Provider<FirstUseTipsStore>((ref) => FirstUseTipsStore());
