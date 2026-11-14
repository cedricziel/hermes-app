import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../api/hermes_repositories.dart';
import '../../auth/auth_controller.dart';
import '../../chat/media/media_source.dart';
import '../../chat/media/media_store.dart';
import '../../chat/media/quick_look.dart';
import '../../handoff/handoff_bridge.dart';
import '../../handoff/handoff_controller.dart';
import '../../network/network_signals.dart';
import '../../telemetry/telemetry.dart';

/// Handoff, the auth controller, the repositories over it and the media store.
List<SingleChildWidget> authProviders(Telemetry telemetry) => [
  ChangeNotifierProvider(
    lazy: false,
    create: (_) => HandoffController(HandoffBridge())..start(),
  ),
  ChangeNotifierProvider(
    create: (_) => AuthController(
      telemetry: telemetry.forConnection,
      networkSignals: ConnectivityNetworkSignals(),
    )..bootstrap(),
  ),
  ProxyProvider<AuthController, HermesRepositories?>(
    update: (_, auth, previous) => HermesRepositories.forAuth(auth, previous),
  ),
  // Downloaded files are deleted when the session ends, so this must be
  // listening from the start, not from the first file opened.
  Provider<MediaStore?>(
    lazy: false,
    create: (context) {
      final auth = context.read<AuthController>();
      return MediaStore(
          source: HermesMediaSource(() => auth.api),
          cacheDirectory: getApplicationCacheDirectory,
          quickLook: platformQuickLook(),
        )
        ..clearOnSignOut(auth.signedOut)
        // Copies of files that looked secret, which an app killed on the Files
        // page never got to delete, and files nobody opened again.
        ..wipeSecretCopies()
        ..sweep(mediaCacheMaxAge);
    },
    dispose: (_, store) => store?.dispose(),
  ),
];
