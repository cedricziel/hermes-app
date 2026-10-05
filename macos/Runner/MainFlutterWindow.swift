import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    FlutterMethodChannel(
      name: "hermes_app/clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
      guard call.method == "files" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Self.clipboardFilePaths(from: .general))
    }

    FlutterMethodChannel(
      name: "hermes_app/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard call.method == "startDrag" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let event = NSApp.currentEvent {
        self?.performDrag(with: event)
      }
      result(nil)
    }

    super.awakeFromNib()
  }

  static func clipboardFilePaths(from pasteboard: NSPasteboard) -> [String] {
    let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) ?? []
    return urls.compactMap { object in
      guard let url = object as? NSURL, url.isFileURL else { return nil }
      return url.path
    }
  }
}
