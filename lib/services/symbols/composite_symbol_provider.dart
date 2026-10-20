/// Composite symbol provider.
///
/// Chains multiple providers with prioritized fallback:
/// File -> Bundled Asset -> Vector Material.
library;

import 'package:flutter/widgets.dart';

import 'asset_symbol_provider.dart';
import 'data_uri_symbol_provider.dart';
import 'file_symbol_provider.dart';
import 'symbol_provider.dart';
import 'vector_symbol_provider.dart';

class CompositeSymbolProvider implements SymbolProvider {
  CompositeSymbolProvider({List<SymbolProvider>? providers})
      : providers = providers ??
            const [
              DataUriSymbolProvider(),
              FileSymbolProvider(),
              AssetSymbolProvider(),
              VectorSymbolProvider(),
            ];

  final List<SymbolProvider> providers;

  static final CompositeSymbolProvider defaultInstance =
      CompositeSymbolProvider();

  @override
  String get id => 'composite';

  @override
  String get displayName => 'Unified AAC Symbol System';

  @override
  String get license => 'Apache-2.0';

  @override
  bool canHandle(String uri) => providers.any((p) => p.canHandle(uri));

  @override
  Widget buildSymbol(
    BuildContext context, {
    required String uri,
    required String label,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
  }) {
    for (final p in providers) {
      if (p.canHandle(uri)) {
        return p.buildSymbol(
          context,
          uri: uri,
          label: label,
          width: width,
          height: height,
          fit: fit,
          color: color,
        );
      }
    }
    return const SizedBox.shrink();
  }
}
