import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/busy_bar.dart';
import '../context_state.dart';
import 'context_fill_bar.dart';
import 'context_format.dart';

/// The Context row of the Activity panel: how full the chat's window is.
///
/// It takes plain values and callbacks. The state word with its icon appears
/// from 80%, the bar is decorative and the row's own label says what it
/// shows. At the largest text size the percentage moves under the label,
/// whole. [onOpen] null draws a row that does not open (no chevron).
class ContextRow extends StatelessWidget {
  const ContextRow({
    super.key,
    required this.figures,
    required this.level,
    this.notUpToDate = false,
    this.locked = false,
    this.compressing = false,
    this.suggestionVisible = false,
    this.onOpen,
    this.onCompress,
    this.onDismissSuggestion,
  });

  final ContextFigures figures;
  final ContextLevel level;

  /// The connection closed; the values are the last ones read.
  final bool notUpToDate;

  /// App Lock covers the app: only the percentage is drawn.
  final bool locked;
  final bool compressing;
  final bool suggestionVisible;
  final VoidCallback? onOpen;
  final VoidCallback? onCompress;
  final VoidCallback? onDismissSuggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.hermesColors;
    final subtle = colors.subtleText;
    final muted = notUpToDate;
    final levelColor = muted || locked
        ? null
        : contextLevelColor(context, level);
    final scheme = Theme.of(context).colorScheme;
    final barColor = muted
        ? subtle.withValues(alpha: 0.6)
        : levelColor ?? scheme.primary;
    final percentStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: muted ? subtle : levelColor,
    );
    final openable = onOpen != null && !locked;
    final big = contextLargeText(context);
    final state = locked
        ? const SizedBox.shrink()
        : ContextStateWord(level: level, muted: muted);
    final percent = Text(
      l10n.chatContextPercent(figures.percent),
      style: percentStyle,
    );
    final chevron = openable
        ? ExcludeSemantics(
            child: AppIcon(AppIcons.chevronRight, size: 20, color: subtle),
          )
        : null;
    final label = Text(
      l10n.chatContextLabel,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
    final showState = !locked && level != ContextLevel.normal;

    final Widget header;
    if (big) {
      header = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 2),
                percent,
                if (showState) ...[const SizedBox(height: 2), state],
              ],
            ),
          ),
          ?chevron,
        ],
      );
    } else {
      header = Row(
        children: [
          label,
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 2,
                children: [if (showState) state, percent],
              ),
            ),
          ),
          if (chevron != null) ...[const SizedBox(width: 4), chevron],
        ],
      );
    }

    final caption = locked || compressing ? null : _caption(l10n, figures);
    final suggestion =
        suggestionVisible && !locked && !compressing && onCompress != null;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (!locked) ...[
              const SizedBox(height: 8),
              if (compressing) ...[
                const ExcludeSemantics(child: BusyBar(minHeight: 2)),
                const SizedBox(height: 6),
                Text(
                  l10n.chatContextCompressing,
                  style: TextStyle(fontSize: 13, color: subtle),
                ),
              ] else ...[
                ContextFillBar(
                  fraction: figures.percent / 100,
                  height: 4,
                  color: barColor,
                ),
                if (caption != null) ...[
                  const SizedBox(height: 6),
                  Text(caption, style: TextStyle(fontSize: 13, color: subtle)),
                ],
              ],
              if (notUpToDate) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.chatContextNotUpToDate,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: subtle,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );

    final semanticsLabel = [
      contextBarLabel(l10n, figures),
      if (showState) contextLevelWord(l10n, level)!,
      if (compressing) l10n.chatContextCompressing,
      ?caption,
      if (notUpToDate) l10n.chatContextNotUpToDate,
    ].join('. ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          button: openable,
          label: semanticsLabel,
          onTap: openable ? onOpen : null,
          child: ExcludeSemantics(
            child: openable ? InkWell(onTap: onOpen, child: body) : body,
          ),
        ),
        if (suggestion)
          _Suggestion(onCompress: onCompress!, onDismiss: onDismissSuggestion),
      ],
    );
  }

  static String _caption(AppLocalizations l10n, ContextFigures figures) {
    final used = contextTokensShort(l10n, figures.used);
    final max = contextTokensShort(l10n, figures.max);
    return figures.estimated == true
        ? l10n.chatContextCaptionEstimated(used, max)
        : l10n.chatContextCaption(used, max);
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.onCompress, this.onDismiss});

  final VoidCallback onCompress;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = contextButtonStyle(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatContextSuggestion,
            style: const TextStyle(fontSize: 14),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                style: style,
                onPressed: onCompress,
                child: Text(l10n.chatContextSuggestionCompress),
              ),
              if (onDismiss != null)
                TextButton(
                  style: style,
                  onPressed: onDismiss,
                  child: Text(l10n.chatContextSuggestionDismiss),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
