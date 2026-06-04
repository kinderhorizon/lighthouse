/// Locale-registry font wiring (ADR 0008 + the bundled-Cairo work).
///
/// The Arabic locale must declare a bundled font so Arabic glyphs never depend
/// on the platform face (absent or poor on many tablets). main.dart reads
/// requiredFontFamily into ThemeData.fontFamily, so this value is load-bearing
/// for what the Arabic family actually sees. The Latin locales intentionally
/// leave it null (system default), relying on the app-wide Cairo fallback only
/// for stray non-Latin glyphs.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/i18n/locale_registry.dart';

void main() {
  test('Arabic declares the bundled Cairo font', () {
    expect(LocaleRegistry.specForCode('ar')?.requiredFontFamily, 'Cairo');
  });

  test('Latin launch locales use the system default (no required font)', () {
    expect(LocaleRegistry.specForCode('en')?.requiredFontFamily, isNull);
    expect(LocaleRegistry.specForCode('es')?.requiredFontFamily, isNull);
  });

  test('the bundled Cairo font asset exists and is non-trivial', () {
    final f = File('assets/fonts/Cairo.ttf');
    expect(f.existsSync(), isTrue,
        reason: 'requiredFontFamily Cairo must have a bundled face on disk');
    expect(f.lengthSync(), greaterThan(50000),
        reason: 'a real Arabic-capable TTF, not a placeholder');
  });
}
