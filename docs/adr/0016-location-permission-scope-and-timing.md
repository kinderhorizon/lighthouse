# ADR 0016: Location-permission scope and timing (Wi-Fi context)

Status: Accepted (2026-05-31)

Reviewer-approved 2026-05-31 (substance approved; Decision 6 corrected to strip
the location code from the iOS binary, not just the usage string).

## Amendment (2026-06-02): network_info_plus also linked iOS CoreLocation, but it was NOT the only (or main) location source

Two corrections to this ADR, after the first TestFlight upload (build 1) was
rejected with THREE App Store Connect 90683 "missing purpose string" errors
(Photos, Camera, AND Location):

**(1) Decision 6's parenthetical was wrong.** It claimed `network_info_plus`
"needs no string" because its iOS Wi-Fi API is entitlement-gated. In fact
`network_info_plus`'s iOS implementation links `CoreLocation` for
`getWifiName()`. We removed it regardless (it is genuinely the right call for
the Android-only Wi-Fi feature):

- Removed `network_info_plus` from `pubspec.yaml` entirely.
- The SSID read is now an Android-only platform channel (`lighthouse/wifi`,
  method `getWifiSsid`), implemented in `MainActivity.kt` via `WifiManager`
  (still gated by `ACCESS_FINE_LOCATION`). `wifi_source.dart` calls it through
  an injectable `WifiSsidReader` wrapper (the test seam that replaced the
  injected `NetworkInfo`). No iOS handler is registered.

**(2) The location 90683 is NOT actually resolved by removing
network_info_plus.** Binary analysis (`nm` of the build-2 archive) shows the
true source of all three location/media symbols is `file_picker`'s iOS
dependency chain: `file_picker` -> `DKImagePickerController` (links Photos, 12
CLLocation refs) -> `DKCamera` (links Camera + Location, 48 CLLocation refs,
and CALLS `requestWhenInUseAuthorization`). `permission_handler`'s location
code is correctly stripped (`PERMISSION_LOCATION=0`; its framework has zero
CLLocation symbols), and `network_info_plus` is now gone, yet the build-2
`Runner` binary STILL references `CLLocationManager` +
`requestWhenInUseAuthorization` via `DKCamera`.

Consequence: build 2 (Photos + Camera strings added, no location string)
should clear the Photos and Camera 90683s but will very likely STILL hit the
Location 90683, because `DKImagePickerController` cannot be linked without
`DKCamera`'s location call, and Decision 6 + the founder both forbid shipping a
location string.

**Resolved (2026-06-02, founder decision): switch to PHPicker + document
picker, ship zero photo/camera/location strings.** Rather than disclose
location for a picker the app does not need, the custom-button photo source
moved to the system photo picker and pack import moved to the document picker:

- `file_picker` removed from `pubspec.yaml` entirely.
- Custom-button photos: `image_picker` (`pickImage(source: gallery)`), which is
  PHPicker on iOS 14+. PHPicker runs out of process and returns the chosen
  image without any Photos-library permission, so no `NSPhotoLibraryUsageDescription`
  is needed and no Camera/CoreLocation framework is linked. Sites:
  `custom_buttons_screen.dart`, `board_edit_screen.dart`. The existing
  size/extension validation backstops are unchanged (the picker still yields a
  path we wrap in `File`).
- JSON pack import: `file_selector` (`openFile`), backed by
  `UIDocumentPickerViewController`, which does NOT pull
  `DKImagePickerController`. Site: `settings_primary_screen.dart` (with an
  extension re-check, since the iOS type filter is advisory).
- The two media purpose strings added in build 2
  (`NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`) were REMOVED
  from `Info.plist`. The binary ships no photo/camera/location usage string.
- Minimum iOS raised to 14.0 (`Podfile`, `project.pbxproj`,
  `AppFrameworkInfo.plist`) so PHPicker is always the path.

Binary acceptance test (the proof, `nm` of the build-2 `Runner`): zero
`CLLocationManager`, `requestWhenInUseAuthorization`, `DKCamera`, and
`DKImagePickerController` symbols, and no `CoreLocation` load command. All
three 90683 sources are structurally gone, and Decision 1's "no iOS location
disclosure" is finally achieved (this time at the binary level, not just the
usage string). Android is unaffected: `image_picker` + `file_selector` use the
system pickers and declare no new `uses-permission`, so the Play Data Safety
story is unchanged.

## Context

The bandit uses a hashed Wi-Fi SSID as one dimension of its environmental
context (ADR 0006, PRD 3.1). `wifi_source.dart` reads the SSID, SHA-256-hashes
it, keeps only a 12-hex `wifi_`-prefixed prefix, and never stores or transmits
the raw value. Reading the SSID requires Location permission on both platforms
(iOS 13+ ties `CNCopyCurrentNetworkInfo` to Location; Android has gated the
Wi-Fi name behind `ACCESS_FINE_LOCATION` since API 26).

A website-claims audit plus an independent reviewer pass (read against the same
tree) surfaced two findings that change how this permission should be handled:

- **(A) On iOS the permission is all cost, no benefit.** There is no
  `.entitlements` file, no `CODE_SIGN_ENTITLEMENTS` build setting, and no
  `com.apple.developer.networking.wifi-info` entitlement wired anywhere in
  `ios/Runner/` or `project.pbxproj`. Without that entitlement Apple returns
  `nil` from the Wi-Fi-name API on iOS 13+. So today on iOS the app prompts for
  Location, the read returns null, and the bandit context is permanently
  `wifi_UNKNOWN`: the family gets an alarming prompt and zero functional
  benefit.
- **(B) The prompt fires mid-use, on the child's tap path.**
  `hashOfCurrentSsid()` is called from the tap/stateKey build
  (`main.dart` `_persistTap`), and `_ensureLocationPermission()` calls
  `requestOf(...)` directly the first time it is hit. So the OS Location dialog
  appears while the child is first tapping the board, not at a controlled,
  parent-facing moment.

## Decision

1. **iOS does not request Location and does not read Wi-Fi context.**
   `WifiSource.usesWifiContext` is `Platform.isAndroid`. On iOS the bandit runs
   on `wifi_UNKNOWN`. Rationale: we deliberately do not ship the `wifi-info`
   entitlement, so the read is null regardless; a privacy-first app must not
   raise an alarming Location prompt for zero benefit; and dropping it removes
   the App Store location disclosure entirely. (If Wi-Fi context on iPad is ever
   judged worth it, that is a separate, explicit decision: add the entitlement,
   enable the capability on the provisioning profile, declare location on the
   App Store privacy form, and add the rationale step on iOS too.)

2. **The permission request moves off the tap path into a deliberate,
   parent-facing onboarding step (rationale -> prompt).** A new onboarding
   screen explains, in plain language, why the app reads the (scrambled) Wi-Fi
   name and that it never leaves the tablet, then offers Allow / Not now; Allow
   performs the actual request. The screen is shown only where
   `usesWifiContext` is true (Android). It is skipped on iOS and anywhere the
   platform does not use Wi-Fi context.

3. **`hashOfCurrentSsid()` becomes read-only and never prompts.** It checks the
   permission status and reads the SSID only if already granted; it never calls
   `request(...)`. A child tap therefore can never trigger an OS dialog.

4. **Graceful degradation is the existing clean path.** Ungranted,
   unsupported platform, or no SSID all return null, and `ContextManager`
   already maps null to `wifi_UNKNOWN`. The bandit runs fully without Wi-Fi
   context; it is one dimension of many, not a hard dependency.

5. **Comment reconciliation + forward path.** The `wifi_source.dart` comment
   claiming "precise location is not needed" is corrected:
   `ACCESS_FINE_LOCATION` is genuinely required for SSID reads on current
   Android APIs. Forward note (out of scope here, tracked): Android 13+ (API
   33) `NEARBY_WIFI_DEVICES` can read Wi-Fi info without the Location
   permission, which would let us drop the scary permission entirely on new
   Android once `minSdk` allows.

6. **Strip the iOS location code from the binary, AND remove
   `NSLocationWhenInUseUsageDescription`. Both steps, in this order.** By
   default `permission_handler` compiles in every permission handler, including
   the `CLLocationManager` code behind `PERMISSION_LOCATION`. Apple's static
   analysis flags a binary that links the Location API but ships no usage
   string, so removing the string *alone* (while the location code is still
   compiled in) flips the rejection risk to "uses location, no purpose string."
   Therefore:
   - Add `PERMISSION_LOCATION=0` to `GCC_PREPROCESSOR_DEFINITIONS` in the
     `ios/Podfile` `post_install` so the `CLLocationManager` code is not in the
     iOS binary at all.
   - Then remove `NSLocationWhenInUseUsageDescription` from `Info.plist`.

   (CORRECTED, see the 2026-06-02 amendment above: this parenthetical was
   wrong. `network_info_plus` links iOS `CoreLocation` for `getWifiName()`,
   which is a location symbol Apple's static analysis flags regardless of the
   entitlement, so it ALSO needed handling. It was removed entirely and the
   SSID read moved to an Android-only platform channel.)

## Store forms

- **iOS App Privacy:** no location collected or used. Declare only what is
  actually present (Crash/Diagnostics per the existing posture). No location
  entry.
- **Play Data Safety (Android listing):** Location is *accessed for app
  functionality* (on-device Wi-Fi-based personalization) and is **not**
  collected, shared, or stored. Declare access-not-collection. This applies to
  the Android listing only, since location stays Android-scoped.

## Consequences

- iOS loses the Wi-Fi environmental signal. Acceptable: it never functioned
  there, and the bandit degrades cleanly to `wifi_UNKNOWN`.
- Android keeps Wi-Fi context, now behind explicit, informed, parent-facing
  consent at a controlled moment.
- No OS permission dialog ever appears on the child's interaction path, on
  either platform.
- Store-review surface shrinks: no iOS location disclosure at all.

## Testing

- `wifi_source`: read-only path never calls `request`; iOS short-circuits to
  null; Android reads only when already granted; all error/unsupported paths
  return null.
- Onboarding: the Wi-Fi-context step appears only when `usesWifiContext` is
  true; Allow triggers exactly one request; Not now leaves the bandit on
  `wifi_UNKNOWN`.

## Deferred (reviewer minors, non-blocking)

- **In-app re-enable.** A parent who taps "Not now" has no in-app path back
  (the read never re-prompts; granting later via OS Settings works because the
  status flips). A friendlier "Enable Wi-Fi personalization" toggle in Settings
  that re-runs rationale -> request is a nice-to-have.
- **`permanentlyDenied` on Android.** After a hard deny, "Allow" silently
  no-ops; offering "Open settings" in that state is friendlier. (Today the
  "Not now" guidance text already points the parent to Settings, which is
  adequate for alpha.)
