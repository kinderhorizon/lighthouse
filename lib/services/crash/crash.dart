/// Crash subsystem barrel.
///
/// See docs/adr/0002-no-automatic-telemetry.md. Strictly local: no network
/// calls, no third-party SDK, no automatic transmission. Sharing is
/// user-initiated only.
library;

export 'crash_capture.dart';
export 'crash_log.dart';
export 'crash_log_store.dart';
export 'device_info_source.dart';
