import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/grouped_list.dart';
import '../toolset_copy.dart';
import '../toolset_risk.dart';

/// What a risky toolset lets Hermes change: a note with a 1 pt border in the
/// text colour, a shield, a bold title and one plain sentence. It sits before
/// anything the user can change. A toolset that asks before it is switched on
/// ([confirmLevel]) adds that to the note. The note is one element for a
/// screen reader, the title and then the sentence.
class RiskNote extends StatelessWidget {
  const RiskNote({super.key, required this.kind, this.confirmLevel = false});

  final ToolsetRiskKind kind;
  final bool confirmLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final color = Theme.of(context).colorScheme.onSurface;
    final title = toolsetRiskTitle(l10n, kind);
    final sentence = toolsetRiskSentence(l10n, kind);
    final asks = confirmLevel ? l10n.toolsRiskAsks : null;
    return Semantics(
      container: true,
      label: asks == null ? '$title. $sentence' : '$title. $sentence $asks',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(metrics.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(
                AppIcons.shield,
                size: MediaQuery.textScalerOf(context).scale(20),
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: metrics.titleSize,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sentence,
                      style: TextStyle(
                        fontSize: metrics.subtitleSize,
                        color: color,
                      ),
                    ),
                    if (asks != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          asks,
                          style: TextStyle(
                            fontSize: metrics.subtitleSize,
                            color: color,
                          ),
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
