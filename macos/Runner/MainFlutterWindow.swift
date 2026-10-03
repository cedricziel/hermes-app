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
}
