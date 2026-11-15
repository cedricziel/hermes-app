import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/motion_spinner.dart';
import '../whatsapp/whatsapp_pairing.dart';
import 'pairing_buttons.dart';

/// "Preparing WhatsApp on your server..." while the server installs packages
/// or starts its bridge: a spinner, the title, the stage word ("Installing",
/// "Starting", or "Working..." for a status the app does not know) as a
/// polite live region, a muted line that this can take a few minutes, and the
/// outlined "Cancel setup". There is no percentage, because the server gives
/// none.
class PairingStageCard extends StatelessWidget {
  const PairingStageCard({
    super.key,
    required this.stage,
    required this.onCancel,
    this.handset = true,
  });

  final WhatsAppWorkStage stage;
  final VoidCallback onCancel;
  final bool handset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final stageWord = switch (stage) {
      WhatsAppWorkStage.installing => l10n.messagingWhatsappStageInstalling,
      WhatsAppWorkStage.starting => l10n.messagingWhatsappStageStarting,
      WhatsAppWorkStage.other => l10n.messagingWhatsappStageWorking,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(metrics.radius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: MotionSpinner(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        l10n.messagingWhatsappPreparingTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Semantics(liveRegion: true, child: Text(stageWord)),
                      Text(
                        l10n.messagingWhatsappPreparingDetail,
                        style: TextStyle(
                          fontSize: metrics.subtitleSize,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        PairingActions(
          handset: handset,
          children: [
            PairingButton.outlined(
              label: l10n.messagingWhatsappCancelSetup,
              onPressed: onCancel,
            ),
          ],
        ),
      ],
    );
  }
}
