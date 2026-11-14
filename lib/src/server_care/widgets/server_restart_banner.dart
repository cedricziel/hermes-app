import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/busy_bar.dart';

/// How long the "ready" banner stays before it asks to be removed.
const Duration kServerReadyBannerDuration = Duration(seconds: 6);

/// The strip under the app bar while Hermes restarts after an update, and the
/// "ready" note after it. At least 44 pt tall, in the info tint, with an icon
/// and words. A screen reader hears it once, politely, when it appears.
class ServerRestartBanner extends StatefulWidget {
  /// Hermes is restarting; a tap opens the update page.
  const ServerRestartBanner.restarting({super.key, required this.onTap})
    : version = null,
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
  }) : onTap = null;

  final VoidCallback? onTap;
  final String? version;
  final VoidCallback? onClose;
  final VoidCallback? onAutoDismiss;

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
    final text = ready
        ? 'Hermes ${widget.version} is ready'
        : 'Hermes is restarting after the update. Chats continue when '
              "it's back.";
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
        child: ConstrainedBox(
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
                      tooltip: 'Close',
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
        ),
      ),
    );
  }
}
