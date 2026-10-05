import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for activity in connectionOptions.userActivities {
      _ = ChatHandoff.shared.receive(activity)
    }
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
