import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';

enum VoiceCallNoticeTone { info, warning }

/// One notice card of a call: an icon, a bold sentence and optional muted
/// detail. A warning carries the warning triangle, so the tone is never
/// colour alone. Screen readers announce it when it appears.
class VoiceCallNotice extends StatelessWidget {
  const VoiceCallNotice({
    super.key,
    required this.title,
    this.detail,
    this.tone = VoiceCallNoticeTone.info,
    this.icon,
  });

  final String title;
  final String? detail;
  final VoiceCallNoticeTone tone;

  /// Replaces the tone's own icon.
  final AppIconSet? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final warning = tone == VoiceCallNoticeTone.warning;
    final glyph = icon ?? (warning ? AppIcons.warning : AppIcons.info);
    final detail = this.detail;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: warning ? colors.error : colors.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  glyph.of(context),
                  size: 22,
                  color: warning ? colors.error : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
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
