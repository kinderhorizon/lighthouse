/// WiFi source.
///
/// Returns a SHA-256-derived hash of the current WiFi SSID, or null when the
/// SSID is unavailable (permission not granted, no WiFi, on cellular, platform
/// unsupported, etc.). The ContextManager treats null as "wifi_UNKNOWN", so the
/// bandit runs fully without Wi-Fi context: it is one dimension of many, never a
/// hard dependency.
///
/// Two invariants from ADR 0016:
///   - Read is READ-ONLY: [hashOfCurrentSsid] never requests a permission, so a
///     child's tap can never trigger an OS Location dialog. The permission is
///     requested once, explicitly, from the onboarding Wi-Fi-context step via
///     [requestWifiContextPermission].
///   - iOS does NOT use Wi-Fi context. Reading the SSID on iOS needs the
///     com.apple.developer.networking.wifi-info entitlement, which Lighthouse
///     deliberately does not ship, so the read is null regardless and we never
///     raise an alarming Location prompt for zero benefit. [usesWifiContext] is
///     therefore Android-only.
///
/// The raw SSID never leaves [hashOfCurrentSsid]. We hash it before returning
/// and discard the input. A future code reviewer cannot accidentally log the
/// SSID by adding a `print(rawSsid)` line, because the raw value is never bound
/// to a name long enough to log.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Abstract surface so tests can inject a fake.
abstract class WifiSource {
  /// Whether this platform reads Wi-Fi context at all. False on iOS (no
  /// wifi-info entitlement shipped, ADR 0016) and on desktop/web. When false,
  /// the bandit runs on `wifi_UNKNOWN` and no Location permission is ever
  /// requested.
  bool get usesWifiContext;

  /// Returns the hash-prefixed SSID for the bandit context, or null if
  /// unavailable / not (yet) permitted. READ-ONLY: never triggers a permission
  /// prompt. Implementations should NOT throw on the routine "no SSID" case.
  Future<String?> hashOfCurrentSsid();

  /// Explicitly requests the permission needed to read Wi-Fi context, from the
  /// deliberate parent-facing onboarding step (ADR 0016) and nowhere else.
  /// Returns whether context reads are now permitted. No-op (returns false) on
  /// platforms where [usesWifiContext] is false.
  Future<bool> requestWifiContextPermission();
}

class SystemWifiSource implements WifiSource {
  SystemWifiSource({
    WifiSsidReader? ssidReader,
    PermissionHandlerPlatformWrapper? permissions,
  })  : _ssid = ssidReader ?? const WifiSsidReader(),
        _permissions = permissions ?? const PermissionHandlerPlatformWrapper();

  final WifiSsidReader _ssid;
  final PermissionHandlerPlatformWrapper _permissions;

  /// Hash prefix length kept short (12 hex chars) so it's compact in state keys
  /// + crash diagnostics while still effectively unique per SSID. We do NOT need
  /// cryptographic collision resistance here; it's an opaque label for the
  /// bandit's context.
  static const int _hashPrefixHexLength = 12;

  static const String _hashPrefix = 'wifi_';

  /// Only Android reads Wi-Fi context (ADR 0016). iOS is deliberately excluded:
  /// the SSID read is an Android-only platform channel with no iOS handler
  /// registered, so the iOS binary links no Wi-Fi/CoreLocation symbol at all
  /// (which is what lets us ship no iOS location disclosure). Even if it were
  /// wired, iOS needs the com.apple.developer.networking.wifi-info entitlement,
  /// which we do not ship, so requesting Location would be all cost, no benefit.
  @override
  bool get usesWifiContext => Platform.isAndroid;

  @override
  Future<String?> hashOfCurrentSsid() async {
    // READ-ONLY (ADR 0016): never requests permission, so a child's tap can
    // never trigger an OS Location dialog. The request is made once, explicitly,
    // from the onboarding Wi-Fi-context step. Not granted / unsupported / no
    // SSID all return null, and the bandit uses wifi_UNKNOWN.
    if (!usesWifiContext) return null;
    try {
      final status = await _permissions.statusOf(Permission.locationWhenInUse);
      if (status != PermissionStatus.granted) return null;

      // The Android platform channel returns the literal SSID where available.
      // The WiFi name is gated behind ACCESS_FINE_LOCATION (the precise-location
      // permission), which is required by current Android APIs for this read;
      // it is granted above. (Android 13+ NEARBY_WIFI_DEVICES could read Wi-Fi
      // info without Location and let us drop that permission later; see ADR
      // 0016.)
      final raw = await _ssid.getWifiSsid();
      if (raw == null || raw.isEmpty) return null;

      // Strip iOS-style surrounding quotes if present (`"MySSID"` -> `MySSID`).
      final normalized = raw.startsWith('"') && raw.endsWith('"')
          ? raw.substring(1, raw.length - 1)
          : raw;
      if (normalized.isEmpty || normalized == '<unknown ssid>') {
        return null;
      }

      final digest = sha256.convert(utf8.encode(normalized)).toString();
      return '$_hashPrefix${digest.substring(0, _hashPrefixHexLength)}';
    } catch (_) {
      // Plugin can throw on platforms that don't support the API at all
      // (web/desktop in tests). Treat as "no SSID available".
      return null;
    }
  }

  @override
  Future<bool> requestWifiContextPermission() async {
    if (!usesWifiContext) return false;
    final status = await _permissions.statusOf(Permission.locationWhenInUse);
    if (status == PermissionStatus.granted) return true;
    if (status == PermissionStatus.permanentlyDenied) return false;
    final requested =
        await _permissions.requestOf(Permission.locationWhenInUse);
    return requested == PermissionStatus.granted;
  }
}

/// Thin injectable seam around the Android platform channel that reads the raw
/// Wi-Fi SSID. Replaces `network_info_plus`, which linked iOS CoreLocation for
/// `getWifiName()` and tripped Apple's location static-analysis even though iOS
/// never called it (ADR 0016).
///
/// The channel handler is implemented in the Android host only
/// (`MainActivity.kt`, via `WifiManager`, gated by `ACCESS_FINE_LOCATION`).
/// NO iOS handler is registered, so the iOS binary contains no Wi-Fi or
/// CoreLocation reference. The Dart call site is Android-only ([usesWifiContext]
/// is `Platform.isAndroid`), so this is never invoked on iOS regardless.
class WifiSsidReader {
  const WifiSsidReader();

  /// Must match the channel name registered in `MainActivity.kt`.
  static const MethodChannel _channel = MethodChannel('lighthouse/wifi');

  /// Returns the raw SSID (possibly surrounded by quotes, as the platform
  /// reports it), or null when unavailable. The caller hashes and discards it.
  Future<String?> getWifiSsid() => _channel.invokeMethod<String>('getWifiSsid');
}

/// Thin seam around `package:permission_handler` so tests can stub it.
/// The package exposes static globals which are awkward to mock; this
/// wrapper makes them injectable.
class PermissionHandlerPlatformWrapper {
  const PermissionHandlerPlatformWrapper();

  Future<PermissionStatus> statusOf(Permission p) => p.status;
  Future<PermissionStatus> requestOf(Permission p) => p.request();
}

/// In-memory implementation for tests and for the host runtime.
class StubWifiSource implements WifiSource {
  StubWifiSource({
    this.fixedHash,
    this.usesWifiContext = true,
    this.permissionGranted = true,
  });

  String? fixedHash;

  @override
  bool usesWifiContext;

  /// What [requestWifiContextPermission] resolves to.
  bool permissionGranted;

  /// Number of times [requestWifiContextPermission] was called, so tests can
  /// assert the request happens exactly once, at onboarding.
  int requestCount = 0;

  @override
  Future<String?> hashOfCurrentSsid() async => fixedHash;

  @override
  Future<bool> requestWifiContextPermission() async {
    requestCount++;
    return permissionGranted;
  }
}
