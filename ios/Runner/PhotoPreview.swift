import Flutter
import UIKit

/// Uses the same channel as macOS Quick Look. Only staged cache files cross
/// this boundary. UIKit owns zoom, sharing and swipe dismissal rather than
/// reproducing those gestures in Flutter. Not Quick Look: it draws the photo
/// in another process, so a swipe on the photo never reaches a dismiss gesture.
final class PhotoPreview: NSObject {
  private weak var registrar: FlutterPluginRegistrar?
  private var preview: PhotoViewerNavigation?
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
    guard let url = Self.stagedFile(path), let image = UIImage(contentsOfFile: url.path),
      let presenter = registrar?.viewController,
      presenter.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive,
      !presenter.isBeingDismissed else { result(false); return }
    // A second tap while the first viewer animates must not create a second
    // modal. Do not replace a file while its Share sheet is using it.
    if let preview {
      if preview.presentedViewController == nil && !preview.isBeingDismissed {
        preview.viewer.show(file: url, image: image)
      }
      result(true)
      return
    }
    guard presenter.presentedViewController == nil else { result(false); return }
    generation += 1
    let request = generation
    let controller = PhotoViewerNavigation(viewer: PhotoViewerController(file: url, image: image))
    controller.onDismiss = { [weak self, weak controller] in
      guard let self, let controller, controller === self.preview else { return }
      self.preview = nil
    }
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
    // Hide immediately, including if a sign-out races the presentation.
    controller?.view.isHidden = true
    controller?.dismiss(animated: false)
  }

  deinit {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
  }
}

/// Holds the viewer's bar, and reports every way it goes away (Close, a
/// swipe, VoiceOver's escape, or `PhotoPreview.close`).
private final class PhotoViewerNavigation: UINavigationController {
  let viewer: PhotoViewerController
  var onDismiss: (() -> Void)?

  init(viewer: PhotoViewerController) {
    self.viewer = viewer
    super.init(rootViewController: viewer)
    modalPresentationStyle = .overFullScreen
    modalTransitionStyle = .crossDissolve
    modalPresentationCapturesStatusBarAppearance = true
    overrideUserInterfaceStyle = .dark
    view.backgroundColor = .clear
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    navigationBar.standardAppearance = appearance
    navigationBar.compactAppearance = appearance
    navigationBar.scrollEdgeAppearance = appearance
  }

  required init?(coder: NSCoder) { fatalError("Use init(viewer:)") }

  override var childForStatusBarHidden: UIViewController? { viewer }
  override var childForStatusBarStyle: UIViewController? { viewer }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isBeingDismissed { onDismiss?() }
  }
}

/// A photo on black, as in Photos: pinch and double-tap zoom, a tap shows or
/// hides the bar, and a vertical swipe while not zoomed in closes it. The bar
/// uses system items, so Close and Share are labelled in the user's language.
private final class PhotoViewerController: UIViewController, UIScrollViewDelegate,
  UIGestureRecognizerDelegate
{
  private static let dismissDistance: CGFloat = 120
  private static let dismissVelocity: CGFloat = 900

  private(set) var file: URL
  private let backdrop = UIView()
  private let scrollView = UIScrollView()
  private let imageView = UIImageView()
  private lazy var shareItem = UIBarButtonItem(
    barButtonSystemItem: .action, target: self, action: #selector(share))
  private var laidOutSize = CGSize.zero
  private var barsHidden = false

  init(file: URL, image: UIImage) {
    self.file = file
    super.init(nibName: nil, bundle: nil)
    imageView.image = image
  }

  required init?(coder: NSCoder) { fatalError("Use init(file:image:)") }

  func show(file: URL, image: UIImage) {
    self.file = file
    imageView.image = image
    imageView.accessibilityLabel = file.lastPathComponent
    laidOutSize = .zero
    view.setNeedsLayout()
  }

  override var prefersStatusBarHidden: Bool { barsHidden }
  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    backdrop.backgroundColor = .black
    backdrop.frame = view.bounds
    backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(backdrop)

    scrollView.frame = view.bounds
    scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    scrollView.delegate = self
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.decelerationRate = .fast
    view.addSubview(scrollView)

    imageView.contentMode = .scaleAspectFit
    imageView.isAccessibilityElement = true
    imageView.accessibilityTraits = .image
    imageView.accessibilityLabel = file.lastPathComponent
    scrollView.addSubview(imageView)

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
    navigationItem.rightBarButtonItem = shareItem

    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
    doubleTap.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(doubleTap)
    let tap = UITapGestureRecognizer(target: self, action: #selector(toggleBars))
    tap.require(toFail: doubleTap)
    scrollView.addGestureRecognizer(tap)
    let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
    pan.delegate = self
    view.addGestureRecognizer(pan)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard scrollView.bounds.size != laidOutSize else { return }
    laidOutSize = scrollView.bounds.size
    layoutImage()
  }

  /// Fits the photo in the screen at zoom 1, and lets it zoom to at least
  /// three times that or its full resolution, whichever is larger.
  private func layoutImage() {
    let bounds = scrollView.bounds.size
    guard let size = imageView.image?.size, size.width > 0, size.height > 0,
      bounds.width > 0, bounds.height > 0 else { return }
    scrollView.minimumZoomScale = 1
    scrollView.zoomScale = 1
    let fit = min(bounds.width / size.width, bounds.height / size.height)
    imageView.frame = CGRect(x: 0, y: 0, width: size.width * fit, height: size.height * fit)
    scrollView.contentSize = imageView.frame.size
    scrollView.maximumZoomScale = max(3, 1 / fit)
    centerImage()
  }

  private func centerImage() {
    let bounds = scrollView.bounds.size
    let content = scrollView.contentSize
    scrollView.contentInset = UIEdgeInsets(
      top: max(0, (bounds.height - content.height) / 2),
      left: max(0, (bounds.width - content.width) / 2),
      bottom: 0, right: 0)
  }

  func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

  func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }

  @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
    if scrollView.zoomScale > scrollView.minimumZoomScale {
      scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
      return
    }
    let scale = min(scrollView.maximumZoomScale, 2.5)
    let point = gesture.location(in: imageView)
    let size = CGSize(width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
    scrollView.zoom(
      to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
        width: size.width, height: size.height),
      animated: true)
  }

  @objc private func toggleBars() {
    barsHidden.toggle()
    navigationController?.setNavigationBarHidden(barsHidden, animated: true)
    UIView.animate(withDuration: 0.2) { self.setNeedsStatusBarAppearanceUpdate() }
  }

  @objc private func closeTapped() { dismiss(animated: true) }

  override func accessibilityPerformEscape() -> Bool {
    dismiss(animated: true)
    return true
  }

  @objc private func share() {
    let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
    sheet.popoverPresentationController?.barButtonItem = shareItem
    present(sheet, animated: true)
  }

  // A swipe dismisses only while the photo is not zoomed in: zoomed, the
  // same drag pans the photo.
  func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
    guard let pan = gesture as? UIPanGestureRecognizer,
      scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01 else { return false }
    let velocity = pan.velocity(in: view)
    return abs(velocity.y) > abs(velocity.x)
  }

  @objc private func panned(_ pan: UIPanGestureRecognizer) {
    let offset = pan.translation(in: view).y
    let progress = min(1, abs(offset) / (view.bounds.height / 2))
    switch pan.state {
    case .changed:
      scrollView.transform = CGAffineTransform(translationX: 0, y: offset)
      backdrop.alpha = 1 - progress
      navigationController?.navigationBar.alpha = 1 - progress * 2
    case .ended, .cancelled, .failed:
      let velocity = pan.velocity(in: view).y
      let dismissing = pan.state == .ended
        && (abs(offset) > Self.dismissDistance || abs(velocity) > Self.dismissVelocity)
        && (offset == 0 || velocity == 0 || (offset > 0) == (velocity > 0))
      if dismissing {
        let direction: CGFloat = (offset + velocity) >= 0 ? 1 : -1
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
          self.scrollView.transform = CGAffineTransform(
            translationX: 0, y: direction * self.view.bounds.height)
          self.backdrop.alpha = 0
          self.navigationController?.navigationBar.alpha = 0
        } completion: { _ in
          self.dismiss(animated: false)
        }
      } else {
        UIView.animate(
          withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0
        ) {
          self.scrollView.transform = .identity
          self.backdrop.alpha = 1
          self.navigationController?.navigationBar.alpha = 1
        }
      }
    default:
      break
    }
  }
}
