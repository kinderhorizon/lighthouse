import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  group('WifiSsidReader (lighthouse/wifi platform channel)', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('lighthouse/wifi');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('invokes getWifiSsid and returns the host SSID', () async {
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return '"HomeNet"';
      });

      expect(await const WifiSsidReader().getWifiSsid(), '"HomeNet"');
      expect(methods, ['getWifiSsid']);
    });

    test('returns null when the host reports no SSID', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await const WifiSsidReader().getWifiSsid(), isNull);
    });
  });

  group('StubWifiSource', () {
    test('returns the configured hash', () async {
      final src = StubWifiSource(fixedHash: 'wifi_HOMEHASH');
      expect(await src.hashOfCurrentSsid(), 'wifi_HOMEHASH');
    });

    test('returns null when not configured', () async {
      expect(await StubWifiSource().hashOfCurrentSsid(), isNull);
    });

    test('hash can be swapped at runtime (simulates user moving '
        'between WiFi networks)', () async {
      final src = StubWifiSource(fixedHash: 'wifi_HOMEHASH');
      expect(await src.hashOfCurrentSsid(), 'wifi_HOMEHASH');
      src.fixedHash = 'wifi_SCHOOLHASH';
      expect(await src.hashOfCurrentSsid(), 'wifi_SCHOOLHASH');
    });

    test('usesWifiContext defaults to true and is configurable', () {
      expect(StubWifiSource().usesWifiContext, isTrue);
      expect(StubWifiSource(usesWifiContext: false).usesWifiContext, isFalse);
    });

    test('requestWifiContextPermission returns the configured outcome and '
        'counts calls (ADR 0016: request is explicit, made once)', () async {
      final granted = StubWifiSource();
      expect(await granted.requestWifiContextPermission(), isTrue);
      expect(granted.requestCount, 1);

      final denied = StubWifiSource(permissionGranted: false);
      expect(await denied.requestWifiContextPermission(), isFalse);
      expect(denied.requestCount, 1);
    });
  });

  // SystemWifiSource exercises the real platform surfaces (location
  // permission + the lighthouse/wifi channel). Covered by integration_test/
  // alongside the Isar tests; not viable under host `flutter test`
  // because the permission plugin requires a live platform binding.
}
