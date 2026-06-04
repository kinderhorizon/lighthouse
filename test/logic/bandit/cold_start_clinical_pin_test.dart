/// App-CI guard for clinical overrides pinned into the shipped cold-start
/// artifacts (`assets/cold_start/*.json`).
///
/// The offline tool's `must_gold` golden frame protects the BUILD; this guards
/// the SHIPPED asset, so a future stale or unpinned refresh is caught app-side
/// (the asset is what the app actually loads).
///
/// `want -> bathroom`: the LM rates it ~0.67 ("want to GO to the bathroom" in
/// general text), so it ranked too low to glow; clinically it is a top child
/// "want" (BCBA), pinned to 0.95. Asserted via `meanFor` + non-null on
/// purpose: bathroom's `base_weight` (0.8) would mask a dropped pin under a
/// base_weight fallback, so we require the EXPLICIT pinned entry to survive.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';

ContextualColdStart _artifact(String locale) =>
    ContextualColdStart.fromArtifactJson(
      jsonDecode(File('assets/cold_start/$locale.json').readAsStringSync())
          as Map<String, dynamic>,
    );

void main() {
  test('clinical pin: want -> bathroom glows gold in every locale', () {
    for (final locale in ['en', 'es', 'ar']) {
      final w = _artifact(locale)
          .meanFor(prevKey: 'btn_want', candidateId: 'btn_bathroom');
      expect(w, isNotNull,
          reason: '$locale: want->bathroom pin missing from the artifact');
      expect(
        w,
        greaterThanOrEqualTo(0.75),
        reason: '$locale: want->bathroom must stay gold (BCBA '
            'clinical pin); refresh assets/cold_start from the pinned tool out/',
      );
    }
  });

  // clinical review cold-start pins. The fresh-start glow (no previous word, the
  // `_NONE` row) must surface useful first words, not sad/drink/here. With a
  // _NONE row present, a candidate that is NOT listed is capped below the glow
  // floor, so the row both promotes the good words and excludes the rest.
  group('clinical review: fresh-start (_NONE) glow set', () {
    const wanted = ['btn_want', 'btn_bathroom', 'btn_break', 'btn_water'];
    const excluded = ['btn_sad', 'btn_drink', 'btn_here'];
    for (final locale in ['en', 'es', 'ar']) {
      test('$locale promotes useful words, excludes sad/drink/here', () {
        final a = _artifact(locale);
        for (final id in wanted) {
          final w = a.meanFor(prevKey: '_NONE', candidateId: id);
          expect(w, isNotNull, reason: '$locale: _NONE missing $id');
          expect(w, greaterThanOrEqualTo(0.5),
              reason: '$locale: $id must be glow-eligible at fresh start');
        }
        for (final id in excluded) {
          expect(a.meanFor(prevKey: '_NONE', candidateId: id), isNull,
              reason: '$locale: $id must NOT be in the fresh-start glow set '
                  '(absent -> capped below the glow floor)');
        }
      });
    }
  });

  // After a pronoun ("I"), the useful verbs must glow. "want" was missing from
  // the table (so it never glowed) and "eat" sat below the floor; both are now
  // pinned glow-eligible in every locale.
  group('clinical review: after "I", want + eat glow', () {
    for (final locale in ['en', 'es', 'ar']) {
      test(locale, () {
        final a = _artifact(locale);
        for (final id in ['btn_want', 'btn_eat']) {
          final w = a.meanFor(prevKey: 'btn_i', candidateId: id);
          expect(w, isNotNull, reason: '$locale: btn_i->$id missing');
          expect(w, greaterThanOrEqualTo(0.5),
              reason: '$locale: btn_i->$id must be glow-eligible');
        }
      });
    }
  });
}
