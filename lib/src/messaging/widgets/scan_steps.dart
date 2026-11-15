import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// The four steps for scanning the code with WhatsApp, numbered, text only.
/// Each step is one accessibility node ("1. Open WhatsApp ..."); a long step
/// wraps under its own text, not under its number.
class ScanSteps extends StatelessWidget {
  const ScanSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      l10n.messagingWhatsappStep1,
      l10n.messagingWhatsappStep2,
      l10n.messagingWhatsappStep3,
      l10n.messagingWhatsappStep4,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final (i, step) in steps.indexed)
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wide enough for "4." at any text size, so the lines of every
                // step start at the same x.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.textScalerOf(context).scale(22),
                  ),
                  child: Text('${i + 1}.'),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(step)),
              ],
            ),
          ),
      ],
    );
  }
}
