/// Crash capture wiring.
///
/// Catches three classes of errors:
/// 1. Synchronous framework errors via [FlutterError.onError].
/// 2. Async + platform-channel errors via [PlatformDispatcher.instance.onError].
/// 3. Anything else thrown inside the zone via [runZonedGuarded] in main().
///
/// Each captured error is whitelisted through [CrashLog] and persisted via
/// [CrashLogStore]. No network calls, no third-party SDK. See ADR 0002.
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'crash_log.dart';
import 'crash_log_store.dart';
import 'device_info_source.dart';

class CrashCapture {
  CrashCapture({
    required CrashLogStore store,
    required DeviceInfoSource deviceInfoSource,
  })  : _store = store,
        _deviceInfo = deviceInfoSource;

  final CrashLogStore _store;
  final DeviceInfoSource _deviceInfo;

  /// Lazily updated each navigation event. Set by the router (Phase 1 has
  /// no router yet; remains null until plumbed).
  String? lastUiRoute;

  /// Diagnostic counters supplied by other subsystems (Phase 3 wiring).
  int? isarDbSizeBytes;
  int? uniqueContextKeysCount;
  bool banditStateCorruptionFlag = false;

  /// Install framework + platform handlers. Call ONCE inside the
  /// [runZonedGuarded] zone before [runApp].
  void install() {
    FlutterError.onError = (details) {
      _captureSync(
        details.exception,
        details.stack ?? StackTrace.current,
        contextLibrary: details.library,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _captureSync(error, stack);
      return true;
    };
  }

  /// To be called from the zoneError handler in [runZonedGuarded]:
  ///   runZonedGuarded(() { ...runApp(...) }, crashCapture.zoneErrorHandler);
  void zoneErrorHandler(Object error, StackTrace stack) {
    _captureSync(error, stack);
  }

  /// Fire-and-forget. We do not await persistence in error handlers because
  /// a handler that hangs is worse than a missed log.
  void _captureSync(Object error, StackTrace stack, {String? contextLibrary}) {
    _captureAsync(error, stack, contextLibrary: contextLibrary)
        .catchError((Object e) {
      // If even our error path errors, swallow it to avoid recursion.
    });
  }

  Future<void> _captureAsync(
    Object error,
    StackTrace stack, {
    String? contextLibrary,
  }) async {
    final info = await _deviceInfo.read();
    final log = CrashLog(
      timestamp: DateTime.now().toUtc(),
      appVersion: info.appVersion,
      buildNumber: info.buildNumber,
      os: info.os,
      deviceModel: info.deviceModel,
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      exceptionType: error.runtimeType.toString(),
      exceptionMessage: _safeMessage(error),
      stackTrace: stack.toString(),
      lastUiRoute: lastUiRoute,
      isarDbSizeBytes: isarDbSizeBytes,
      uniqueContextKeysCount: uniqueContextKeysCount,
      banditStateCorruptionFlag: banditStateCorruptionFlag,
    );
    try {
      await _store.write(log);
    } catch (_) {
      // Swallow; nothing useful we can do if we can't write to local cache.
    }

    if (kDebugMode) {
      FlutterError.presentError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: contextLibrary,
      ));
    }
  }

  /// Defensive string-of-error. Some errors override toString to include
  /// communication content or other sensitive context in odd places. We
  /// keep this short and let the stack trace carry the real signal.
  String _safeMessage(Object error) {
    final s = error.toString();
    if (s.length <= 1000) return s;
    return '${s.substring(0, 1000)}...[truncated]';
  }
}
