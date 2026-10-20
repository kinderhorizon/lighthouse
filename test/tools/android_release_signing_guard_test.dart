/// Verification test for Android Release Signing Safety & Fail-Closed Guard.
///
/// Ensures:
/// 1. `.gitignore` strictly ignores keystore files and key.properties.
/// 2. `android/key.properties.example` exists with safe placeholders.
/// 3. `android/app/build.gradle.kts` enforces fail-closed release signing.
/// 4. `tools/verify_android_signing.py` is executable and detects debug-signed binaries.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Release Signing Safety Guard Tests', () {
    test('.gitignore excludes key.properties and keystore files', () {
      final rootGitignore = File('.gitignore').readAsStringSync();
      expect(rootGitignore, contains('**/key.properties'));
      expect(rootGitignore, contains('*.jks'));
      expect(rootGitignore, contains('*.keystore'));

      final androidGitignore = File('android/.gitignore').readAsStringSync();
      expect(androidGitignore, contains('key.properties'));
      expect(androidGitignore, contains('*.jks'));
      expect(androidGitignore, contains('*.keystore'));
    });

    test('android/key.properties.example exists and contains no leaked credentials', () {
      final exampleFile = File('android/key.properties.example');
      expect(exampleFile.existsSync(), isTrue);

      final content = exampleFile.readAsStringSync();
      expect(content, contains('storeFile='));
      expect(content, contains('storePassword='));
      expect(content, contains('keyAlias='));
      expect(content, contains('keyPassword='));

      // Ensure no real secrets or passwords are in the example
      expect(content, contains('YOUR_KEYSTORE_PASSWORD_HERE'));
      expect(content, contains('YOUR_KEY_PASSWORD_HERE'));
    });

    test('android/app/build.gradle.kts enforces fail-closed signing check', () {
      final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();

      // Verify fail-closed check in taskGraph
      expect(buildGradle, contains('hasValidReleaseKey'));
      expect(buildGradle, contains('allowDebugSigningForRelease'));
      expect(buildGradle, contains('ERROR: PRODUCTION RELEASE BUILD BLOCKED - SIGNING KEY REQUIRED'));

      // Verify that release signing requires all valid properties
      expect(buildGradle, contains('resolvedStoreFile.exists()'));
      expect(buildGradle, contains('!keyAlias.isNullOrBlank()'));
    });

    test('tools/verify_android_signing.py exists and correctly parses signing status', () {
      final script = File('tools/verify_android_signing.py');
      expect(script.existsSync(), isTrue);

      final result = Process.runSync(
        'python3',
        ['tools/verify_android_signing.py', '--all'],
      );

      // Verify that verify_android_signing correctly evaluates artifacts:
      // When production signed: exitCode == 0, contains PRODUCTION_SIGNED
      // When debug signed: exitCode == 2, contains BLOCKED FOR GOOGLE PLAY
      expect(result.exitCode, isIn([0, 2]));
      final stdout = result.stdout.toString();
      if (result.exitCode == 0) {
        expect(stdout, contains('PRODUCTION_SIGNED'));
        expect(stdout, contains('VERIFIED'));
      } else {
        expect(stdout, contains('DEBUG_SIGNED_TEST_ARTIFACT'));
        expect(stdout, contains('BLOCKED FOR GOOGLE PLAY'));
      }
    });
  });
}
