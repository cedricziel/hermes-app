import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    private var shareChannel: FlutterMethodChannel?

    override func applicationDidFinishLaunching(_ notification: Notification) {
        if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "hermes_app/share", binaryMessenger: controller.engine.binaryMessenger
            )
            channel.setMethodCallHandler { call, result in
                if call.method == "take" {
                    result(ShareHandoff.take())
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
            shareChannel = channel
        }
        super.applicationDidFinishLaunching(notification)
    }

    /// The share extension opens `hermes-share://share` once it has left the
    /// content in the App Group container.
    override func application(_: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.scheme == ShareHandoff.urlScheme }) {
            shareChannel?.invokeMethod("shared", arguments: nil)
        }
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        return true
    }
}
