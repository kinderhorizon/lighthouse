import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/ota/content_manifest.dart';

void main() {
  const validJson = {
    'schemaVersion': 1,
    'sequence': 1,
    'contentVersion': '2026-05-31',
    'minAppVersion': '1.0.0',
    'files': [
      {'path': 'boards/board_body.json', 'sha256': 'abc123', 'bytes': 1234},
      {'path': 'audio/en/deadbeef.mp3', 'sha256': 'def456', 'bytes': 5678},
    ],
  };

  test('parses a valid manifest and round-trips through toJson', () {
    final m = ContentManifest.parse(jsonEncode(validJson));
    expect(m.schemaVersion, 1);
    expect(m.contentVersion, '2026-05-31');
    expect(m.minAppVersion, '1.0.0');
    expect(m.files, hasLength(2));
    expect(m.files.first.path, 'boards/board_body.json');
    expect(m.files.first.sha256, 'abc123');
    expect(m.files.first.bytes, 1234);
    // Round-trip: re-parsing the serialized form yields the same canonical JSON.
    expect(ContentManifest.fromJson(m.toJson()).toJson(), equals(m.toJson()));
  });

  test('minAppVersion is optional and omitted from toJson when absent', () {
    final json = Map<String, dynamic>.from(validJson)..remove('minAppVersion');
    final m = ContentManifest.parse(jsonEncode(json));
    expect(m.minAppVersion, isNull);
    expect(m.toJson().containsKey('minAppVersion'), isFalse);
  });

  group('targetVersion (ADR 0021)', () {
    test('parses and round-trips through toJson when present', () {
      final json = Map<String, dynamic>.from(validJson)
        ..['targetVersion'] = '0.1.0+8';
      final m = ContentManifest.parse(jsonEncode(json));
      expect(m.targetVersion, '0.1.0+8');
      expect(m.toJson()['targetVersion'], '0.1.0+8');
      expect(ContentManifest.fromJson(m.toJson()).toJson(), equals(m.toJson()));
    });

    test('is optional and omitted from toJson when absent (not emitted as null)',
        () {
      final json = Map<String, dynamic>.from(validJson)
        ..remove('targetVersion');
      final m = ContentManifest.parse(jsonEncode(json));
      expect(m.targetVersion, isNull);
      expect(m.toJson().containsKey('targetVersion'), isFalse);
    });

    test('a null-tagged manifest serializes byte-identically to pre-0021', () {
      // The exact bytes a builder would emit BEFORE this field existed.
      final pre0021 = {
        'schemaVersion': 1,
        'sequence': 1,
        'contentVersion': '2026-05-31',
        'minAppVersion': '1.0.0',
        'files': [
          {'path': 'boards/board_body.json', 'sha256': 'abc123', 'bytes': 1234},
          {'path': 'audio/en/deadbeef.mp3', 'sha256': 'def456', 'bytes': 5678},
        ],
      };
      const encoder = JsonEncoder.withIndent('  ');
      final m = ContentManifest.parse(jsonEncode(pre0021));
      expect(m.targetVersion, isNull);
      // Byte-for-byte identical: the signature over a pre-0021 manifest still
      // verifies after this change.
      expect(encoder.convert(m.toJson()), equals(encoder.convert(pre0021)));
    });

    test('rejects a non-string targetVersion', () {
      final json = Map<String, dynamic>.from(validJson)
        ..['targetVersion'] = 42;
      expect(() => ContentManifest.parse(jsonEncode(json)),
          throwsA(isA<ContentManifestException>()));
    });
  });

  test('empty files list is valid', () {
    final json = Map<String, dynamic>.from(validJson)..['files'] = [];
    expect(ContentManifest.parse(jsonEncode(json)).files, isEmpty);
  });

  test('malformed JSON throws', () {
    expect(() => ContentManifest.parse('{not json'),
        throwsA(isA<ContentManifestException>()));
  });

  test('non-object top level throws', () {
    expect(() => ContentManifest.parse('[]'),
        throwsA(isA<ContentManifestException>()));
  });

  test('missing schemaVersion / contentVersion / files throws', () {
    for (final key in ['schemaVersion', 'sequence', 'contentVersion', 'files']) {
      final json = Map<String, dynamic>.from(validJson)..remove(key);
      expect(() => ContentManifest.parse(jsonEncode(json)),
          throwsA(isA<ContentManifestException>()),
          reason: 'removing "$key" must throw');
    }
  });

  test('entry with a missing sha256 or invalid bytes throws', () {
    final noSha = Map<String, dynamic>.from(validJson)
      ..['files'] = [
        {'path': 'boards/x.json', 'bytes': 1}
      ];
    expect(() => ContentManifest.parse(jsonEncode(noSha)),
        throwsA(isA<ContentManifestException>()));

    final badBytes = Map<String, dynamic>.from(validJson)
      ..['files'] = [
        {'path': 'boards/x.json', 'sha256': 'a', 'bytes': -1}
      ];
    expect(() => ContentManifest.parse(jsonEncode(badBytes)),
        throwsA(isA<ContentManifestException>()));
  });

  group('path-traversal guard (untrusted manifest)', () {
    for (final bad in [
      '../escape.json',
      'boards/../../secret',
      '/absolute/path.json',
      'boards\\windows.json',
      'a//b.json',
      './rel.json',
    ]) {
      test('rejects unsafe path "$bad"', () {
        final json = Map<String, dynamic>.from(validJson)
          ..['files'] = [
            {'path': bad, 'sha256': 'a', 'bytes': 1}
          ];
        expect(() => ContentManifest.parse(jsonEncode(json)),
            throwsA(isA<ContentManifestException>()));
      });
    }

    test('accepts a normal nested path', () {
      expect(
        ContentManifestEntry.isSafeRelativePath('audio/ar/deadbeef.mp3'),
        isTrue,
      );
    });
  });

  group('contentVersion path-segment guard (untrusted manifest)', () {
    for (final bad in [
      '..',
      '.',
      '../evil',
      'a/b',
      r'a\b',
      'has space',
      'a:b', // colon is not path-safe on every filesystem
      'x' * 65,
    ]) {
      test('rejects unsafe contentVersion "$bad"', () {
        final json = Map<String, dynamic>.from(validJson)
          ..['contentVersion'] = bad;
        expect(() => ContentManifest.parse(jsonEncode(json)),
            throwsA(isA<ContentManifestException>()));
      });
    }

    for (final ok in ['2026.05.31', '2026-05-31', 'v1_2_3', 'A.B-c_9']) {
      test('accepts safe contentVersion "$ok"', () {
        expect(ContentManifest.isSafeVersionSegment(ok), isTrue);
      });
    }
  });
}
