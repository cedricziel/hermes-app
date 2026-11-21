import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../auth/auth_controller.dart';
import '../../deep_links/deep_link_listener.dart';
import '../../deep_links/deep_link_source.dart';
import '../../spotlight/spotlight_index.dart';
import '../../spotlight/spotlight_links.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// The system search index and the deep links that arrive through it.
///
/// [launchArguments] are `main`'s arguments: on Linux a link that started the
/// app is in them (see [withLaunchLink]).
List<SingleChildWidget> deepLinkProviders(
  Telemetry telemetry, {
  List<String> launchArguments = const [],
}) => [
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
      if (!deepLinksSupported(defaultTargetPlatform)) return null;
      return DeepLinks(
        links: linksWithSpotlight(
          withLaunchLink(AppLinks().uriLinkStream, launchArguments),
          context.read<SpotlightIndex>(),
          events: telemetry.events(),
        ),
        signedOut: context.read<AuthController>().signedOut,
        breadcrumbs: context.read<Breadcrumbs>(),
      );
    },
  ),
];
