import Flutter
import QuickLook
import UIKit

/// Uses the same channel as macOS Quick Look. Only staged cache files cross
/// this boundary; UIKit owns image zoom, sharing, iPad presentation and drag
/// dismissal rather than trying to reproduce those gestures in Flutter.
final class PhotoPreview: NSObject, QLPreviewControllerDelegate, UIAdaptivePresentationControllerDelegate {
  private weak var registrar: FlutterPluginRegistrar?
  private var preview: PhotoPreviewController?
  private var generation = 0
  private var observers: [NSObjectProtocol] = []

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
    FlutterMethodChannel(name: "hermes_app/quick_look", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { [weak self] call, result in
        guard let self else { result(false); return }
        switch call.method {
        case "preview":
          self.show(path: (call.arguments as? [String: Any])?["path"] as? String, result: result)
        case "close":
          self.close()
          result(nil)
        case "doubleClickInterval": result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    // Native presentations sit above Flutter's app-lock cover. Hide the
    // image for inactive snapshots, and dismiss on background so returning
    // to the app cannot bypass its lock screen. A foreground share sheet
    // remains UIKit's responsibility.
    observers = [
      NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
        object: nil, queue: .main) { [weak self] _ in self?.preview?.view.isHidden = true },
      NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
        object: nil, queue: .main) { [weak self] _ in self?.preview?.view.isHidden = false },
      NotificationCenter.default.addObserver(forName: UIScene.didEnterBackgroundNotification,
        object: nil, queue: .main) { [weak self] note in
          guard let self,
            let scene = note.object as? UIWindowScene,
            scene === self.registrar?.viewController?.viewIfLoaded?.window?.windowScene
          else { return }
          self.close()
        },
    ]
  }

  private func show(path: String?, result: @escaping FlutterResult) {
    guard let url = Self.stagedFile(path), QLPreviewController.canPreview(url as NSURL),
      let presenter = registrar?.viewController,
      presenter.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive,
      !presenter.isBeingDismissed else { result(false); return }
    // A second tap while the first sheet animates must not create a second
    // modal. Do not replace a file while its Share sheet is using it.
    if let preview {
      if preview.presentedViewController == nil && !preview.isBeingDismissed {
        preview.replaceFile(url)
      }
      result(true)
      return
    }
    guard presenter.presentedViewController == nil else { result(false); return }
    generation += 1
    let request = generation
    let controller = PhotoPreviewController(file: url)
    controller.delegate = self
    controller.modalPresentationStyle = .pageSheet
    controller.isModalInPresentation = false
    if let sheet = controller.sheetPresentationController {
      sheet.detents = [.large()]
      sheet.prefersGrabberVisible = true
      sheet.prefersEdgeAttachedInCompactHeight = true
    }
    controller.presentationController?.delegate = self
    preview = controller
    presenter.present(controller, animated: true) { [weak self, weak controller] in
      guard let self, let controller else { result(false); return }
      guard self.generation == request, self.preview === controller else {
        controller.dismiss(animated: false)
        // Presentation was consumed and then cancelled/dismissed. Do not
        // turn a user's quick dismissal into an "unable to open" error.
        result(true)
        return
      }
      result(true)
    }
  }

  /// A local, readable, regular file made by MediaStore. Resolve symlinks
  /// before checking the directory, so another app file cannot be shared by
  /// passing a URL, a relative path or a link outside the media cache.
  static func stagedFile(_ path: String?) -> URL? {
    guard let path, path.hasPrefix("/"),
      let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    let root = cache.appendingPathComponent("hermes_media", isDirectory: true)
      .resolvingSymlinksInPath().standardizedFileURL
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    guard url.path.hasPrefix(root.path + "/"),
      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
      FileManager.default.isReadableFile(atPath: url.path)
    else { return nil }
    return url
  }

  private func close() {
    generation += 1
    let controller = preview
    preview = nil
    // Hide immediately, including if a sign-out races sheet presentation.
    controller?.view.isHidden = true
    controller?.dismiss(animated: false)
  }

  func previewControllerDidDismiss(_ controller: QLPreviewController) {
    guard controller === preview else { return }
    preview = nil
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    // UIKit's pull-down gesture can dismiss the sheet without using Quick
    // Look's Done button. Drop that controller too, so the next photo opens.
    guard presentationController.presentedViewController === preview else { return }
    preview = nil
  }

  deinit {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
  }
}

/// The preview item lives with its controller through UIKit's asynchronous
/// dismissal, even after the owner's close/sign-out has dropped its reference.
private final class PhotoPreviewController: QLPreviewController, QLPreviewControllerDataSource {
  private var file: NSURL

  init(file: URL) {
    self.file = file as NSURL
    super.init(nibName: nil, bundle: nil)
    dataSource = self
  }

  required init?(coder: NSCoder) { fatalError("Use init(file:)") }

  func replaceFile(_ url: URL) {
    file = url as NSURL
    reloadData()
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    file
  }
}
