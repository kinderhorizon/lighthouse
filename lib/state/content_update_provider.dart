/// Provider for the OTA content update service (ADR 0017).
///
/// Async because it reads the app version (package_info) for the minAppVersion
/// compatibility check. Wires the compile-time config (endpoint + trust-list),
/// the one shared overlay store (so what this WRITES is what the board/audio
/// resolvers READ), and the HTTPS-only client. Manual Riverpod (no build_runner).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/services.dart';
import 'content_overlay_provider.dart';

final contentUpdateServiceProvider =
    FutureProvider<ContentUpdateService>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return ContentUpdateService(
    baseUrl: kOtaContentBaseUrl,
    // appVersion = marketing version, used for the minAppVersion compat check
    // and for the wire header. appBuild = build number, used ONLY for the local
    // ADR 0021 targetVersion gate and NEVER sent on the wire, so the HTTP client
    // keeps receiving the marketing version alone (HIGH-1).
    appVersion: info.version,
    appBuild: info.buildNumber,
    httpClient: HttpContentClient(appVersion: info.version),
    store: ref.watch(contentOverlayStoreProvider),
    verifier: ManifestSignatureVerifier(
      trustedPublicKeysBase64: kOtaTrustedPublicKeys,
    ),
  );
});
