import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../macos/mac_window.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/busy_bar.dart';

/// How long the "ready" banner stays before it asks to be removed.
const Duration kServerReadyBannerDuration = Duration(seconds: 6);

/// The strip under the app bar while Hermes restarts after an update, and the
/// "ready" note after it. At least 44 pt tall, in the info tint, with an icon
/// and words. A screen reader hears it once, politely, when it appears.
class ServerRestartBanner extends StatefulWidget {
  /// Hermes is restarting; a tap opens the update page.
  const ServerRestartBanner.restarting({
    super.key,
    required this.onTap,
    this.topInset = 0,
  }) : version = null,
       onClose = null,
       onAutoDismiss = null;

  /// Hermes is back on [version]. [onClose] is the close button;
  /// [onAutoDismiss] fires after [kServerReadyBannerDuration] unless the
  /// system asks for reduced motion, which keeps the banner until closed.
  const ServerRestartBanner.ready({
    super.key,
    required String this.version,
    required VoidCallback this.onClose,
    this.onAutoDismiss,
    this.topInset = 0,
  }) : onTap = null;

  final VoidCallback? onTap;
  final String? version;
  final VoidCallback? onClose;
  final VoidCallback? onAutoDismiss;

  /// The system's inset above the banner (the status bar, a notch or the Mac
  /// title bar): the background is painted through it and the content sits
  /// below it. On a Mac window the strip drags the window.
  final double topInset;

  bool get _ready => version != null;

  @override
  State<ServerRestartBanner> createState() => _ServerRestartBannerState();
}

class _ServerRestartBannerState extends State<ServerRestartBanner> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arm();
  }

  @override
  void didUpdateWidget(ServerRestartBanner old) {
    super.didUpdateWidget(old);
    if (old._ready != widget._ready ||
        old.onAutoDismiss != widget.onAutoDismiss) {
      _arm();
    }
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    final onDismiss = widget.onAutoDismiss;
    if (!widget._ready || onDismiss == null || reduceMotionOf(context)) return;
    _timer = Timer(kServerReadyBannerDuration, onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final ready = widget._ready;
    final l10n = context.l10n;
    final text = ready
        ? l10n.serverCareRestartBannerReady(widget.version!)
        : l10n.serverCareRestartBannerRestarting;
    final textStyle = TextStyle(fontSize: 14, color: scheme.onSurface);
    final icon = ExcludeSemantics(
      child: AppIcon(
        ready ? AppIcons.checkCircle : AppIcons.info,
        size: 20,
        color: ready ? colors.success : colors.link,
      ),
    );
    final background = Color.alphaBlend(
      colors.link.withValues(alpha: 0.08),
      scheme.surfaceContainerHighest,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.topInset > 0) _inset(context),
            _content(context, ready, text, textStyle, icon, l10n),
          ],
        ),
      ),
    );
  }

  Widget _inset(BuildContext context) {
    final strip = ExcludeSemantics(child: SizedBox(height: widget.topInset));
    return platformChromeOf(context) == PlatformChrome.macos
        ? MacWindowDragArea(child: strip)
        : strip;
  }

  Widget _content(
    BuildContext context,
    bool ready,
    String text,
    TextStyle textStyle,
    Widget icon,
    AppLocalizations l10n,
  ) {
    final colors = context.hermesColors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: ready
          ? Row(
              children: [
                const SizedBox(width: 16),
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(text, style: textStyle),
                  ),
                ),
                IconButton(
                  tooltip: l10n.serverCareRestartBannerClose,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: widget.onClose,
                  icon: const AppIcon(AppIcons.close, size: 18),
                ),
              ],
            )
          : MergeSemantics(
              child: Semantics(
                button: true,
                child: InkWell(
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: Text(text, style: textStyle)),
                        const SizedBox(width: 8),
                        ExcludeSemantics(
                          child: AppIcon(
                            AppIcons.chevronRight,
                            size: 20,
                            color: colors.subtleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
