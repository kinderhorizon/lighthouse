/// Riverpod provider for the active [SymbolProvider].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/symbols/symbols.dart';

/// Provides the active [SymbolProvider] for rendering board symbols.
final symbolProviderProvider = Provider<SymbolProvider>((ref) {
  return CompositeSymbolProvider.defaultInstance;
});
