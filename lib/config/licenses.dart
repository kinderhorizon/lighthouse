/// Registers the non-package license texts so they appear on the in-app
/// "Open-source licences" page (Flutter's `showLicensePage`, opened from the
/// About screen).
///
/// `showLicensePage` already auto-aggregates every Dart/Flutter PACKAGE license
/// (flutter, isar_community (Apache-2.0), flutter_riverpod, flutter_tts,
/// share_plus, path_provider, record, just_audio, ...). The three entries added
/// here are the things package metadata does NOT cover: the two bundled fonts
/// (SIL Open Font License) and the build-time Google Cloud Text-to-Speech audio
/// provenance notice.
///
/// Every body is loaded from a BUNDLED ASSET (the OFL files, and the provider
/// notice inside the audio manifest) rather than hardcoded, so the displayed
/// text stays in sync with the source of truth.
///
/// The ARASAAC pictogram attribution is deliberately NOT added here: its
/// CC BY-NC-SA credit is shown verbatim and always-visible on the About screen
/// (ADR 0001), so duplicating it on the licence page would be redundant.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;

/// Call once at startup, before `runApp`. The collector is invoked lazily (only
/// when the licence page is opened), so registering early is cheap.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(_bundledLicenses);
}

Stream<LicenseEntryWithLineBreaks> _bundledLicenses() async* {
  // Bundled fonts (SIL OFL): the OFL text is the licence body verbatim.
  yield LicenseEntryWithLineBreaks(
    const ['Atkinson Hyperlegible'],
    await rootBundle.loadString('LICENSES/AtkinsonHyperlegible-OFL.txt'),
  );
  yield LicenseEntryWithLineBreaks(
    const ['Cairo'],
    await rootBundle.loadString('LICENSES/Cairo-OFL.txt'),
  );

  // Google Cloud Text-to-Speech: the provenance/licence note lives in the audio
  // manifest (single source of truth, kept beside the clips it describes).
  final body = await _gcpTtsNotice();
  if (body != null) {
    yield LicenseEntryWithLineBreaks(
      const ['Google Cloud Text-to-Speech'],
      body,
    );
  }
}

Future<String?> _gcpTtsNotice() async {
  try {
    final raw = await rootBundle.loadString('assets/audio/manifest.json');
    final manifest = jsonDecode(raw) as Map<String, dynamic>;
    final provider = manifest['provider'];
    if (provider is! Map) return null;
    final name = provider['name'] as String? ?? 'Google Cloud Text-to-Speech';
    final license = provider['license'] as String?;
    final url = provider['url'] as String?;
    if (license == null) return null;
    return [name, '', license, if (url != null) ...['', url]].join('\n');
  } catch (_) {
    // A missing/malformed manifest just omits this one entry; the fonts and the
    // auto-collected package licences still render.
    return null;
  }
}
