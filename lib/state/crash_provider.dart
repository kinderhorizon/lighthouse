/// Crash subsystem providers.
///
/// Provided as Riverpod handles so Settings + future preview screens can
/// read them without reaching into globals. Overridden at app startup with
/// the live instances created before [runZonedGuarded].
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';

part 'crash_provider.g.dart';

@Riverpod(keepAlive: true)
CrashLogStore crashLogStore(CrashLogStoreRef ref) {
  throw UnimplementedError(
    'crashLogStoreProvider must be overridden at app startup',
  );
}

@Riverpod(keepAlive: true)
CrashCapture crashCapture(CrashCaptureRef ref) {
  throw UnimplementedError(
    'crashCaptureProvider must be overridden at app startup',
  );
}
