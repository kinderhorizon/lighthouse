/// Cross-board integrity guards.
///
/// Two invariants that, if broken, cause silent harm rather than a crash:
///
/// 1. Button IDs are globally unique across every board. The contextual
///    bandit keys posteriors on (stateKey, buttonId) and does NOT include
///    board identity (see ADR 0009). Uniqueness is precisely what makes
///    learning board-scoped: a food word's stats can only ever be observed on
///    the food board. Reusing an ID on two boards would bleed one board's
///    learning into the other's glow and actively misguide the child.
///
/// 2. No dead folders. Every folder's link_id must resolve to a board that is
///    both registered in BoardRegistry and present on disk. A tap-to-nowhere
///    is a broken utterance for a non-speaking child.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  final boards = <String, Map<String, dynamic>>{};
  for (final f in (Directory('boards').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      .where((f) => f.path.endsWith('.json'))) {
    final b = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    boards[b['board_id'] as String] = b;
  }

  test('at least the home board plus sub-boards are present', () {
    expect(boards.containsKey('core_main'), isTrue);
    expect(boards.length, greaterThan(1));
  });

  test('button IDs are globally unique across all boards (bandit invariant)',
      () {
    final idToBoard = <String, String>{};
    final dupes = <String>[];
    for (final entry in boards.entries) {
      for (final btn
          in (entry.value['buttons'] as List).cast<Map<String, dynamic>>()) {
        final id = btn['id'] as String;
        final prior = idToBoard[id];
        if (prior != null) {
          dupes.add('$id (in $prior and ${entry.key})');
        } else {
          idToBoard[id] = entry.key;
        }
      }
    }
    expect(dupes, isEmpty,
        reason: 'duplicate button IDs would bleed bandit learning across '
            'boards: $dupes');
  });

  test('buttons fill the grid row-major with no empty interior columns', () {
    // Bug guard: a board can declare an 8-column grid but only lay its buttons
    // out 6-wide, leaving columns 6-7 empty on every row (the renderer draws
    // gridDimensions.cols regardless, so the right edge shows blank tiles).
    // Enforce contiguous row-major packing: the set of occupied (row, col)
    // cells must equal exactly the first N cells in row-major order, where
    // N is the button count. This permits a partial final row but forbids a
    // fully-empty column to the right of occupied ones.
    final offenders = <String>[];
    for (final entry in boards.entries) {
      final btns = (entry.value['buttons'] as List).cast<Map<String, dynamic>>();
      final cols = (entry.value['grid_dimensions'] as List)[1] as int;
      final occupied = <int>{};
      for (final btn in btns) {
        final pos = btn['position'] as Map<String, dynamic>;
        occupied.add((pos['row'] as int) * cols + (pos['col'] as int));
      }
      final expected = {for (var i = 0; i < btns.length; i++) i};
      // Set equality is content-based here: equal sizes + containsAll. (Dart's
      // default Set `==` is reference identity, so do not use it.)
      if (occupied.length != btns.length || !occupied.containsAll(expected)) {
        offenders.add('${entry.key} (cols=$cols, ${btns.length} buttons)');
      }
    }
    expect(offenders, isEmpty,
        reason: 'boards with non-contiguous / non-row-major layout (empty '
            'interior columns): $offenders');
  });

  test('every folder link_id resolves to a registered board on disk', () {
    final reg = BoardRegistry();
    final dead = <String>[];
    for (final entry in boards.entries) {
      for (final btn
          in (entry.value['buttons'] as List).cast<Map<String, dynamic>>()) {
        if (btn['type'] != 'folder') continue;
        final link = btn['link_id'] as String?;
        if (link == null || !reg.knows(link) || !boards.containsKey(link)) {
          dead.add('${entry.key}/${btn['id']} -> $link');
        }
      }
    }
    expect(dead, isEmpty, reason: 'dead folders (tap-to-nowhere): $dead');
  });

  test('every semantic-boost target category exists on some board', () {
    // ADR 0011: after a verb, the matching object words/folder glow gold. The
    // boost keys on board `category` values, so a target that no button uses is
    // a silently-dead boost (this caught btn_play -> "activities" when the
    // Activities items use the singular "activity").
    final allCategories = <String>{
      for (final b in boards.values)
        for (final btn in (b['buttons'] as List).cast<Map<String, dynamic>>())
          btn['category'] as String,
    };
    final missing = <String>[];
    for (final entry in kVerbObjectBoosts.entries) {
      for (final cat in entry.value) {
        if (!allCategories.contains(cat)) {
          missing.add('${entry.key} -> "$cat"');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'boost target categories absent from every board (dead '
            'boost): $missing');
  });

  test('glow grammar tables key on real, locale-independent ids/categories',
      () {
    // The post-verb suppression (clinical review) works for en/es/ar and any
    // future language ONLY because it keys on button ids + categories, which
    // are identical across locales (ADR 0008 localizes label/voice_out only).
    // This guard fails if a referenced id/category stops existing, which would
    // silently disable the rule in every language at once.
    final allIds = <String>{
      for (final b in boards.values)
        for (final btn in (b['buttons'] as List).cast<Map<String, dynamic>>())
          btn['id'] as String,
    };
    final allCategories = <String>{
      for (final b in boards.values)
        for (final btn in (b['buttons'] as List).cast<Map<String, dynamic>>())
          btn['category'] as String,
    };

    final missingVerbs =
        kTransitiveVerbs.where((id) => !allIds.contains(id)).toList();
    expect(missingVerbs, isEmpty,
        reason: 'transitive-verb ids not on any board: $missingVerbs');

    final missingCats = kPostVerbSuppressedCategories
        .where((c) => !allCategories.contains(c))
        .toList();
    expect(missingCats, isEmpty,
        reason: 'suppressed categories on no board: $missingCats');
  });

  test('every favouritable category has a color in some board key (QA B1)', () {
    // A favourite is colored against the merged color_key of all boards
    // (main.dart _BoardView). If a word's category exists on no board's
    // color_key, a pinned favourite of it renders grey, which is exactly the
    // bug the clinical lead reported for Activities/Body/Time words.
    final unionColors = <String>{
      for (final b in boards.values)
        ...(b['color_key'] as Map).keys.cast<String>(),
    };
    final uncolored = <String>{};
    for (final b in boards.values) {
      for (final btn in (b['buttons'] as List).cast<Map<String, dynamic>>()) {
        if (btn['type'] == 'folder') continue; // folders are not favouritable
        final cat = btn['category'] as String;
        if (!unionColors.contains(cat)) uncolored.add(cat);
      }
    }
    expect(uncolored, isEmpty,
        reason: 'word categories with no color on any board (favourites would '
            'render grey): $uncolored');
  });
}
