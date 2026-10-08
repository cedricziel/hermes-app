import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for activity in connectionOptions.userActivities {
      _ = ChatHandoff.shared.receive(activity)
    }
    // The live_activities plugin only hears taps while the app runs; a tap
    // that launched it is kept for Dart to ask for.
    LiveActivityLaunch.shared.receive(connectionOptions.urlContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if !ChatHandoff.shared.receive(userActivity) {
      super.scene(scene, continue: userActivity)
    }
  }

  override func scene(_ scene: UIScene, didFailToContinueUserActivityWithType type: String, error: Error) {
    ChatHandoff.shared.failed(type)
    super.scene(scene, didFailToContinueUserActivityWithType: type, error: error)
  }
}
