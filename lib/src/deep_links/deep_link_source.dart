import 'dart:async';

import 'package:flutter/foundation.dart';

import 'deep_link_parser.dart';

/// Whether the `hermes` scheme is registered on [platform]: iOS, macOS and
/// Android in their manifests, Linux through the `.desktop` file's
/// `MimeType`. Windows registers none (it needs an installer).
bool deepLinksSupported(TargetPlatform platform, {bool web = kIsWeb}) =>
    !web &&
    switch (platform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.android ||
      TargetPlatform.linux => true,
      TargetPlatform.windows || TargetPlatform.fuchsia => false,
    };

/// [links] preceded by the `hermes://` link in the process's launch
/// [arguments], if any. The Linux plugin registers after the runner has read
/// the command line, so a link that launched the app is only in `main`'s
/// arguments; one sent by a later launch arrives on [links].
Stream<Uri> withLaunchLink(Stream<Uri> links, List<String> arguments) {
  Uri? launch;
  for (final argument in arguments) {
    final uri = Uri.tryParse(argument);
    if (uri != null && isHermesLink(uri)) {
      launch = uri;
      break;
    }
  }
  if (launch == null) return links;
  late StreamController<Uri> controller;
  StreamSubscription<Uri>? subscription;
  controller = StreamController<Uri>(
    onListen: () {
      subscription = links.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.add(launch!);
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}
