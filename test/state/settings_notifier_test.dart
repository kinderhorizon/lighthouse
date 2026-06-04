/// SettingsNotifier tile-content invariant.
///
/// The tile word and pictogram toggles both default ON. A parent may turn off
/// exactly one; they can NEVER both be off (a blank tile is unusable for a
/// non-speaking child). The notifier enforces this by forcing the other back
/// on, and persists that forced-on write so it survives a restart.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsNotifierProvider.future);
    return container;
  }

  SettingsState now(ProviderContainer c) =>
      c.read(settingsNotifierProvider).requireValue;

  test('both content toggles default on (nothing hidden)', () async {
    final c = await boot();
    expect(now(c).hideTileText, isFalse);
    expect(now(c).hidePictogram, isFalse);
  });

  test('hiding the word forces the pictogram back on', () async {
    final c = await boot();
    final n = c.read(settingsNotifierProvider.notifier);
    await n.setHidePictogram(true);
    expect(now(c).hidePictogram, isTrue);

    await n.setHideTileText(true);
    expect(now(c).hideTileText, isTrue);
    expect(now(c).hidePictogram, isFalse,
        reason: 'word + pictogram can never both be hidden');
  });

  test('hiding the pictogram forces the word back on', () async {
    final c = await boot();
    final n = c.read(settingsNotifierProvider.notifier);
    await n.setHideTileText(true);
    expect(now(c).hideTileText, isTrue);

    await n.setHidePictogram(true);
    expect(now(c).hidePictogram, isTrue);
    expect(now(c).hideTileText, isFalse,
        reason: 'word + pictogram can never both be hidden');
  });

  test('the forced-on flip is persisted (survives a restart)', () async {
    final c = await boot();
    final n = c.read(settingsNotifierProvider.notifier);
    await n.setHidePictogram(true);
    await n.setHideTileText(true); // forces hidePictogram off, must persist

    final restarted = await SettingsRepository().read();
    expect(restarted.hideTileText, isTrue);
    expect(restarted.hidePictogram, isFalse);
  });

  test('turning a toggle back on does not disturb the other', () async {
    final c = await boot();
    final n = c.read(settingsNotifierProvider.notifier);
    await n.setHidePictogram(true); // pictogram off, word on
    await n.setHidePictogram(false); // pictogram back on
    expect(now(c).hidePictogram, isFalse);
    expect(now(c).hideTileText, isFalse,
        reason: 'restoring one toggle must not flip the other');
  });
}
