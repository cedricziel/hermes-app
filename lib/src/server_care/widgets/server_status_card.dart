import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';

/// How a [ServerStatusCard] reads. Each tone has its own icon, so the state
/// never rests on colour alone.
enum ServerStatusTone { loading, healthy, info, warning, error }

/// The card's one button.
class ServerStatusButton {
  const ServerStatusButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// Outlined for a button that only looks (Show logs, Run again); filled for
  /// one that fixes something.
  final bool outlined;
}

/// The headline of the Server screen, and the summary of a Server check: an
/// icon tile, one sentence, an optional second line and at most one button.
class ServerStatusCard extends StatelessWidget {
  const ServerStatusCard({
    super.key,
    required this.tone,
    required this.title,
    this.detail,
    this.button,
  });

  final ServerStatusTone tone;
  final String title;
  final String? detail;
  final ServerStatusButton? button;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final detail = this.detail;
    final button = this.button;
    final iconColor = switch (tone) {
      ServerStatusTone.loading => colors.subtleText,
      ServerStatusTone.healthy => colors.success,
      ServerStatusTone.info => scheme.primary,
      ServerStatusTone.warning => colors.warning,
      ServerStatusTone.error => scheme.error,
    };
    final icon = switch (tone) {
      ServerStatusTone.loading => null,
      ServerStatusTone.healthy => AppIcons.checkCircle,
      ServerStatusTone.info => AppIcons.info,
      ServerStatusTone.warning => AppIcons.warning,
      ServerStatusTone.error => AppIcons.error,
    };
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radius),
          side: BorderSide(color: scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The sentence names the state, so the picture is skipped.
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerHighest,
                  ),
                  child: icon == null
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : AppIcon(icon, size: 22, color: iconColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: mac ? 15 : 17,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          if (detail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                detail,
                                style: TextStyle(
                                  fontSize: mac ? 12 : metrics.subtitleSize,
                                  color: colors.subtleText,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (button != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: button.outlined
                            ? OutlinedButton(
                                style: buttonStyle,
                                onPressed: button.onPressed,
                                child: Text(button.label),
                              )
                            : FilledButton(
                                style: buttonStyle,
                                onPressed: button.onPressed,
                                child: Text(button.label),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
