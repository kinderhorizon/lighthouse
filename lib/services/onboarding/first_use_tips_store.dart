/// Persistence for one-time "first-use" tips (ADR 0020).
///
/// A first-use tip is a small dismissible bubble shown the FIRST time a parent
/// opens a powerful screen (e.g. the board editor). The "seen" flag is a single
/// SharedPreferences bool per tip key, mirroring the prototype's `localStorage`
/// usage, so each tip shows exactly once and then never again.
library;

import 'package:shared_preferences/shared_preferences.dart';

class FirstUseTipsStore {
  FirstUseTipsStore({SharedPreferences? prefs}) : _override = prefs;

  final SharedPreferences? _override;
  SharedPreferences? _cached;

  static const String _prefix = 'tip_seen.';

  // Tip keys, one per powerful screen (v7 handoff).
  static const String editorKey = 'editor';
  static const String gateKey = 'gate';
  static const String customButtonsKey = 'buttons';
  static const String favouritesKey = 'favourites';
  static const String advancedKey = 'advanced';

  Future<SharedPreferences> _prefs() async =>
      _cached ??= _override ?? await SharedPreferences.getInstance();

  Future<bool> seen(String key) async =>
      (await _prefs()).getBool('$_prefix$key') ?? false;

  Future<void> markSeen(String key) async =>
      (await _prefs()).setBool('$_prefix$key', true);

  /// All known tip keys, so [reset] can re-arm every tip.
  static const List<String> allKeys = [
    editorKey,
    gateKey,
    customButtonsKey,
    favouritesKey,
    advancedKey,
  ];

  /// Clears every tip's "seen" flag so they all show again. Wired into
  /// "Re-run the welcome" (ADR 0020) so the whole first-run experience replays.
  Future<void> reset() async {
    final p = await _prefs();
    for (final k in allKeys) {
      await p.remove('$_prefix$k');
    }
  }
}
