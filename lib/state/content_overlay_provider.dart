/// Provider for the OTA content overlay store (ADR 0017).
///
/// A single shared instance: the BoardRegistry (and, later, the audio and
/// pictogram resolvers) READ overlaid content through it, while the
/// ContentUpdateService WRITES applied updates through the same instance.
/// Manual Riverpod (no build_runner), like [boardLayoutProvider].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';

final contentOverlayStoreProvider =
    Provider<ContentOverlayStore>((ref) => ContentOverlayStore());
