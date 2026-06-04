import 'package:flutter/foundation.dart' show kReleaseMode;

import '../services/feedback/feedback_config.dart';
import '../services/legal/legal_config.dart';
import '../services/ota/ota_config.dart';

/// Compile-time guard that a *release* build was configured with every required
/// backend endpoint: OTA content host (ADR 0017), the feedback relay (ADR
/// 0018), and the privacy-policy link.
///
/// Those three values are `String.fromEnvironment` consts that default to `''`
/// (see `services/ota/ota_config.dart`, `services/feedback/feedback_config.dart`,
/// `services/legal/legal_config.dart`). Each feature dead-UI-gates itself off
/// when its const is empty, so a release build that FORGETS the `--dart-define`s
/// ships SILENTLY DORMANT (no OTA, no feedback, no privacy link) and cannot be
/// fixed without a new app-store submission. This guard converts that silent
/// footgun into a hard build failure.
///
/// Mechanism: a const-constructor `assert`. Const assertions are evaluated at
/// COMPILE time (independent of the runtime `--enable-asserts` flag that strips
/// ordinary asserts from release builds), so a misconfigured release build FAILS
/// TO COMPILE instead of producing a broken binary. It is invocation-independent
/// (even a bare `flutter build ipa --release` with no flags trips it) because
/// the constant is on the compile graph via [releaseEndpointGuard], referenced
/// from `main()`.
///
/// Debug and profile builds are unaffected: `kReleaseMode` is a compile-time
/// const that is `false` there, so the guard short-circuits to satisfied.
///
/// Escape hatch for a deliberately-dormant LOCAL release build (e.g. a perf or
/// size smoke test before the endpoints are settled): pass
/// `--dart-define=ALLOW_UNCONFIGURED_RELEASE=true`. This mirrors the Gradle
/// `-PallowDebugSigningForRelease` opt-in: fail-closed by default, explicit
/// opt-out only, never the happy path.
const bool _allowUnconfigured =
    bool.fromEnvironment('ALLOW_UNCONFIGURED_RELEASE');

class _ReleaseEndpointGuard {
  const _ReleaseEndpointGuard()
      : assert(
          !kReleaseMode ||
              _allowUnconfigured ||
              (kOtaContentBaseUrl != '' &&
                  kFeedbackEndpointUrl != '' &&
                  kLighthousePrivacyPolicyUrl != ''),
          'RELEASE BUILD IS MISCONFIGURED: one or more required endpoint '
          'defines are empty (OTA_BASE_URL / FEEDBACK_URL / '
          'PRIVACY_POLICY_URL). Build the release with '
          '--dart-define-from-file=config/release.json. For a deliberately '
          'dormant local release build, pass '
          '--dart-define=ALLOW_UNCONFIGURED_RELEASE=true.',
        );
}

/// The guard sentinel. Constructing this const triggers the compile-time
/// assertion in [_ReleaseEndpointGuard]. Reference it once from `main()` (a
/// `const _ = releaseEndpointGuard;` wildcard local is enough) so the constant
/// is retained on the build graph. It has no runtime behaviour.
const releaseEndpointGuard = _ReleaseEndpointGuard();
