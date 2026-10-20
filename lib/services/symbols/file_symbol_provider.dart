/// File symbol provider.
///
/// Loads user-captured symbols and custom photos from local storage.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'symbol_provider.dart';

class FileSymbolProvider implements SymbolProvider {
  const FileSymbolProvider();

  @override
  String get id => 'file';

  @override
  String get displayName => 'Local File Symbols';

  @override
  String get license => 'Proprietary / User Captured';

  @override
  bool canHandle(String uri) {
    if (kIsWeb) return false;
    if (uri.isEmpty ||
        uri.startsWith('assets/') ||
        uri.startsWith('symbol://') ||
        uri.startsWith('data:')) {
      return false;
    }
    return uri.startsWith('/') || uri.contains(Platform.pathSeparator);
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
    return Image.file(
      File(uri),
      width: width,
      height: height,
      fit: fit,
      color: color,
      semanticLabel: label,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
