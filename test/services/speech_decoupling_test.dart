import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/i18n/locale_registry.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SettingsState supports independent speechLocaleOverride, rate, and pitch',
      () async {
    final repo = SettingsRepository();
    var settings = await repo.read();

    expect(settings.speechLocaleOverride, isNull);
    expect(settings.voiceRate, 1.0);
    expect(settings.voicePitch, 1.0);
    expect(settings.highContrast, isFalse);

    await repo.setSpeechLocaleOverride('ar_dz');
    await repo.setVoiceRate(1.25);
    await repo.setVoicePitch(0.9);
    await repo.setHighContrast(true);

    settings = await repo.read();
    expect(settings.speechLocaleOverride, 'ar_dz');
    expect(settings.voiceRate, 1.25);
    expect(settings.voicePitch, 0.9);
    expect(settings.highContrast, isTrue);
  });

  test('Vocabulary resolves independent UI label vs Speech-output language', () {
    const button = AACButton(
      id: 'btn_water',
      label: 'Water',
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: 'food',
      baseWeight: 0.8,
      iconUri: 'assets/symbols/food/water.png',
      voiceOut: 'water',
      labelByLocale: {
        'en': 'Water',
        'ar': 'ماء',
        'ar_dz': 'الما',
        'de': 'Wasser',
      },
      voiceOutByLocale: {
        'en': 'water',
        'ar': 'ماء',
        'ar_dz': 'حاب نشرب الماء',
        'de': 'Wasser',
      },
    );

    // English UI with Algerian Darija speech output
    expect(button.labelFor('en'), 'Water');
    expect(button.voiceOutFor('ar_dz'), 'حاب نشرب الماء');

    // German UI with Arabic speech output
    expect(button.labelFor('de'), 'Wasser');
    expect(button.voiceOutFor('ar'), 'ماء');

    // Subtag normalization: 'ar-DZ' resolves to 'ar_dz'
    expect(button.labelFor('ar-DZ'), 'الما');
    expect(button.voiceOutFor('ar-DZ'), 'حاب نشرب الماء');
  });

  test('LocaleRegistry codeForLocale correctly identifies dialect sub-locales', () {
    expect(LocaleRegistry.codeForLocale(const Locale('en')), 'en');
    expect(LocaleRegistry.codeForLocale(const Locale('de')), 'de');
    expect(LocaleRegistry.codeForLocale(const Locale('ar')), 'ar');
    expect(LocaleRegistry.codeForLocale(const Locale('ar', 'DZ')), 'ar_dz');
    // Generic non-registered region falls back to language code
    expect(LocaleRegistry.codeForLocale(const Locale('ar', 'EG')), 'ar');
  });
}
