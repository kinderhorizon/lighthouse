import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  group('CrashLog whitelist', () {
    final log = CrashLog(
      timestamp: DateTime.utc(2026, 5, 28, 17, 0, 0),
      appVersion: '0.1.0',
      buildNumber: '1',
      os: 'iOS 18.2',
      deviceModel: 'iPad13,16',
      locale: 'en-CA',
      exceptionType: 'StateError',
      exceptionMessage: 'something failed',
      stackTrace: 'at foo\nat bar',
      lastUiRoute: '/grid/core_main',
      isarDbSizeBytes: 12345,
      uniqueContextKeysCount: 67,
      banditStateCorruptionFlag: false,
    );

    test('toJson contains only whitelisted keys', () {
      final json = log.toJson();
      const allowed = {
        'timestamp',
        'app_version',
        'build_number',
        'os',
        'device_model',
        'locale',
        'exception_type',
        'exception_message',
        'stack_trace',
        'last_ui_route',
        'isar_db_size_bytes',
        'unique_context_keys_count',
        'bandit_state_corruption_flag',
      };
      expect(json.keys.toSet().difference(allowed), isEmpty,
          reason:
              'toJson emitted unexpected keys: ${json.keys.toSet().difference(allowed)}');
    });

    test('forbidden communication-content keys never appear', () {
      final json = log.toJson();
      const forbidden = {
        'button_id',
        'button_label',
        'voice_out',
        'board_id',
        'board_contents',
        'wifi_ssid',
        'wifi_hash',
        'location',
        'tap_history',
        'context_key',
        'state_key',
      };
      for (final k in forbidden) {
        expect(json.containsKey(k), isFalse,
            reason: 'forbidden key "$k" leaked into toJson');
      }
    });

    test('JSON encodes and round-trips back via fromJson', () {
      final encoded = jsonEncode(log.toJson());
      final decoded =
          CrashLog.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
      expect(decoded.appVersion, log.appVersion);
      expect(decoded.exceptionType, log.exceptionType);
      expect(decoded.stackTrace, log.stackTrace);
      expect(decoded.isarDbSizeBytes, log.isarDbSizeBytes);
      expect(decoded.uniqueContextKeysCount, log.uniqueContextKeysCount);
      expect(decoded.timestamp.toUtc(), log.timestamp.toUtc());
    });

    test('optional diagnostic fields are omitted when null', () {
      final lite = CrashLog(
        timestamp: DateTime.utc(2026, 5, 28),
        appVersion: '0.1.0',
        buildNumber: '1',
        os: 'iOS',
        deviceModel: 'iPad',
        locale: 'en',
        exceptionType: 'X',
        exceptionMessage: 'y',
        stackTrace: 'z',
      );
      final json = lite.toJson();
      expect(json.containsKey('last_ui_route'), isFalse);
      expect(json.containsKey('isar_db_size_bytes'), isFalse);
      expect(json.containsKey('unique_context_keys_count'), isFalse);
      expect(json['bandit_state_corruption_flag'], isFalse);
    });
  });
}
