/// Switch Access State & Scanning Provider.
///
/// Implements clinical scanning controllers for single-switch (automatic
/// scan with configurable dwell time: 500ms-2000ms) and dual-switch (step & select)
/// motor-accessible navigation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'settings_provider.dart';

/// Currently focused button index on the active AAC board.
final switchFocusIndexProvider = StateProvider<int>((ref) => 0);

/// Whether the automatic scanning timer is actively stepping.
final switchScanningActiveProvider = StateProvider<bool>((ref) => false);

/// Convenient derived provider for whether any switch access mode is active.
final isSwitchAccessEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider).valueOrNull;
  if (settings == null) return false;
  return settings.accessMethod == AccessMethod.switchSingle ||
      settings.accessMethod == AccessMethod.switchDual;
});
