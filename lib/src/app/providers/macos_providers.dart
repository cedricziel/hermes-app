import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../auth/auth_controller.dart';
import '../../api/hermes_repositories.dart';
import '../../chat/queue_storage/queue_persistence.dart';
import '../../drag_out/drag_out_source.dart';
import '../../drag_out/drag_out_telemetry.dart';
import '../../drag_out/mac_drag_out_source.dart';
import '../../macos/dock/dock_menu_bridge.dart';
import '../../macos/dock/dock_menu_controller.dart';
import '../../macos/mac_window.dart';
import '../../app_lock/app_lock_controller.dart';
import '../../quick_panel/global_shortcut.dart';
import '../../quick_panel/quick_panel_shortcut.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';
import '../../windows/conversation_windows.dart';
import '../../windows/desktop_conversation_windows.dart';

/// The global shortcut and drag out, which only exist on a Mac.
List<SingleChildWidget> macosInputProviders(Telemetry telemetry) => [
  Provider<GlobalShortcut?>(
    create: (_) => MacWindow.enabled ? ChannelGlobalShortcut() : null,
  ),
  // Null where nothing can be dragged out (every platform but macOS).
  // One source for the engine: a reconnect only swaps its telemetry, so
  // a drop in flight is still answered and later drops are logged
  // against the new server.
  ProxyProvider2<HermesRepositories?, Breadcrumbs, DragOutSource?>(
    update: (_, repositories, breadcrumbs, previous) {
      if (!MacDragOutSource.supported) return null;
      final telemetry = DragOutTelemetry.forConnection(
        repositories?.telemetry ?? const ConnectionTelemetry(),
        breadcrumbs,
      );
      if (previous case final MacDragOutSource source) {
        return source..telemetry = telemetry;
      }
      return MacDragOutSource(telemetry: telemetry);
    },
    dispose: (_, source) {
      if (source case final MacDragOutSource mac) mac.dispose();
    },
  ),
];

/// Conversation windows (and the quick panel shortcut they carry).
List<SingleChildWidget> macosWindowProviders(Telemetry telemetry) => [
  ChangeNotifierProvider<ConversationWindows?>(
    lazy: false,
    create: (context) {
      if (!MacWindow.enabled) return null;
      final auth = context.read<AuthController>();
      final queues = context.read<QueuePersistence>();
      final windows = ConversationWindows(
        host: DesktopConversationWindowHost(),
        store: ConversationWindowStore(SharedPreferencesAsync()),
        ownerKey: () => windowSessionOwnerKey(auth),
        connection: () {
          final baseUrl = auth.baseUrl;
          if (!auth.protectedRequestsAllowed ||
              auth.state != HermesConnectionState.ready ||
              baseUrl == null) {
            return null;
          }
          return (
            baseUrl: baseUrl,
            authRequired: auth.status?.authRequired ?? true,
          );
        },
        headers: auth.windowAuthHeaders,
        queueStore: queues.open,
        queueAllowed: () => queues.allowed,
        breadcrumbs: context.read<Breadcrumbs>(),
        events: telemetry.events(),
      );
      windows.bindSession(auth);
      windows.bindQueueAccess(queues);
      if (context.read<GlobalShortcut?>() case final shortcut?) {
        QuickPanelShortcut(
          shortcut: shortcut,
          windows: windows,
          events: telemetry.events(),
          breadcrumbs: context.read<Breadcrumbs>(),
        ).start();
      }
      return windows;
    },
  ),
];

/// The Dock menu.
List<SingleChildWidget> macosDockProviders(Telemetry telemetry) => [
  ChangeNotifierProvider<DockMenuController?>(
    lazy: false,
    create: (context) => MacWindow.enabled
        ? DockMenuController(
            bridge: DockMenuBridge(),
            unlock: context.read<AppLockController>().unlock,
            breadcrumbs: context.read<Breadcrumbs>(),
            events: telemetry.events(),
          )
        : null,
  ),
];
