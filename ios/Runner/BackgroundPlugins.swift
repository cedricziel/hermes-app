import Flutter
import device_info_plus
import flutter_local_notifications
import flutter_secure_storage_darwin
import home_widget
import package_info_plus
import shared_preferences_foundation
import workmanager_apple

/// The plugins a background engine needs to reach Hermes: the session in the
/// keychain, the saved server, telemetry, notifications, the snapshot for
/// widgets and the task scheduler. A second engine
/// must not get `GeneratedPluginRegistrant`'s whole list: several plugins act
/// as application or scene delegates (share, URL and Live Activity handling),
/// and registering them twice would handle every URL and share twice.
///
/// `home_widget` and `workmanager_apple` still add themselves as delegates of
/// the app, as they do in their own background engines. Both only matter at
/// launch or for a URL the first instance already took, so a second copy is
/// harmless.
///
/// Consumers pass this to their plugin's registrant callback, for example
/// `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback`.
enum BackgroundPlugins {
  static func register(with registry: FlutterPluginRegistry) {
    if let registrar = registry.registrar(forPlugin: "FlutterSecureStorageDarwinPlugin") {
      FlutterSecureStorageDarwinPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "SharedPreferencesPlugin") {
      SharedPreferencesPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin") {
      FPPPackageInfoPlusPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "FPPDeviceInfoPlusPlugin") {
      FPPDeviceInfoPlusPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin") {
      FlutterLocalNotificationsPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "HomeWidgetPlugin") {
      HomeWidgetPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "WorkmanagerPlugin") {
      WorkmanagerPlugin.register(with: registrar)
    }
  }
}
