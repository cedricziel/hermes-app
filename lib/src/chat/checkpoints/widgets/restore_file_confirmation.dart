import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../checkpoint_models.dart';
import 'restore_confirmation_layout.dart';

/// "Restore this file?": the content and buttons of the confirmation, for
/// `showAdaptiveSheet`. It takes the finished relative time ("12 min ago") and
/// the file's name, which belongs to the confirmation the user asked for and
/// is never logged. Allowed while the agent works, with a warning line.
class RestoreFileConfirmation extends StatelessWidget {
  const RestoreFileConfirmation({
    super.key,
    required this.fileName,
    required this.timeLabel,
    required this.reason,
    this.agentWorking = false,
    required this.onConfirm,
    required this.onCancel,
  });

  final String fileName;
  final String timeLabel;
  final CheckpointReason reason;
  final bool agentWorking;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RestoreConfirmationLayout(
      title: l10n.chatCheckpointsRestoreFileTitle,
      cancelLabel: l10n.chatCheckpointsRestoreCancel,
      confirmLabel: l10n.chatCheckpointsRestoreFileConfirm,
      onCancel: onCancel,
      onConfirm: onConfirm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatCheckpointsRestoreFileBody(
              fileName,
              timeLabel,
              reason.name,
            ),
          ),
          if (agentWorking) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: AppIcon(
                    AppIcons.warning,
                    size: 18,
                    color: context.hermesColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.chatCheckpointsRestoreFileWorking,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
