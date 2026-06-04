/// First-use tip "seen" flag persistence (ADR 0020).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('a tip is unseen on first run, seen after markSeen', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = FirstUseTipsStore(prefs: prefs);
    expect(await store.seen(FirstUseTipsStore.editorKey), isFalse);
    await store.markSeen(FirstUseTipsStore.editorKey);
    expect(await store.seen(FirstUseTipsStore.editorKey), isTrue);
  });

  test('the flag persists across a fresh store instance', () async {
    final prefs = await SharedPreferences.getInstance();
    await FirstUseTipsStore(prefs: prefs).markSeen(FirstUseTipsStore.editorKey);
    final fresh = FirstUseTipsStore(prefs: prefs);
    expect(await fresh.seen(FirstUseTipsStore.editorKey), isTrue);
  });

  test('distinct tip keys are independent', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = FirstUseTipsStore(prefs: prefs);
    await store.markSeen('editor');
    expect(await store.seen('somethingElse'), isFalse);
  });

  test('reset re-arms every known tip', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = FirstUseTipsStore(prefs: prefs);
    for (final k in FirstUseTipsStore.allKeys) {
      await store.markSeen(k);
    }
    await store.reset();
    for (final k in FirstUseTipsStore.allKeys) {
      expect(await store.seen(k), isFalse, reason: '$k should be re-armed');
    }
  });
}
