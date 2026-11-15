import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/dialog_presentation.dart';

/// From this window width the call opens as a dialog over the chat, as on
/// every Mac width; narrower windows get a full-screen page.
const double kCallDialogBreakpoint = 760;

/// The call dialog's width.
const double kCallDialogWidth = 480;

/// Opens the call screen [builder] makes: a full-screen page on a phone, a
/// 480 pt dialog from [kCallDialogBreakpoint] and on the Mac (never a sheet).
/// Closing either leaves the call running; the screen's End ends it.
Future<void> showVoiceCall(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final mac = Theme.of(context).platform == TargetPlatform.macOS;
  if (mac || MediaQuery.sizeOf(context).width >= kCallDialogBreakpoint) {
    return showAppDialog<void>(
      context: context,
      builder: (dialog) => _CallDialog(child: builder(dialog)),
    );
  }
  return Navigator.of(context)
      .push<void>(MaterialPageRoute(fullscreenDialog: true, builder: builder));
}

class _CallDialog extends StatelessWidget {
  const _CallDialog({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      key: const Key('voice-call-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: kCallDialogWidth,
        height: (height - 48).clamp(0, 760),
        child: child,
      ),
    );
  }
}

/// Whether the system has a settings page for microphone access that a link
/// can open. Android and Linux have none this app can reach without another
/// plugin, so a denied microphone there only offers Allow again.
bool canOpenMicrophoneSettings(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS || TargetPlatform.macOS || TargetPlatform.windows => true,
  _ => false,
};

/// Opens the system page for microphone access; throws when it cannot.
Future<void> openMicrophoneSettings(TargetPlatform platform) async {
  final link = switch (platform) {
    TargetPlatform.iOS => 'app-settings:',
    TargetPlatform.macOS => 'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
    TargetPlatform.windows => 'ms-settings:privacy-microphone',
    _ => null,
  };
  if (link == null || !await launchUrl(Uri.parse(link))) {
    throw StateError('Settings could not be opened');
  }
}
