/// Provider for the hosted privacy-policy URL.
///
/// Defaults to the compile-time const `kLighthousePrivacyPolicyUrl` (empty
/// until the launch build sets `PRIVACY_POLICY_URL`), so production behaviour
/// and the dead-UI gate are unchanged. Exists as a provider so a test can
/// override it to exercise the configured-on state without a build-time
/// define. Manual Riverpod (no build_runner), matching the feedback/OTA
/// providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';

final privacyPolicyUrlProvider =
    Provider<String>((ref) => kLighthousePrivacyPolicyUrl);
