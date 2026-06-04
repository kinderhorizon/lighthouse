/// Board loader.
///
/// Loads an [AACBoard] from a JSON document. Supports two sources:
/// - the Flutter asset bundle (default boards shipped with the app)
/// - an arbitrary file path (Pack Loader, when imported by the user via the
///   system file-import flow; Phase 1 follow-up).
///
/// Throws [BoardLoadException] with diagnostics on any parse failure. Never
/// returns a partial or default-substituted board. Silent failure here would
/// surface as a broken grid for a non-speaking child, which is unacceptable.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../models/aac_board.dart';

class BoardLoadException implements Exception {
  const BoardLoadException(this.message, {this.source, this.cause});

  final String message;
  final String? source;
  final Object? cause;

  @override
  String toString() {
    final src = source != null ? ' (source: $source)' : '';
    final c = cause != null ? '\nCaused by: $cause' : '';
    return 'BoardLoadException: $message$src$c';
  }
}

class BoardLoader {
  const BoardLoader();

  /// Upper bound on a board JSON file loaded from disk (the Pack Loader, an
  /// untrusted source). A real board is a few KB; this rejects a multi-megabyte
  /// pack before it is read fully into memory and decoded. Bundled assets are
  /// trusted and not size-checked.
  static const int maxFileBytes = 4 * 1024 * 1024;

  /// Loads a bundled board from `assets/` (path given relative to the bundle
  /// root, e.g., "boards/core_main.json").
  Future<AACBoard> loadFromAssets(String assetPath) async {
    final String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (e) {
      throw BoardLoadException(
        'Could not read asset',
        source: assetPath,
        cause: e,
      );
    }
    return _parse(raw, source: assetPath);
  }

  /// Loads a board from a file on the device (used by the Pack Loader).
  Future<AACBoard> loadFromFile(File file) async {
    final String raw;
    try {
      // Reject an oversized pack BEFORE reading it into memory.
      final length = await file.length();
      if (length > maxFileBytes) {
        throw BoardLoadException(
          'Board file is too large (${length} bytes, max $maxFileBytes)',
          source: file.path,
        );
      }
      raw = await file.readAsString();
    } on BoardLoadException {
      rethrow;
    } catch (e) {
      throw BoardLoadException(
        'Could not read file',
        source: file.path,
        cause: e,
      );
    }
    return _parse(raw, source: file.path);
  }

  AACBoard _parse(String raw, {required String source}) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw BoardLoadException(
        'Malformed JSON',
        source: source,
        cause: e,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw BoardLoadException(
        'Top-level JSON value must be an object',
        source: source,
      );
    }
    try {
      return AACBoard.fromJson(decoded);
    } on FormatException catch (e) {
      throw BoardLoadException(
        'Schema mismatch',
        source: source,
        cause: e,
      );
    }
  }
}
