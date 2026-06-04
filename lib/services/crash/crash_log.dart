/// Crash log data model.
///
/// Every field is on the explicit whitelist from
/// docs/adr/0002-no-automatic-telemetry.md. There is no "extras" map, no
/// untyped key/value store, and no "log additional context" path. If a
/// future contributor wants to log a new field, they must add it here and
/// amend ADR 0002.
///
/// Communication-content fields (button taps, voice-out text, board IDs,
/// WiFi info, location, anything the parent or child typed/selected) are
/// excluded by construction: they do not exist as fields on this class.
///
/// Caveat (privacy copy, ADR 0002): [exceptionMessage] and [stackTrace] are
/// free text from the thrown error. The app does not deliberately put
/// communication content there, but a third-party or framework exception could
/// incidentally embed a string. That is why the in-app copy (howWeKnowBody2) no
/// longer makes an absolute "never any communication content" promise; the real
/// backstop is that the parent previews the exact log and chooses to share it.
library;

import 'dart:convert';

class CrashLog {
  const CrashLog({
    required this.timestamp,
    required this.appVersion,
    required this.buildNumber,
    required this.os,
    required this.deviceModel,
    required this.locale,
    required this.exceptionType,
    required this.exceptionMessage,
    required this.stackTrace,
    this.lastUiRoute,
    this.isarDbSizeBytes,
    this.uniqueContextKeysCount,
    this.banditStateCorruptionFlag = false,
  });

  /// UTC instant when the crash was captured.
  final DateTime timestamp;

  final String appVersion;
  final String buildNumber;

  /// e.g., "iOS 18.2", "Android 14".
  final String os;

  /// e.g., "iPad Air 11-inch (M2)", "SM-X716".
  final String deviceModel;

  /// e.g., "en_CA", "ar_SA".
  final String locale;

  final String exceptionType;
  final String exceptionMessage;
  final String stackTrace;

  /// Last navigation route the UI was on. Routes are app-internal (e.g.,
  /// "/grid/core_main", "/settings"), not communication content.
  final String? lastUiRoute;

  final int? isarDbSizeBytes;
  final int? uniqueContextKeysCount;
  final bool banditStateCorruptionFlag;

  /// JSON encoding. Field order is stable for diff-friendly logs.
  /// New fields MUST also be added to ADR 0002's whitelist.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'app_version': appVersion,
        'build_number': buildNumber,
        'os': os,
        'device_model': deviceModel,
        'locale': locale,
        'exception_type': exceptionType,
        'exception_message': exceptionMessage,
        'stack_trace': stackTrace,
        if (lastUiRoute != null) 'last_ui_route': lastUiRoute,
        if (isarDbSizeBytes != null) 'isar_db_size_bytes': isarDbSizeBytes,
        if (uniqueContextKeysCount != null)
          'unique_context_keys_count': uniqueContextKeysCount,
        'bandit_state_corruption_flag': banditStateCorruptionFlag,
      };

  String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  /// Recreate from JSON. Useful for the "View crash logs" preview UI and
  /// tests, NOT for accepting external input. We do not validate against
  /// the whitelist on read because logs we wrote are the only source.
  factory CrashLog.fromJson(Map<String, dynamic> json) {
    return CrashLog(
      timestamp: DateTime.parse(json['timestamp'] as String),
      appVersion: json['app_version'] as String,
      buildNumber: json['build_number'] as String,
      os: json['os'] as String,
      deviceModel: json['device_model'] as String,
      locale: json['locale'] as String,
      exceptionType: json['exception_type'] as String,
      exceptionMessage: json['exception_message'] as String,
      stackTrace: json['stack_trace'] as String,
      lastUiRoute: json['last_ui_route'] as String?,
      isarDbSizeBytes: (json['isar_db_size_bytes'] as num?)?.toInt(),
      uniqueContextKeysCount:
          (json['unique_context_keys_count'] as num?)?.toInt(),
      banditStateCorruptionFlag:
          json['bandit_state_corruption_flag'] as bool? ?? false,
    );
  }
}
