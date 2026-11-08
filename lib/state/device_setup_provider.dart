/// Copying a child's whole setup to another device (ADR 0023).
///
/// Manual Riverpod API (like [boardLayoutProvider]) so it needs no
/// build_runner pass.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';
import 'board_layout_provider.dart';
import 'board_stack.dart';
import 'custom_button_provider.dart';
import 'custom_voice_provider.dart';
import 'favourites_provider.dart';
import 'hidden_tiles_provider.dart';
import 'icon_override_provider.dart';
import 'settings_provider.dart';

final deviceSetupServiceProvider = Provider<DeviceSetupService>(
  (ref) => DeviceSetupService(
    customButtons: ref.read(customButtonStoreProvider),
    layout: ref.read(boardLayoutStoreProvider),
    hidden: ref.read(hiddenTilesStoreProvider),
    favourites: ref.read(favouritesStoreProvider),
    icons: ref.read(iconOverrideStoreProvider),
    voices: ref.read(customVoiceStoreProvider),
    settings: ref.read(settingsRepositoryProvider),
  ),
);

/// Puts [setup] in place of this device's setup, then reloads everything that
/// shows it, and takes the child's view back to Home (the page it was on may
/// be gone). Throws what [DeviceSetupService.apply] throws.
Future<void> applyDeviceSetup(WidgetRef ref, DeviceSetup setup) async {
  final registry = await ref.read(boardRegistryProvider.future);
  try {
    await ref.read(deviceSetupServiceProvider).apply(setup, registry);
  } finally {
    // Reload even after a failure part-way: the screens must show what is
    // actually stored now.
    ref
      ..invalidate(customButtonsProvider)
      ..invalidate(boardLayoutProvider)
      ..invalidate(hiddenTilesProvider)
      ..invalidate(favouritesProvider)
      ..invalidate(iconOverridesProvider)
      ..invalidate(customVoiceProvider)
      ..invalidate(settingsNotifierProvider)
      ..invalidate(editableBoardsProvider);
    ref.read(boardStackProvider.notifier).resetToRoot();
  }
}
