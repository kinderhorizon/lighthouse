/// Asset symbol provider.
///
/// Loads legally compatible open symbols from bundled Flutter assets (`assets/symbols/...`).
library;

import 'package:flutter/widgets.dart';

import 'symbol_provider.dart';

class AssetSymbolProvider implements SymbolProvider {
  const AssetSymbolProvider();

  @override
  String get id => 'asset';

  @override
  String get displayName => 'Bundled Commercial AAC Symbols';

  @override
  String get license => 'Apache-2.0';

  @override
  bool canHandle(String uri) => uri.startsWith('assets/');

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
    return Image.asset(
      uri,
      width: width,
      height: height,
      fit: fit,
      color: color,
      semanticLabel: label,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
