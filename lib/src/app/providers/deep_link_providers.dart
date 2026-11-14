import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../auth/auth_controller.dart';
import '../../deep_links/deep_link_listener.dart';
import '../../spotlight/spotlight_index.dart';
import '../../spotlight/spotlight_links.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// The system search index and the deep links that arrive through it.
List<SingleChildWidget> deepLinkProviders(Telemetry telemetry) => [
  // Where the system search is; nothing off iOS. Its taps are links, so
  // it sits before the deep links.
  Provider<SpotlightIndex>(
    create: (_) => SpotlightIndex.forPlatform(events: telemetry.events()),
    dispose: (_, index) => index.dispose(),
  ),
  // Above the screens, so a link opened on the sign-in screen waits for
  // the shell. Only where the `hermes` scheme is registered.
  ChangeNotifierProvider<DeepLinks?>(
    lazy: false,
    create: (context) {
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.iOS &&
              defaultTargetPlatform != TargetPlatform.macOS &&
              defaultTargetPlatform != TargetPlatform.android)) {
        return null;
      }
      return DeepLinks(
        links: linksWithSpotlight(
          AppLinks().uriLinkStream,
          context.read<SpotlightIndex>(),
          events: telemetry.events(),
        ),
        signedOut: context.read<AuthController>().signedOut,
        breadcrumbs: context.read<Breadcrumbs>(),
      );
    },
  ),
];
