/// Regression for review M2: `DeviceInfoSource.read()` must never throw.
///
/// It is awaited on the crash-capture path (`CrashCapture._captureAsync`), so a
/// platform-channel failure here, e.g. `PackageInfo.fromPlatform()` throwing
/// early in startup, would otherwise reject the capture and lose the crash log
/// at the exact moment a crash is happening. The fix makes `read()` total,
/// returning an "unknown" fallback on any failure.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/crash/device_info_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('read() returns a fallback snapshot instead of throwing when the '
      'platform channels are unavailable', () async {
    // No mock handlers are registered, so the package-info channel is unhandled
    // and its call throws (the early-startup / odd-platform case M2 describes).
    // Pre-fix this propagated out of read() and rejected the crash capture.
    final snap = await DeviceInfoSource().read();
    expect(snap.appVersion, 'unknown');
    expect(snap.buildNumber, 'unknown');
    expect(snap.os, 'unknown');
    expect(snap.deviceModel, 'unknown');
  });
}
