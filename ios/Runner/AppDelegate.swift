import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeApplicationSupportFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Marks the entire Application Support directory as excluded from iCloud
  /// backup and device transfer (ADR 0002, privacy-critical).
  ///
  /// On iOS Library/Application Support IS backed up to iCloud by default (only
  /// Caches and tmp are excluded). Everything the app persists there is either
  /// the child's data or parent-authored content: the Isar DB (button-tap log),
  /// custom buttons + images, home favourites, board layout, imported boards,
  /// and applied OTA overlays. None of it should leave the device, so we exclude
  /// the whole directory rather than enumerate paths. That also future-proofs
  /// against a new content store being added without remembering to exclude it
  /// (on Android the <exclude> list must be kept in sync, enforced by
  /// backup_exclusion_test).
  ///
  /// Settings/locale live in NSUserDefaults (Library/Preferences), NOT here, so
  /// they still back up, matching the Android sharedpref behavior. Setting
  /// NSURLIsExcludedFromBackupKey on the directory covers its current and future
  /// contents. We do it at launch, before the Dart entrypoint opens Isar, so the
  /// attribute is in place first. Best-effort: never block launch. Device
  /// verification (attribute actually sticks) is an alpha check.
  private func excludeApplicationSupportFromBackup() {
    let fm = FileManager.default
    guard let support = fm.urls(for: .applicationSupportDirectory,
                                in: .userDomainMask).first else { return }
    var supportDir = support
    do {
      if !fm.fileExists(atPath: supportDir.path) {
        try fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
      }
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try supportDir.setResourceValues(values)
    } catch {
      NSLog("Lighthouse: could not exclude Application Support from backup: \(error)")
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
