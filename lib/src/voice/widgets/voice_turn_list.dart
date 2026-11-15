import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// The last turn of a call as two plain lines, under the hint: what the user
/// said (You) and what Hermes answered. Not bubbles; the thread holds the
/// rest. It draws nothing until there is a line to show.
///
/// The words live only in the open call screen. The caller leaves them out
/// while the caption of a turn being sent replaces them, once the call has
/// stopped and under App Lock.
class VoiceTurnList extends StatelessWidget {
  const VoiceTurnList({
    super.key,
    this.you = '',
    this.hermes = '',
    this.replyInChat = false,
  });

  /// What the user said, as it was sent.
  final String you;

  /// The reply as it streams in; empty until the first words arrive.
  final String hermes;

  /// Speak replies is off and the reply is done: the line says where to read
  /// it instead of repeating it.
  final bool replyInChat;

  /// Long words stop here with an ellipsis; the chat has the whole turn.
  static const youLines = 2, hermesLines = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final base = theme.textTheme.bodyMedium;
    Widget line(String name, String text, int maxLines, {bool note = false}) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$name  ',
              style: base?.copyWith(color: muted, fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: text,
              style: note
                  ? base?.copyWith(color: muted, fontStyle: FontStyle.italic)
                  : null,
            ),
          ],
        ),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }

    final lines = [
      if (you.isNotEmpty) line(l10n.voiceCallTurnYou, you, youLines),
      if (replyInChat)
        line(
          l10n.voiceCallTurnHermes,
          l10n.voiceCallReplyInChat,
          hermesLines,
          note: true,
        )
      else if (hermes.isNotEmpty)
        line(l10n.voiceCallTurnHermes, hermes, hermesLines),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          lines[i],
        ],
      ],
    );
  }
}
