import 'package:flutter/material.dart';

import '../../macos/mac_window.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_icon_button.dart';
import '../bot_screen_models.dart' show BotScreenControl, BotScreenViewerPhase;

/// Where the viewer is shown: a full-screen page on a phone, or a layer over
/// the whole window on a larger one.
enum BotScreenViewerPresentation { page, overlay }

final _darkThemes = <TargetPlatform, ThemeData>{};

/// The viewer's black look for [platform], made once.
ThemeData _darkTheme(TargetPlatform platform) => _darkThemes.putIfAbsent(
  platform,
  () => buildHermesDarkTheme().copyWith(platform: platform),
);

/// The screen viewer: a header that names the profile and who is in control,
/// and below it the live picture, or the reason there is none.
///
/// It draws [phase] and [control] and nothing else, so it needs no controller.
/// The picture is whatever [picture] draws, laid out at [aspectRatio], and can
/// be zoomed and panned. [onStart] (Start Screen, when the screen is off) and
/// [onRetry] (Try Again) are shown only when given, and so are the actions
/// that change who is in control: [onTakeOver] (while a live picture is only
/// watched), [onHandBack] (while this device is in control),
/// [onForceHandBack] (Hand back to Hermes, while someone else is in control
/// and [canForce]) and [onDismissLost] (the notice that control was lost).
class BotScreenViewerView extends StatelessWidget {
  const BotScreenViewerView({
    super.key,
    required this.phase,
    required this.profile,
    this.picture,
    this.aspectRatio = 16 / 10,
    this.presentation = BotScreenViewerPresentation.page,
    this.control = BotScreenControl.watching,
    this.lostText = 'Someone else took control.',
    this.canForce = false,
    this.onClose,
    this.onRetry,
    this.onStart,
    this.onTakeOver,
    this.onHandBack,
    this.onForceHandBack,
    this.onDismissLost,
  });

  final BotScreenViewerPhase phase;

  /// The profile's name, in the header.
  final String profile;
  final Widget? picture;
  final double aspectRatio;
  final BotScreenViewerPresentation presentation;

  /// Who is driving: this device, or only watching.
  final BotScreenControl control;

  /// What the notice of lost control says ("Hermes took control back." when
  /// the lease went back to Hermes).
  final String lostText;

  /// Whether the lease someone else holds can be handed back to Hermes from
  /// here (a person holds it under a viewer id this app does not).
  final bool canForce;
  final VoidCallback? onClose;
  final VoidCallback? onRetry;
  final VoidCallback? onStart;
  final VoidCallback? onTakeOver;
  final VoidCallback? onHandBack;
  final VoidCallback? onForceHandBack;
  final VoidCallback? onDismissLost;

  bool get _live =>
      phase == BotScreenViewerPhase.live ||
      phase == BotScreenViewerPhase.reconnecting;

  /// Whether this device is driving, a hand back on its way included.
  bool get _inControl =>
      (control == BotScreenControl.inControl ||
          control == BotScreenControl.releasing) &&
      _live;

  /// Who is in control, as far as the viewer knows.
  String? get _control => switch (phase) {
    _ when _inControl => "You're in control",
    BotScreenViewerPhase.live ||
    BotScreenViewerPhase.reconnecting => 'Hermes is in control',
    BotScreenViewerPhase.blanked => 'Someone else is in control',
    _ => null,
  };

  /// The header's action: Hand Back while in control, Take over while only
  /// watching a live picture.
  Widget? get _action {
    if (control == BotScreenControl.releasing && _live) {
      return const _HeaderAction(label: 'Handing back…', onPressed: null);
    }
    if (_inControl) {
      return _HeaderAction(label: 'Hand Back', onPressed: onHandBack);
    }
    if (phase != BotScreenViewerPhase.live) return null;
    if (control == BotScreenControl.acquiring) {
      return const _HeaderAction(label: 'Taking over…', onPressed: null);
    }
    final takeOver = onTakeOver;
    return takeOver == null
        ? null
        : _HeaderAction(label: 'Take over', onPressed: takeOver);
  }

  @override
  Widget build(BuildContext context) {
    // Like a photo viewer, the picture sits on black in both themes.
    final dark = _darkTheme(Theme.of(context).platform);
    return Theme(
      data: dark,
      child: Builder(
        builder: (context) => Material(
          color: Colors.black,
          // A notch beside a landscape phone, the home indicator.
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  profile: profile,
                  control: _control,
                  inControl: _inControl,
                  action: _action,
                  presentation: presentation,
                  onClose: onClose,
                ),
                if (control == BotScreenControl.lost &&
                    (_live || phase == BotScreenViewerPhase.blanked))
                  _Banner(text: lostText, onDismiss: onDismissLost),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final picture = this.picture;
    switch (phase) {
      case BotScreenViewerPhase.connecting ||
          BotScreenViewerPhase.live ||
          BotScreenViewerPhase.reconnecting ||
          BotScreenViewerPhase.blanked:
        // One stage for all four, so the zoom and the picture below it survive
        // a reconnect, a blank and coming back.
        final drawn =
            picture != null &&
            (phase == BotScreenViewerPhase.live ||
                phase == BotScreenViewerPhase.reconnecting);
        return Stack(
          fit: StackFit.expand,
          children: [
            _Picture(aspectRatio: aspectRatio, child: drawn ? picture : null),
            if (_inControl) const _ControlFrame(),
            if (drawn && phase == BotScreenViewerPhase.reconnecting)
              const IgnorePointer(child: ColoredBox(color: Colors.black54)),
            if (phase == BotScreenViewerPhase.blanked)
              _Notice(
                icon: AppIcons.lock,
                title: 'Someone else is in control',
                text: 'The picture returns when Hermes has control again.',
                action: canForce && onForceHandBack != null
                    ? ('Hand back to Hermes', onForceHandBack!)
                    : null,
              )
            else if (!drawn)
              const Center(child: _Busy('Connecting to the screen…'))
            else if (phase == BotScreenViewerPhase.reconnecting)
              const Center(child: _Busy('Reconnecting…')),
          ],
        );
      case BotScreenViewerPhase.off:
        return _Notice(
          icon: AppIcons.screen,
          title: 'The screen is off',
          text: 'It starts by itself when Hermes needs it.',
          action: onStart == null ? null : ('Start Screen', onStart!),
        );
      case BotScreenViewerPhase.notAllowed:
        return const _Notice(
          icon: AppIcons.blocked,
          title: "Viewing isn't allowed from this app",
          text: 'The server refused the connection to the screen.',
        );
      case BotScreenViewerPhase.unreachable:
        return _Notice(
          icon: AppIcons.warning,
          title: "Can't reach the screen",
          text: 'Check the connection to the server.',
          action: onRetry == null ? null : ('Try Again', onRetry!),
        );
      case BotScreenViewerPhase.failed:
        return _Notice(
          icon: AppIcons.warning,
          title: 'The screen stopped sending',
          text: 'The server ended the stream with an error.',
          action: onRetry == null ? null : ('Try Again', onRetry!),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
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
  final Widget? action;
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
          if (action != null) ...[const SizedBox(width: 8), action!],
          if (chrome == PlatformChrome.macos) close,
          const SizedBox(width: 8),
        ],
      ),
    );
    // A Mac window moves by its toolbar.
    return chrome == PlatformChrome.macos ? MacWindowDragArea(child: bar) : bar;
  }
}

/// A button in the header: Take over or Hand Back.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

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
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// A line under the header that says something happened to control.
class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.onDismiss});

  final String text;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: ColoredBox(
      color: Colors.white12,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(child: Text(text)),
            if (onDismiss != null)
              NamedIconButton(
                label: 'Dismiss',
                icon: AppIcons.close,
                iconSize: 18,
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    ),
  );
}

/// The edge of the stage while this device is in control: it takes no
/// pointer, so the picture below it keeps every gesture.
class _ControlFrame extends StatelessWidget {
  const _ControlFrame();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: context.hermesColors.warning, width: 3),
      ),
    ),
  );
}

/// The picture, kept in its aspect ratio and open to pinch, wheel and drag.
class _Picture extends StatelessWidget {
  const _Picture({required this.aspectRatio, required this.child});

  final double aspectRatio;
  final Widget? child;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    minScale: 1,
    maxScale: 4,
    child: Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: child == null
            ? const SizedBox.shrink()
            : Semantics(
                image: true,
                label: "Hermes's screen",
                child: ExcludeSemantics(child: child),
              ),
      ),
    ),
  );
}

class _Busy extends StatelessWidget {
  const _Busy(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(text)),
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final AppIconSet icon;
  final String title;
  final String text;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = this.action;
    final chrome = platformChromeOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(icon, size: 32, color: context.hermesColors.subtleText),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.hermesColors.subtleText,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    style: chrome == PlatformChrome.ios
                        ? FilledButton.styleFrom(
                            minimumSize: const Size(0, kAppleMinTapTarget),
                          )
                        : null,
                    onPressed: action.$2,
                    child: Text(action.$1),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
