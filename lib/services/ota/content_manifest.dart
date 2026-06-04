/// OTA content manifest (ADR 0017).
///
/// The small versioned index the app fetches (only on the parent's explicit
/// "Check for updates" tap) to learn what content corrections are available.
/// Each entry is content-addressed by sha256 so a download can be
/// integrity-checked before it is applied. The manifest is served as
/// `manifest.json`; its AUTHENTICITY is verified separately, via a detached
/// signature checked against the app's bundled public-key trust-list (a layer
/// built on top of this pure model, ADR 0017).
///
/// Parsing is strict: a malformed manifest throws [ContentManifestException]
/// and is never partially applied. A bad manifest must be a no-op, never a
/// corrupted board for a non-speaking child (same discipline as BoardLoader).
library;

import 'dart:convert';

class ContentManifestException implements Exception {
  const ContentManifestException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ContentManifestException: $message'
      '${cause != null ? '\nCaused by: $cause' : ''}';
}

/// One updatable file: its content-root-relative [path], the expected [sha256]
/// of its bytes, and its size in [bytes].
class ContentManifestEntry {
  const ContentManifestEntry({
    required this.path,
    required this.sha256,
    required this.bytes,
  });

  final String path;
  final String sha256;
  final int bytes;

  Map<String, dynamic> toJson() => {
        'path': path,
        'sha256': sha256,
        'bytes': bytes,
      };

  factory ContentManifestEntry.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final sha256 = json['sha256'];
    final bytes = json['bytes'];
    if (path is! String || path.isEmpty) {
      throw const ContentManifestException('entry missing "path"');
    }
    if (sha256 is! String || sha256.isEmpty) {
      throw ContentManifestException('entry "$path" missing "sha256"');
    }
    if (bytes is! int || bytes < 0) {
      throw ContentManifestException('entry "$path" has invalid "bytes"');
    }
    // The path is used to place a file under the on-device overlay dir, so it
    // must be a safe relative path. Closes a traversal vector from an untrusted
    // manifest (e.g. `../../lighthouse_db`), the same class of guard AACBoard
    // applies to board ids.
    if (!isSafeRelativePath(path)) {
      throw ContentManifestException('entry has unsafe "path": $path');
    }
    return ContentManifestEntry(path: path, sha256: sha256, bytes: bytes);
  }

  /// Path safety: relative, forward-slash, no `..`/`.` segments, no leading
  /// slash, no backslashes, no NUL, no empty segments.
  static bool isSafeRelativePath(String p) {
    if (p.startsWith('/') || p.contains('\\') || p.contains('\u0000')) {
      return false;
    }
    for (final seg in p.split('/')) {
      if (seg.isEmpty || seg == '..' || seg == '.') return false;
    }
    return true;
  }
}

class ContentManifest {
  const ContentManifest({
    required this.schemaVersion,
    required this.sequence,
    required this.contentVersion,
    required this.files,
    this.minAppVersion,
    this.targetVersion,
  });

  final int schemaVersion;

  /// Monotonic, strictly-increasing publish counter. The client REFUSES to
  /// apply a manifest whose sequence is <= the applied one (ADR 0017), which
  /// blocks a downgrade/rollback attack: a validly-signed OLD manifest (replayed
  /// by a stale CDN cache or an attacker) cannot roll a device back to withdrawn
  /// content, even though its signature checks out.
  final int sequence;

  /// Human-readable version label for the whole content set (display / logs).
  /// Ordering is decided by [sequence], not this string.
  final String contentVersion;

  /// Optional minimum app version that can render this content set. The client
  /// compares locally and refuses content a too-old build cannot handle, so the
  /// server never needs to know which build is asking.
  final String? minAppVersion;

  /// Optional release the corrections in this manifest have been FOLDED INTO the
  /// app bundle for (ADR 0021), as a combined `"<version>+<build>"` identity,
  /// e.g. `"0.1.0+8"`. The client offers this manifest only to builds STRICTLY
  /// BELOW this release (their bundle does not yet contain the fix); a build at
  /// or above it already bundles the content and is not re-offered. Null means
  /// "no fold has shipped yet": always eligible (the pre-0021 behavior). The
  /// comparison is purely local; the build number never leaves the device. This
  /// tag MUST name a release that has actually shipped the fold, never a forward
  /// promise (ADR 0021, HIGH-2).
  final String? targetVersion;

  final List<ContentManifestEntry> files;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'sequence': sequence,
        'contentVersion': contentVersion,
        if (minAppVersion != null) 'minAppVersion': minAppVersion,
        // Omit when null so a pre-0021 / null-tagged manifest serializes
        // byte-identically (the bytes are signed; an emitted `null` would break
        // existing signatures). Mirrors minAppVersion above.
        if (targetVersion != null) 'targetVersion': targetVersion,
        'files': [for (final f in files) f.toJson()],
      };

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int) {
      throw const ContentManifestException('missing/invalid "schemaVersion"');
    }
    final sequence = json['sequence'];
    if (sequence is! int || sequence < 0) {
      throw const ContentManifestException('missing/invalid "sequence"');
    }
    final contentVersion = json['contentVersion'];
    if (contentVersion is! String || contentVersion.isEmpty) {
      throw const ContentManifestException('missing "contentVersion"');
    }
    // contentVersion is joined into an on-device path (the overlay version
    // dir, content_overlay_store.dart). Even though the manifest is signed,
    // validate it as a single safe path segment so a malformed (or
    // pipeline-bug) manifest can never write outside the versions dir or break
    // GC. Mirrors the file-path guard above; defense in depth.
    if (!isSafeVersionSegment(contentVersion)) {
      throw ContentManifestException(
          'unsafe "contentVersion" (must match ${_versionPattern.pattern} '
          'and not be "." or ".."): $contentVersion');
    }
    final minAppVersion = json['minAppVersion'];
    if (minAppVersion != null && minAppVersion is! String) {
      throw const ContentManifestException('"minAppVersion" must be a string');
    }
    // targetVersion (ADR 0021): nullable; type-checked only. Its shape is the
    // device's own `"<version>+<build>"` identity, compared locally; there is no
    // traversal/path risk (it is never joined into a filesystem path), so no
    // further validation beyond "must be a string".
    final targetVersion = json['targetVersion'];
    if (targetVersion != null && targetVersion is! String) {
      throw const ContentManifestException('"targetVersion" must be a string');
    }
    final filesRaw = json['files'];
    if (filesRaw is! List) {
      throw const ContentManifestException('"files" must be an array');
    }
    final files = <ContentManifestEntry>[
      for (final f in filesRaw)
        if (f is Map<String, dynamic>)
          ContentManifestEntry.fromJson(f)
        else
          throw const ContentManifestException('each file must be an object'),
    ];
    return ContentManifest(
      schemaVersion: schemaVersion,
      sequence: sequence,
      contentVersion: contentVersion,
      minAppVersion: minAppVersion as String?,
      targetVersion: targetVersion as String?,
      files: List.unmodifiable(files),
    );
  }

  /// Allowed shape for [contentVersion]: a single safe path segment. Note `.`
  /// and `..` MATCH this pattern, so [isSafeVersionSegment] rejects them
  /// separately.
  static final RegExp _versionPattern = RegExp(r'^[A-Za-z0-9._-]{1,64}$');

  /// Whether [v] is safe to use as a single on-device directory name: bounded,
  /// no slashes/backslashes/NUL, and not the `.`/`..` traversal segments.
  static bool isSafeVersionSegment(String v) {
    if (!_versionPattern.hasMatch(v)) return false;
    if (v == '.' || v == '..') return false;
    return true;
  }

  /// Parses [raw] manifest JSON text. Throws [ContentManifestException] on any
  /// problem; never returns a partial manifest.
  factory ContentManifest.parse(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw ContentManifestException('malformed JSON', cause: e);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ContentManifestException('top-level value must be an object');
    }
    return ContentManifest.fromJson(decoded);
  }
}
