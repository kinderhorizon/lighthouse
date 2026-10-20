/// Symbol provider abstraction.
///
/// Enables pluggable, multi-source AAC symbol rendering (assets, local files,
/// vectors, or custom plugins) with strict licensing and attribution metadata.
library;

import 'package:flutter/widgets.dart';

abstract interface class SymbolProvider {
  /// Unique identifier for this provider.
  String get id;

  /// Human-readable display name.
  String get displayName;

  /// License governing symbols rendered by this provider.
  String get license;

  /// Whether this provider can handle the given URI.
  bool canHandle(String uri);

  /// Builds the symbol widget.
  Widget buildSymbol(
    BuildContext context, {
    required String uri,
    required String label,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
  });
}
