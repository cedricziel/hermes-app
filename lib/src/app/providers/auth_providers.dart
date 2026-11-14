import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../api/hermes_repositories.dart';
import '../../auth/auth_controller.dart';
import '../../chat/media/media_source.dart';
import '../../chat/media/media_store.dart';
import '../../chat/media/quick_look.dart';
import '../../files/files_availability.dart';
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
  // Whether the server has the Files routes: asked once per connection, so
  // the entry points of Files stay hidden on an older Hermes.
  filesAvailabilityProvider(),
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
        ..wipeFileDownloads()
        ..sweep(mediaCacheMaxAge);
    },
    dispose: (_, store) => store?.dispose(),
  ),
];

/// Whether the server has the Files routes, asked once per connection (a new
/// API client asks again). A [ChangeNotifier], so it needs a notifier
/// provider: entry points watch it and appear when the probe answers.
SingleChildWidget filesAvailabilityProvider() =>
    ChangeNotifierProxyProvider<HermesRepositories?, FilesAvailability?>(
      create: (_) => null,
      update: (_, repositories, previous) {
        if (repositories == null) return null;
        if (previous != null &&
            identical(previous.connection, repositories.api)) {
          return previous;
        }
        return FilesAvailability.forRepositories(repositories);
      },
    );
