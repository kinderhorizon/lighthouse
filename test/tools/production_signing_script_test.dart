/// Comprehensive automated tests for NūriTalk Production Signing Setup Utility.
///
/// Verifies:
/// 1. `tools/setup_production_signing.sh` exists, is executable, and supports --dry-run / --check / --help.
/// 2. Pre-flight checks correctly identify gitignore rules and fail-closed guards.
/// 3. Dry-run mode never creates or modifies any files.
/// 4. Command-line validation rejects unrecognized flags.
/// 5. Gradle build configuration contains the fail-closed release guard.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Production Signing Setup Utility Tests', () {
    const scriptPath = 'tools/setup_production_signing.sh';

    test('setup_production_signing.sh exists and has execute permissions', () {
      final script = File(scriptPath);
      expect(script.existsSync(), isTrue, reason: '$scriptPath must exist');

      final stat = script.statSync();
      // Verify execute permission for user (at least 0100)
      expect(stat.mode & 0x49, isNonZero, reason: '$scriptPath must be executable');
    });

    test('--help displays security guidance and exits with code 0', () {
      final result = Process.runSync('bash', [scriptPath, '--help']);
      expect(result.exitCode, equals(0));
      final out = result.stdout.toString();
      expect(out, contains('NūriTalk - Android Production Signing Setup Utility'));
      expect(out, contains('--dry-run'));
      expect(out, contains('--check'));
      expect(out, contains('SECURITY GUARANTEES:'));
      expect(out, contains('OFFLINE BACKUP REQUIREMENT:'));
    });

    test('--dry-run completes all pre-flight checks with code 0 without creating files', () {
      final keyPropBefore = File('android/key.properties').existsSync();
      final keystoreBefore = File('android/upload-keystore.jks').existsSync();

      final result = Process.runSync('bash', [scriptPath, '--dry-run']);
      expect(result.exitCode, equals(0), reason: 'Dry-run pre-flight checks must pass');

      final out = result.stdout.toString();
      expect(out, contains('[+] Git repository verified'));
      expect(out, contains('[+] JDK keytool detected'));
      expect(out, contains('[+] Git ignore rules verified'));
      expect(out, contains('[+] Android Gradle build configuration verified'));
      expect(out, contains('[+] Dry-run succeeded'));

      // Ensure dry-run created no files
      expect(File('android/key.properties').existsSync(), equals(keyPropBefore));
      expect(File('android/upload-keystore.jks').existsSync(), equals(keystoreBefore));
    });

    test('--check reports audit status and confirms gitignore exclusion', () {
      final result = Process.runSync('bash', [scriptPath, '--check']);
      expect(result.exitCode, equals(0));
      final out = result.stdout.toString();
      expect(out, contains('android/key.properties is properly gitignored'));
      expect(out, contains('Keystore (*.jks) is properly gitignored'));
      expect(out, contains('AUDIT COMPLETE: Configuration and security guards are operational'));
    });

    test('unrecognized arguments reject execution with exit code 1', () {
      final result = Process.runSync('bash', [scriptPath, '--invalid-flag-test']);
      expect(result.exitCode, equals(1));
      expect(result.stderr.toString(), contains('Unknown option: --invalid-flag-test'));
    });

    test('build.gradle.kts enforces fail-closed signing check and error message', () {
      final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(buildGradle, contains('hasValidReleaseKey'));
      expect(buildGradle, contains('allowDebugSigningForRelease'));
      expect(buildGradle, contains('ERROR: PRODUCTION RELEASE BUILD BLOCKED - SIGNING KEY REQUIRED'));
      expect(buildGradle, contains('resolvedStoreFile.exists()'));
      expect(buildGradle, contains('!keyAlias.isNullOrBlank()'));
    });
  });
}
