import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android ProGuard / R8 Rules Guard Tests', () {
    test('proguard-rules.pro exists and contains critical plugin retention rules', () {
      final file = File('android/app/proguard-rules.pro');
      expect(file.existsSync(), isTrue, reason: 'proguard-rules.pro must exist');

      final content = file.readAsStringSync();

      // Check critical Flutter & Kotlin rules
      expect(content, contains('-keep class io.flutter.**'));
      expect(content, contains('-keep class kotlin.coroutines.**'));
      expect(content, contains('-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses'));

      // Check critical native plugin rules
      expect(content, contains('io.flutter.plugins.sharedpreferences'));
      expect(content, contains('io.isar'));
      expect(content, contains('com.tundralabs.fluttertts'));
      expect(content, contains('com.ryanheise.just_audio'));
      expect(content, contains('com.llfbandit.record'));
      expect(content, contains('io.flutter.plugins.pathprovider'));
      expect(content, contains('io.flutter.plugins.imagepicker'));
    });

    test('android/app/build.gradle.kts references proguard-rules.pro in release buildType', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();
      expect(content, contains('proguardFiles('));
      expect(content, contains('"proguard-rules.pro"'));
    });
  });
}
