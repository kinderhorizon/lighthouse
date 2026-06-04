/// Golden-frame contract for the shipped cold-start artifacts
/// (`assets/cold_start/{en,es,ar}.json`), ported from the offline tool's
/// `tools/cold_start_prior/data/golden.json`.
///
/// The original bug: off-topic tiles glow after a verb (e.g. unrelated tiles
/// shimmer after "Eat"). These frames pin the fix structurally, per locale:
/// after a given previous button, on-topic tiles are reachable (effective
/// `w' >= shimmer`) and grammatically-impossible follow-ons are suppressed
/// (`w' < shimmer`).
///
/// "Effective w'" exactly mirrors the offline `run_golden` / the app's
/// resolution: the artifact's `(prev, cand)` mean when present, else the
/// candidate's board `base_weight`. The threshold (`shimmer = 0.50`) is the
/// offline `SHIMMER_AT_OBS0`.
///
/// The frames are embedded (not read from `tools/`) so the test is
/// self-contained and does not depend on the offline tool being present in a
/// checkout. Keep them in sync with `data/golden.json` if the tool's frames
/// change.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';

/// shimmer threshold at obs 0 == offline SHIMMER_AT_OBS0.
const double _shimmer = 0.50;

class _Frame {
  const _Frame(this.prev, {this.glow = const [], this.suppress = const []});
  final String prev;
  final List<String> glow;
  final List<String> suppress;
}

/// Ported verbatim from tools/cold_start_prior/data/golden.json (frames apply to
/// all three locales; none is locale-scoped).
const List<_Frame> _golden = [
  _Frame(
    'btn_eat',
    glow: ['btn_more', 'btn_food_cookie'],
    suppress: ['btn_happy', 'btn_sad', 'btn_yes', 'btn_no', 'btn_what', 'btn_where'],
  ),
  _Frame(
    'btn_drink',
    glow: ['btn_water'],
    suppress: ['btn_happy', 'btn_what', 'btn_yes'],
  ),
  _Frame(
    'btn_want',
    suppress: ['btn_happy', 'btn_sad', 'btn_yes', 'btn_no', 'btn_thankyou', 'btn_what'],
  ),
  _Frame(
    'btn_i',
    suppress: ['btn_yes', 'btn_no', 'btn_what', 'btn_where'],
  ),
  _Frame(
    'btn_go',
    glow: ['btn_home'],
    suppress: ['btn_happy', 'btn_yes'],
  ),
];

/// Board `base_weight` for every button, the fallback when the artifact has no
/// `(prev, cand)` entry (locale-independent).
Map<String, double> _baseWeights() {
  final out = <String, double>{};
  for (final entry in Directory('boards').listSync()) {
    if (entry is! File || !entry.path.endsWith('.json')) continue;
    final board = jsonDecode(entry.readAsStringSync()) as Map<String, dynamic>;
    for (final b in (board['buttons'] as List).cast<Map<String, dynamic>>()) {
      final w = b['base_weight'];
      if (b['id'] is String && w is num) out[b['id'] as String] = w.toDouble();
    }
  }
  return out;
}

ContextualColdStart _artifact(String locale) {
  final json = jsonDecode(
    File('assets/cold_start/$locale.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return ContextualColdStart.fromArtifactJson(json);
}

AACButton _btn(String id, double baseWeight) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: 'needs',
      baseWeight: baseWeight,
      iconUri: '',
      voiceOut: id,
    );

void main() {
  // rootBundle is the EXACT path contextualColdStartProvider uses at runtime;
  // ensures the three artifacts are actually bundled (pubspec) and loadable, not
  // just present on disk (the File-based golden checks below would still pass
  // even if the asset entry were missing, since the provider fails safe).
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cold-start artifacts are bundled and load via rootBundle', () async {
    for (final locale in ['en', 'es', 'ar']) {
      final raw = await rootBundle.loadString('assets/cold_start/$locale.json');
      final ccs = ContextualColdStart.fromArtifactJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      expect(
        ccs.meanFor(prevKey: 'btn_eat', candidateId: 'btn_more'),
        isNotNull,
        reason: '$locale not bundled or parsed empty via rootBundle',
      );
    }
  });

  final base = _baseWeights();

  // Replicates the offline _effective_w and the app's priorFor input: the
  // artifact mean when present, else the candidate's base_weight.
  double effective(ContextualColdStart ccs, String prev, String cand) =>
      ccs.meanFor(prevKey: prev, candidateId: cand) ?? base[cand] ?? 0.5;

  for (final locale in ['en', 'es', 'ar']) {
    group('golden suppression contract ($locale)', () {
      final ccs = _artifact(locale);

      for (final f in _golden) {
        test('after ${f.prev}: on-topic glows, off-topic suppressed', () {
          for (final cand in f.glow) {
            expect(
              effective(ccs, f.prev, cand),
              greaterThanOrEqualTo(_shimmer),
              reason: '$locale: ${f.prev} -> $cand should be reachable '
                  '(>= shimmer $_shimmer)',
            );
          }
          for (final cand in f.suppress) {
            expect(
              effective(ccs, f.prev, cand),
              lessThan(_shimmer),
              reason: '$locale: ${f.prev} -> $cand must be suppressed '
                  '(< shimmer $_shimmer)',
            );
          }
        });
      }
    });
  }

  test('all shipped locales parse and are non-empty', () {
    for (final locale in ['en', 'es', 'ar']) {
      final ccs = _artifact(locale);
      // btn_eat -> btn_more is a stable, model-independent anchor in every
      // locale; if parsing silently produced an empty map this would be null.
      expect(
        ccs.meanFor(prevKey: 'btn_eat', candidateId: 'btn_more'),
        isNotNull,
        reason: '$locale artifact parsed empty (transitions missing?)',
      );
    }
  });

  // The reported bug: after "want", grammatically-impossible follow-ons
  // (verbs / the pronoun "I") glowed because the POS gate REMOVED them from the
  // artifact and the app fell back to their high base_weight. priorFor must now
  // SUPPRESS a candidate that is absent from a known context row.
  test('POS-gated follow-ons do not glow on base_weight after "want" (en)', () {
    final ccs = _artifact('en');
    const wantKey = 'Morning_Weekday|wifi_UNKNOWN|Prev:btn_want|Context:';
    for (final id in [
      'btn_i', // base 0.7
      'btn_go', // 0.6
      'btn_need', // 0.6
      'btn_get', // 0.5
      'btn_play', // 0.6
      'btn_drink', // 0.6
    ]) {
      // These are genuinely absent from the want row (gated). If a future
      // artifact starts listing them, this assumption is stale.
      expect(
        ccs.meanFor(prevKey: 'btn_want', candidateId: id),
        isNull,
        reason: '$id unexpectedly present in the want row',
      );
      final p = ccs.priorFor(wantKey, _btn(id, base[id] ?? 0.5));
      final mean = p.alpha / (p.alpha + p.beta);
      expect(
        mean,
        lessThan(0.50),
        reason: 'want -> $id must be suppressed, not glow on base ${base[id]}',
      );
    }
  });
}
