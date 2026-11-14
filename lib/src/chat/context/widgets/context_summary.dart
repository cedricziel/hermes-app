import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/hermes_theme.dart';
import '../context_state.dart';
import 'context_fill_bar.dart';
import 'context_format.dart';

/// The head of Context details: the large percentage, the state word from
/// 80%, an 8 pt bar, the full counts and the model. [model] is shown here and
/// nowhere else, and is never recorded.
class ContextSummary extends StatelessWidget {
  const ContextSummary({
    super.key,
    required this.figures,
    required this.level,
    this.notUpToDate = false,
    this.model,
  });

  final ContextFigures figures;
  final ContextLevel level;
  final bool notUpToDate;
  final String? model;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final scheme = Theme.of(context).colorScheme;
    final levelColor = notUpToDate ? null : contextLevelColor(context, level);
    final barColor = notUpToDate
        ? subtle.withValues(alpha: 0.6)
        : levelColor ?? scheme.primary;
    final used = contextTokensFull(l10n, figures.used);
    final max = contextTokensFull(l10n, figures.max);
    final caption = figures.estimated == true
        ? l10n.chatContextCaptionEstimated(used, max)
        : l10n.chatContextCaption(used, max);
    final word = contextLevelWord(l10n, level);
    final modelName = model;
    final semanticsLabel = [
      contextBarLabel(l10n, figures),
      ?word,
      caption,
      if (notUpToDate) l10n.chatContextNotUpToDate,
      if (modelName != null && modelName.isNotEmpty)
        l10n.chatContextDetailsModel(modelName),
    ].join('. ');
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 4,
              children: [
                // Scales down rather than cut, so the percentage stays whole.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    l10n.chatContextPercent(figures.percent),
                    style: TextStyle(
                      fontSize: 40,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: notUpToDate ? subtle : levelColor,
                    ),
                  ),
                ),
                if (word == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      l10n.chatContextSummaryFilled,
                      style: TextStyle(fontSize: 15, color: subtle),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ContextStateWord(level: level, muted: notUpToDate),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ContextFillBar(
              fraction: figures.percent / 100,
              height: 8,
              color: barColor,
            ),
            const SizedBox(height: 8),
            Text(caption, style: const TextStyle(fontSize: 15)),
            if (notUpToDate)
              Text(
                l10n.chatContextNotUpToDate,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: subtle,
                ),
              ),
            if (modelName != null && modelName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.chatContextDetailsModel(modelName),
                style: TextStyle(fontSize: 13, color: subtle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
