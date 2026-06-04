/// WiFi provider.
///
/// Exposes a [WifiSource] backed by the real platform plugin in
/// production. Tests override with a [StubWifiSource] so they don't
/// touch the platform.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';

part 'wifi_provider.g.dart';

@Riverpod(keepAlive: true)
WifiSource wifiSource(WifiSourceRef ref) => SystemWifiSource();
