/// ARASAAC symbol vendoring tool.
///
/// Reads boards/core_main.json, resolves each button to an ARASAAC
/// pictogram id (via search by keyword, with manual overrides for the
/// ambiguous cases), downloads the PNG into the location named by the
/// button's icon_uri, and updates assets/arasaac/manifest.json with the
/// arasaac_id + English label + Fitzgerald category + SHA-256 per entry.
///
/// Run from the repo root:
///   dart run tools/fetch_symbols.dart            # only fetches missing
///   dart run tools/fetch_symbols.dart --force    # re-fetches all
///
/// Network: hits https://api.arasaac.org. Auth: none. Rate: best-effort
/// 200 ms between requests to be polite to a public nonprofit API.
///
/// See ADR 0001 (asset licensing) and the manifest's checksum_policy
/// block for the integrity model.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

const String _searchBase = 'https://api.arasaac.org/api/pictograms/en/search';
const String _fetchBase = 'https://api.arasaac.org/api/pictograms';

/// Per-button keyword overrides where the English label gives a poor or
/// ambiguous ARASAAC match. Add to this map as we observe results.
const Map<String, String> _keywordOverrides = {
  'btn_i': 'I',
  'btn_you': 'you',
  'btn_bathroom': 'toilet',
  'btn_all_done': 'finished',
  'btn_thankyou': 'thank you',
  'btn_hurt': 'pain',
  'btn_food_folder': 'food',
  'btn_places_folder': 'place',
  'btn_people_folder': 'people',
  'btn_activities_folder': 'activity',
  'btn_things_folder': 'object',
  'btn_feelings_folder': 'emotion',
  'btn_questions_folder': 'question',
  'btn_time_folder': 'time',
  // Sub-board words whose label gives a poor/empty ARASAAC match.
  'btn_feel_frustrated': 'annoyed',
  'btn_things_crayon': 'crayons',
};

/// Hard pictogram id overrides for cases where keyword search returns a
/// pictogram that does not match the AAC convention. Populated after a
/// first run + visual review. Keep this list short; the search is
/// usually adequate.
const Map<String, int> _pictogramIdOverrides = {
  // Wrong-sense fixes confirmed by visually inspecting ARASAAC candidates
  // (keyword search returned the wrong meaning). See docs/adr/0009.
  'btn_food_cracker': 3331, // edible cracker, not a party/firework cracker
  'btn_food_cereal': 2328, // breakfast cereal box + glass, not raw grain stalks
  'btn_food_rice': 39387, // bowl of cooked rice, not the rice plant
  'btn_food_ice_cream': 2420, // ice cream cone (helado), not an ice cube
  'btn_places_park': 28263, // green-space park, not a parking lot
  'btn_places_pool': 30516, // swimming pool, not a billiards table
  'btn_places_doctor': 3116, // clinic building (relabelled "Doctor's office")
  'btn_things_shoes': 2622, // plain shoes, not women's high heels
  'btn_people_nurse': 31390, // nurse in uniform, not a figure with a pen
  'btn_people_aunt': 30271, // distinct (female) family figure
  'btn_people_uncle': 30255, // distinct (male) family figure
  'btn_time_weekend': 37371, // calendar without baked-in Spanish day letters
  'btn_act_watch': 16905, // person watching TV (relabelled "Watch TV")
  'btn_where': 11603, // "where" = house + question mark, not a red X
  'btn_here': 5382, // "here" = down-arrow to a spot, not a dotted grid
  'btn_that': 6906, // "that" = arrow pointing at an object
  'btn_body_toe': 26035, // "toe" = foot showing toes, not a tic-tac-toe grid
  // Minor-list re-audit fixes (semantic overlap / weak symbol).
  'btn_body_hand': 2928, // plain open hand, not the give/offer hand passing a ball
  'btn_places_kitchen': 33070, // full kitchen room scene, not a bare cooktop
  'btn_feel_okay': 31410, // OK ring gesture, distinct from Like's thumbs-up
  'btn_places_gym': 36397, // gym building/interior scene, not a lone dumbbell
  // ARASAAC has no dedicated "frustrated" face (all map to the Angry image).
  // Use the crossed-arms exasperated figure so Frustrated is not pixel-identical
  // to Angry (both were 35539). Distinct posture, same emotion family.
  'btn_feel_frustrated': 21820,
  // "I need a break" (clinical review): a reclining/resting figure. The "break"
  // keyword returns wrong senses (snap/smash/break wind), so this is an
  // override picked by visually reviewing candidates: 16643 = "rest / have a
  // rest" (person relaxing), the clear AAC sense of taking a break.
  'btn_break': 16643,
};

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final repoRoot = Directory.current.path;

  // Iterate EVERY board under boards/, not just core_main, so sub-board
  // pictograms vendor in the same pass. Button icon_uris are unique across
  // boards (each category has its own subdir), so no dedup is needed.
  final boardsDir = Directory('$repoRoot/boards');
  final boardFiles = boardsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final buttons = <Map<String, dynamic>>[];
  for (final f in boardFiles) {
    final board = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    buttons.addAll((board['buttons'] as List).cast<Map<String, dynamic>>());
  }

  final manifestPath = '$repoRoot/assets/arasaac/manifest.json';
  final manifest = jsonDecode(
    File(manifestPath).readAsStringSync(),
  ) as Map<String, dynamic>;
  final symbols = <Map<String, dynamic>>[];

  // Prior provenance, keyed by icon_uri. Real recorded ids (e.g. the verified
  // core board) are carried forward on skip; entries with a missing/zero id
  // (the sub-boards, whose ids were never recorded) fall through to a re-resolve
  // so provenance gets backfilled. Required for ADR 0001 attribution.
  final oldByUri = <String, Map<String, dynamic>>{
    for (final s in (manifest['symbols'] as List? ?? const [])
        .cast<Map<String, dynamic>>())
      s['icon_uri'] as String: s,
  };

  final client = http.Client();
  try {
    var fetched = 0;
    var skipped = 0;
    var failed = 0;

    for (final btn in buttons) {
      final id = btn['id'] as String;
      final label = btn['label'] as String;
      final category = btn['category'] as String;
      final iconUri = btn['icon_uri'] as String;
      final outFile = File('$repoRoot/$iconUri');

      if (outFile.existsSync() && !force) {
        final prior = oldByUri[iconUri];
        final priorId = prior?['arasaac_id'];
        // Carry forward only when real provenance exists (and no override now
        // points elsewhere). Otherwise fall through to re-resolve + re-download
        // so the file matches a recorded id (backfill + apply id overrides).
        if (priorId is int &&
            priorId > 0 &&
            !_pictogramIdOverrides.containsKey(id)) {
          symbols.add(_entryFor(id, label, category, iconUri,
              arasaacId: priorId,
              sha: await _sha256OfFile(outFile),
              keyword: prior?['arasaac_search_keyword'] as String?));
          skipped++;
          continue;
        }
      }

      final keyword =
          _keywordOverrides[id] ?? label.toLowerCase().split(' ').first;

      stdout.writeln(
        '[$id] searching "$keyword" -> ${iconUri.split('/').last} ...',
      );

      int? pictogramId = _pictogramIdOverrides[id];
      pictogramId ??= await _searchFirstId(client, keyword);
      if (pictogramId == null) {
        stderr.writeln('  ! no result for "$keyword" ($id)');
        failed++;
        continue;
      }

      final imgBytes = await _fetchPng(client, pictogramId);
      if (imgBytes == null) {
        stderr.writeln('  ! could not download id=$pictogramId for $id');
        failed++;
        continue;
      }

      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(imgBytes, flush: true);
      final sha = sha256.convert(imgBytes).toString();

      symbols.add(_entryFor(id, label, category, iconUri,
          arasaacId: pictogramId, sha: sha, keyword: keyword));
      stdout.writeln('  -> id=$pictogramId  ${imgBytes.length} bytes');
      fetched++;

      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    manifest['symbols'] = symbols;
    File(manifestPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );

    stdout.writeln('---');
    stdout.writeln('fetched: $fetched   skipped: $skipped   failed: $failed');
    if (failed > 0) {
      exit(1);
    }
  } finally {
    client.close();
  }
}

Future<int?> _searchFirstId(http.Client client, String keyword) async {
  final url = '$_searchBase/${Uri.encodeComponent(keyword)}';
  final res = await client.get(Uri.parse(url));
  if (res.statusCode != 200) {
    stderr.writeln('  ! search HTTP ${res.statusCode} for "$keyword"');
    return null;
  }
  final body = jsonDecode(res.body);
  if (body is! List || body.isEmpty) return null;

  // Filter out content the AAC clinical population should not see.
  for (final entry in body) {
    if (entry is! Map<String, dynamic>) continue;
    if (entry['sex'] == true) continue;
    if (entry['violence'] == true) continue;
    final id = entry['_id'];
    if (id is int) return id;
  }
  return null;
}

Future<List<int>?> _fetchPng(http.Client client, int pictogramId) async {
  final url = '$_fetchBase/$pictogramId';
  final res = await client.get(Uri.parse(url));
  if (res.statusCode != 200) {
    stderr.writeln('  ! fetch HTTP ${res.statusCode} for id=$pictogramId');
    return null;
  }
  return res.bodyBytes;
}

Future<String> _sha256OfFile(File f) async {
  final bytes = await f.readAsBytes();
  return sha256.convert(bytes).toString();
}

Map<String, dynamic> _entryFor(
  String btnId,
  String label,
  String category,
  String iconUri, {
  required int arasaacId,
  required String sha,
  String? keyword,
}) {
  return {
    'button_id': btnId,
    'english_label': label,
    'fitzgerald_category': category,
    'icon_uri': iconUri,
    'arasaac_id': arasaacId,
    if (keyword != null) 'arasaac_search_keyword': keyword,
    'sha256': sha,
  };
}
