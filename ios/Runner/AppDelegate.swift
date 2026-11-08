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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IncomingFilePlugin") {
      IncomingFilePlugin.register(with: registrar)
    }
  }
}

/// Board files opened with Lighthouse: AirDrop, Messages, Mail, Files, the
/// share sheet's "Open in" (ADR 0015 amendment; Info.plist declares the
/// document type). Without it the phone offered a shared board only to other
/// apps, which asked the parent to sign in.
///
/// iOS hands the scene a private copy (LSSupportsOpeningDocumentsInPlace = NO)
/// in Documents/Inbox, which IS backed up, so it is copied to tmp (never backed
/// up, at most maxBytes + 1 bytes) and the Inbox copy deleted at once. The Dart
/// side takes the ONE pending path (newest wins), asks the parent behind the
/// math gate, imports, and deletes the tmp copy (lib/ui/incoming_board_file_handler.dart).
final class IncomingFilePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  /// Mirrors BoardLoader.maxFileBytes (4 MB): an oversized file still arrives
  /// (one byte over) so the loader rejects it with a message.
  private static let maxBytes = 4 * 1024 * 1024

  private let channel: FlutterMethodChannel
  private var pendingPath: String?

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  /// tmp/incoming: where received files wait for the parent.
  private static var incomingDir: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("incoming", isDirectory: true)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    // A copy left by an earlier run (the app was closed before the parent
    // answered) is never offered again; remove it before a new file arrives.
    try? FileManager.default.removeItem(at: incomingDir)
    let channel = FlutterMethodChannel(
      name: "lighthouse/incoming_file", binaryMessenger: registrar.messenger())
    let instance = IncomingFilePlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takePendingFile":
      result(pendingPath)
      pendingPath = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Cold start: the app was launched to open the file.
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts else { return false }
    return receive(contexts)
  }

  /// The app was already running.
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return receive(URLContexts)
  }

  private func receive(_ contexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = contexts.map(\.url).first(where: { $0.isFileURL }) else { return false }
    let copy = copyToTemp(url)
    removeIfInbox(url)
    guard let copy = copy else { return false }
    if let old = pendingPath { try? FileManager.default.removeItem(atPath: old) }
    pendingPath = copy.path
    channel.invokeMethod("fileReceived", arguments: nil)
    return true
  }

  private func copyToTemp(_ url: URL) -> URL? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let fm = FileManager.default
    let dir = Self.incomingDir
    let dest = dir.appendingPathComponent("board_\(UUID().uuidString).json")
    do {
      let handle = try FileHandle(forReadingFrom: url)
      defer { try? handle.close() }
      let data = try handle.read(upToCount: Self.maxBytes + 1) ?? Data()
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
      try data.write(to: dest, options: .atomic)
      return dest
    } catch {
      try? fm.removeItem(at: dest)
      return nil
    }
  }

  /// Deletes iOS's copy if it is in this app's Documents/Inbox (backed up).
  private func removeIfInbox(_ url: URL) {
    let fm = FileManager.default
    guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let inbox = docs.appendingPathComponent("Inbox", isDirectory: true)
      .resolvingSymlinksInPath().path
    if url.resolvingSymlinksInPath().path.hasPrefix(inbox + "/") {
      try? fm.removeItem(at: url)
    }
  }
}
