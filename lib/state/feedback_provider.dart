/// Provider for the in-app feedback client (ADR 0018).
///
/// Wires the compile-time endpoint (empty until the Azure Function is deployed,
/// so the client returns `notConfigured`). Manual Riverpod (no build_runner),
/// matching the OTA providers. The screen gathers app/OS version at Send time;
/// this provider holds only the transport.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';

final feedbackClientProvider = Provider<FeedbackClient>((ref) {
  return FeedbackClient(endpointUrl: kFeedbackEndpointUrl);
});
