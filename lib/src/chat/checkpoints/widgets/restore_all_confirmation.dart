import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../checkpoint_models.dart';
import 'restore_confirmation_layout.dart';

/// "Restore all files?": the content and buttons of the confirmation, for
/// `showAdaptiveSheet`. It says what the server does: files go back, files
/// created later stay, and the last message and the answers after it are
/// removed from the chat, whichever checkpoint is picked.
///
/// [differingFiles] is null when the changes could not be read ("Some files
/// differ now."). [quotedPrompt] is the app's last prompt, the message the
/// server is expected to remove; it is a preview shown here only, capped at a
/// few lines with a fade, and hidden when null. While [replying] the button
/// is disabled with its reason.
class RestoreAllConfirmation extends StatelessWidget {
  const RestoreAllConfirmation({
    super.key,
    required this.timeLabel,
    required this.reason,
    this.differingFiles,
    this.quotedPrompt,
    this.replying = false,
    required this.onConfirm,
    required this.onCancel,
  });

  final String timeLabel;
  final CheckpointReason reason;
  final int? differingFiles;
  final String? quotedPrompt;
  final bool replying;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final count = differingFiles;
    final lines = [
      count == null
          ? l10n.chatCheckpointsRestoreAllDifferUnknown
          : l10n.chatCheckpointsRestoreAllDifferCount(count),
      l10n.chatCheckpointsRestoreAllLaterFiles,
      l10n.chatCheckpointsRestoreAllSaveFirst,
      l10n.chatCheckpointsRestoreAllNotCaptured,
      l10n.chatCheckpointsRestoreAllOtherChat,
    ];
    final quote = quotedPrompt;
    return RestoreConfirmationLayout(
      title: l10n.chatCheckpointsRestoreAllTitle,
      cancelLabel: l10n.chatCheckpointsRestoreCancel,
      confirmLabel: l10n.chatCheckpointsRestoreAllConfirm,
      onCancel: onCancel,
      onConfirm: replying ? null : onConfirm,
      footer: replying
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: AppIcon(AppIcons.info, size: 18, color: subtle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(l10n.chatCheckpointsRestoreAllReplying),
                  ),
                ),
              ],
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.chatCheckpointsRestoreAllIntro(timeLabel, reason.name)),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(16),
                      child: const Text('•'),
                    ),
                  ),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Divider(height: 1),
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
                  l10n.chatCheckpointsRestoreAllRemovesMessages,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (quote != null) ...[
            const SizedBox(height: 12),
            _QuotedPrompt(
              text: quote,
              label: l10n.chatCheckpointsRestoreAllQuoteLabel,
              hint: l10n.chatCheckpointsRestoreAllQuoteHint,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.chatCheckpointsRestoreAllNote,
            style: TextStyle(fontSize: 13, color: subtle),
          ),
        ],
      ),
    );
  }
}

/// How many lines of the quoted message show before the fade.
const kQuotedPromptMaxLines = 4;

/// The user's own message in a tinted box, cut after a few lines with a fade
/// at the bottom, and the hint that it goes back into the message box.
class _QuotedPrompt extends StatelessWidget {
  const _QuotedPrompt({
    required this.text,
    required this.label,
    required this.hint,
  });

  final String text;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return Semantics(
      container: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.06),
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: direction,
                  textScaler: scaler,
                  maxLines: kQuotedPromptMaxLines,
                )..layout(maxWidth: constraints.maxWidth);
                final cut = painter.didExceedMaxLines;
                painter.dispose();
                final quote = Text(
                  text,
                  maxLines: kQuotedPromptMaxLines,
                  overflow: TextOverflow.clip,
                );
                if (!cut) return quote;
                return ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.55, 1],
                  ).createShader(rect),
                  child: quote,
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: TextStyle(
                fontSize: 13,
                color: context.hermesColors.subtleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
