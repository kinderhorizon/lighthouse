# ADR 0007: Android toolchain modernization + Isar community fork

**Status:** Accepted
**Date:** 2026-05-28
**Amends:** ADR 0005 (Isar schema versioning) on the persistence engine; the
collection-name versioning strategy itself is unchanged.

## Context

Two blockers surfaced once the project moved to the Flutter 3.44 / Dart 3.12
host toolchain:

1. **The Android debug build could not assemble.** The original persistence
   dependency, `isar` 3.1.0 (with `isar_flutter_libs` 3.1.0+1), predates the
   Android Gradle Plugin 8 hard requirement that every library module declare
   a `namespace`. `isar_flutter_libs` 3.1.0+1 ships none, so any AGP 8+ build
   fails at configuration. `isar` 3.1.0 is also unmaintained upstream.

2. **The scaffold Gradle files were stale.** The project still carried the
   Groovy `settings.gradle` / `build.gradle` with AGP 7.3.0, Gradle 7.6.3, and
   Kotlin 1.7.10. Flutter 3.44's bundled dependency-version checker hard-errors
   below AGP 8.6 / Gradle 8.7 / Kotlin 2.0 / Java 17 and warns below AGP 8.11.1
   / Gradle 8.14 / Kotlin 2.2.20. The old versions would not build.

We are pre-alpha. There are zero rows of persisted data on any device, so the
persistence engine can be swapped with no data migration. ADR 0005's
migration-failure design is preserved for the future; it simply has no
existing data to act on today.

## Decision

### Persistence engine: `isar` -> `isar_community`

Adopt the maintained community fork `isar_community` 3.3.0 (+
`isar_community_flutter_libs` 3.3.0) in place of the abandoned `isar` 3.1.0.

- It is a drop-in fork of the Isar v3 API. The import path changes from
  `package:isar/isar.dart` to `package:isar_community/isar.dart`; the symbol
  set is otherwise identical.
- `isar_community_flutter_libs` 3.3.0 declares a `namespace`
  (`dev.isar.isar_community_flutter_libs`), which removes blocker (1) with no
  shim.
- **ADR 0005 collection-name versioning is unchanged.** The regenerated
  schemas keep the same collection names (`BanditStateV1`, `RawEventLogV1`)
  and the same collection id hashes (`1753627432560743480`,
  `-4740275644641358943`) and the same property ids and types. Verified by
  diffing the regenerated `*.g.dart` against the prior output: the structural
  schema is byte-identical apart from generator formatting and the embedded
  version string.

The candidate `isar` 4.0.0-dev was rejected: it is an unstable prerelease
rewrite with a different API surface, which would have meant re-doing the
persistence layer rather than unblocking it.

#### Generated-code constraint (important for future contributors)

The Isar `*.g.dart` files embed `version: '3.3.0'`, which the
`isar_community` 3.3.0 runtime asserts (`Isar.version == version`) when a
database is opened. The old `isar` 3.1.0 generator emitted `'3.1.0+1'`, so the
prior generated files do NOT drop in; they compile under the analyzer but fail
at kernel compile and would fail at DB-open. The files were regenerated with
`isar_community_generator` 3.3.0.

`isar_community_generator` is intentionally not a steady-state dev dependency:
its 3.3.x line requires `build` ^3/^4, which conflicts with `riverpod_generator`
2.x (`build` ^2) and would block the normal `dart run build_runner build`
workflow. Because the schemas are frozen (ADR 0005), regeneration is rare. The
procedure is documented in `pubspec.yaml`: temporarily swap `riverpod_generator`
for `isar_community_generator: 3.3.0`, regenerate, then restore. Revisit when
the project moves to Riverpod 3 (`build` ^4), which lets both generators
co-resolve.

### Android toolchain: Kotlin DSL on the latest AGP 8.x

Convert the Android build to the Flutter 3.44 Kotlin-DSL scaffold and pin:

| Component | Version |
|---|---|
| Android Gradle Plugin | 8.13.2 |
| Gradle wrapper | 8.14.5 |
| Kotlin Gradle Plugin | 2.2.21 |
| Java (host) | 21 (Temurin) |
| Java bytecode target | 17 |
| compileSdk / targetSdk | `flutter.compileSdkVersion` = 36 / `flutter.targetSdkVersion` = 36 |
| minSdk | `flutter.minSdkVersion` = 24 |

These versions clear Flutter 3.44's warn floors (>= AGP 8.11.1, Gradle 8.14,
Kotlin 2.2.20), so the build is warning-free on the version-checker axis.

**We deliberately do not move to AGP 9, even though it is the Flutter 3.44
scaffold default.** AGP 9 flips Android modules to AGP's *built-in Kotlin*
compilation. Most of our plugin set (file_picker, permission_handler,
flutter_tts, network_info_plus, package_info_plus, share_plus,
shared_preferences, url_launcher) still ships the legacy
`apply plugin: 'org.jetbrains.kotlin.android'` path, which several of them
guard to run only under AGP < 9. Under AGP 9 with `builtInKotlin` disabled,
those plugins' Kotlin never compiles and their plugin classes vanish at link
time (observed concretely: `file_picker` 11's `FilePickerPlugin` went missing).
The built-in-Kotlin migration is not yet uniformly supported across the
ecosystem, so AGP 8.13.x is the modern-but-stable choice. Flutter still prints a
forward-looking "plugins apply KGP" warning; that is the whole ecosystem's
pending migration, not an action item for this app.

The app module does not apply `kotlin-android` explicitly; the Flutter Gradle
Plugin injects it, matching the 3.44 scaffold and avoiding the per-build
"migrate to built-in Kotlin" app warning.

### Plugin bump: `file_picker` 8 -> 11

`file_picker` 8.3.7's Android module compiles against `compileSdk 34`, while
its transitive `flutter_plugin_android_lifecycle` now requires consumers to
compile against 36. Bumped to `file_picker` 11.0.0. The only API change at our
single call site is `FilePicker.platform.pickFiles(...)` ->
`FilePicker.pickFiles(...)` (the method became static); `type`,
`allowedExtensions`, and `withData` are unchanged.

### Permissions after the targetSdk bump

targetSdk moved to 36. The only permission-sensitive path is the WiFi-SSID
hash used for bandit context (`lib/services/network/wifi_source.dart`). Reading
the *connected* network's SSID via the location-gated API still requires only
`ACCESS_FINE_LOCATION` on API 33-36; `NEARBY_WIFI_DEVICES` is needed only for
scanning / connection APIs, which we do not call. No manifest change. The code
already degrades to a null SSID ("wifi_UNKNOWN" context) on any denial or
failure, so the permission model change cannot break communication.

## Consequences

- The Android build is green on a current, warn-clean toolchain, and the
  original AGP-8 namespace blocker is permanently resolved.
- Persistence runs on a maintained fork. Verified at runtime on both an iPad
  simulator and an Android 15 (API 35) emulator: the native core loads
  (`IsarCore using libmdbx`), the `3.3.0` version assertion passes at DB-open,
  and the full integration suite (CRUD, V1 happy / corrupted / 5,000-key
  fixtures, end-to-end bandit loop, migration chain) passes.
- Isar schema regeneration is now a documented two-step manual procedure
  rather than part of the default codegen run. Acceptable because schemas are
  frozen by ADR 0005.
- We carry a standing "plugins apply KGP" warning until the plugin ecosystem
  completes its built-in-Kotlin migration; revisiting AGP 9 is a future task
  gated on that, not on us.

## Reviewers

- Engineering review: 2026-05-28. Drove the toolchain modernization, the
  fork selection, the AGP-8-over-9 call, and on-device verification on both
  platforms.
- Independent reviewer: pending pass on the native-build branch (toolchain
  pins, the no-data-migration claim, the schema-identity diff, and the AGP-9
  deferral rationale).
- Clinical lead (BCBA): N/A (engineering decision; no clinical
  or terminology surface touched).
