/// Data URI symbol provider for Web and inline images.
///
/// Handles `data:image/...;base64,...` URIs across Web, Android, and iOS.
library;

import 'dart:convert';
import 'package:flutter/widgets.dart';

import 'symbol_provider.dart';

class DataUriSymbolProvider implements SymbolProvider {
  const DataUriSymbolProvider();

  @override
  String get id => 'data_uri';

  @override
  String get displayName => 'Inline Base64 Data Symbols';

  @override
  String get license => 'User Captured / Local';

  @override
  bool canHandle(String uri) {
    return uri.startsWith('data:image/');
  }

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
    try {
      final commaIndex = uri.indexOf(',');
      if (commaIndex == -1) return const SizedBox.shrink();
      final base64String = uri.substring(commaIndex + 1);
      final bytes = base64Decode(base64String);

      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        color: color,
        semanticLabel: label,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
