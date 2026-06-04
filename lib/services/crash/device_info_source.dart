/// Whitelisted device + app metadata for crash logs.
///
/// Reads OS, device model, app version, and build number via
/// device_info_plus + package_info_plus, caches the result for the process
/// lifetime, and exposes a typed snapshot. The class deliberately does NOT
/// expose any of the dozens of other fields those packages return (e.g.,
/// hardware IDs, screen size, advertising IDs); only the ADR 0002 whitelist
/// fields are surfaced.
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfoSnapshot {
  const DeviceInfoSnapshot({
    required this.appVersion,
    required this.buildNumber,
    required this.os,
    required this.deviceModel,
  });

  final String appVersion;
  final String buildNumber;
  final String os;
  final String deviceModel;
}

class DeviceInfoSource {
  DeviceInfoSource({
    DeviceInfoPlugin? deviceInfoPlugin,
    PackageInfo? packageInfoOverride,
  })  : _deviceInfo = deviceInfoPlugin ?? DeviceInfoPlugin(),
        // ignore: prefer_initializing_formals
        _packageInfoOverride = packageInfoOverride;

  final DeviceInfoPlugin _deviceInfo;
  final PackageInfo? _packageInfoOverride;
  DeviceInfoSnapshot? _cached;

  /// Best-effort device snapshot. This MUST NOT throw: it is awaited on the
  /// crash-capture path (`CrashCapture._captureAsync`), so a platform-channel
  /// failure here, e.g. `PackageInfo.fromPlatform()` or `iosInfo` throwing very
  /// early in startup, would otherwise reject the capture and lose the crash log
  /// at the exact moment a crash is happening. On any failure it returns an
  /// "unknown" fallback WITHOUT caching it, so a later call can still populate
  /// real values once the platform is ready.
  Future<DeviceInfoSnapshot> read() async {
    if (_cached != null) return _cached!;
    try {
      final pkg = _packageInfoOverride ?? await PackageInfo.fromPlatform();

      String os = 'unknown';
      String model = 'unknown';
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        os = 'iOS ${info.systemVersion}';
        model = info.utsname.machine.isNotEmpty
            ? info.utsname.machine
            : info.model;
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        os = 'Android ${info.version.release}';
        model = '${info.manufacturer} ${info.model}'.trim();
      } else if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        os = 'macOS ${info.osRelease}';
        model = info.model;
      }

      _cached = DeviceInfoSnapshot(
        appVersion: pkg.version,
        buildNumber: pkg.buildNumber,
        os: os,
        deviceModel: model,
      );
      return _cached!;
    } catch (_) {
      return const DeviceInfoSnapshot(
        appVersion: 'unknown',
        buildNumber: 'unknown',
        os: 'unknown',
        deviceModel: 'unknown',
      );
    }
  }
}
