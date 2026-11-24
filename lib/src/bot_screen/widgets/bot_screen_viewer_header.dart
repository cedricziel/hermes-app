import 'package:flutter/material.dart';

import '../../macos/mac_window.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_icon_button.dart';
import 'bot_screen_viewer_view.dart' show BotScreenViewerPresentation;

/// The button in the viewer's header: Take over or Hand Back. It is disabled
/// while [onPressed] is null (a take over or hand back on its way).
class BotScreenHeaderAction {
  const BotScreenHeaderAction({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;
}

/// The bar above the screen viewer's picture: Close, the profile, who is in
/// control, and an optional [action].
class BotScreenViewerHeader extends StatelessWidget {
  const BotScreenViewerHeader({
    super.key,
    required this.profile,
    required this.control,
    required this.inControl,
    required this.action,
    required this.presentation,
    required this.onClose,
  });

  final String profile;
  final String? control;

  /// Whether [control] says this device is in control, which it shows in the
  /// frame's color.
  final bool inControl;
  final BotScreenHeaderAction? action;
  final BotScreenViewerPresentation presentation;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final overlay = presentation == BotScreenViewerPresentation.overlay;
    final theme = Theme.of(context);
    final height = switch (chrome) {
      PlatformChrome.ios => kAppleNavBarHeight,
      PlatformChrome.macos => kMacToolbarHeight,
      PlatformChrome.material => kToolbarHeight,
    };
    final muted = context.hermesColors.subtleText;
    final close = NamedIconButton(
      label: 'Close',
      tooltip: overlay || chrome == PlatformChrome.macos ? 'Close (Esc)' : null,
      icon: AppIcons.close,
      iconSize: 22,
      onPressed: onClose,
    );
    final bar = SizedBox(
      height: height,
      // The bar's height is fixed, so its text stops growing at a cap, as the
      // labels of `AdaptiveTabBar` do, and leaves larger text to the Large
      // Content Viewer. The 44 pt iOS bar holds its two lines up to 1.1x.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: chrome == PlatformChrome.ios ? 1.1 : 1.3,
        child: Row(
          children: [
            // The viewer covers the window, traffic lights included.
            if (chrome == PlatformChrome.macos)
              const SizedBox(width: kMacTrafficLightsWidth)
            else
              const SizedBox(width: 4),
            if (chrome != PlatformChrome.macos) close,
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      control ?? 'Bot screen',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: inControl ? context.hermesColors.warning : muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (action case final action?) ...[
              const SizedBox(width: 8),
              _HeaderAction(action: action),
            ],
            if (chrome == PlatformChrome.macos) close,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
    // A Mac window moves by its toolbar.
    return chrome == PlatformChrome.macos ? MacWindowDragArea(child: bar) : bar;
  }
}

/// A button in the header: Take over or Hand Back.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.action});

  final BotScreenHeaderAction action;

  @override
  Widget build(BuildContext context) {
    final height = switch (platformChromeOf(context)) {
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
      PlatformChrome.material => 36.0,
    };
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: action.onPressed,
      child: Text(action.label),
    );
  }
}
