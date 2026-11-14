import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/hermes_theme.dart';
import '../context_state.dart';
import 'context_format.dart';

/// The one action of the Context page: "Compress conversation…" as an
/// outlined button, never filled, because it removes older messages from the
/// model's view for good. The caption under it says what it does, or why it
/// is off ([refusal]). [overLimit] adds the note for a chat that uses more
/// than its window holds. Takes plain values and callbacks only.
class CompressConversationAction extends StatelessWidget {
  const CompressConversationAction({
    super.key,
    this.refusal,
    this.overLimit = false,
    this.onCompress,
  });

  final CompressRefusal? refusal;
  final bool overLimit;
  final VoidCallback? onCompress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.hermesColors.subtleText;
    final refusal = this.refusal;
    final caption = switch (refusal) {
      null => l10n.chatContextPageCompressCaption,
      CompressRefusal.replying => l10n.chatContextPageCompressReplying,
      CompressRefusal.disconnected => l10n.chatContextPageCompressDisconnected,
      CompressRefusal.compressing => l10n.chatContextPageCompressCompressing,
      CompressRefusal.unavailable ||
      CompressRefusal.locked => l10n.chatContextPageCompressUnavailable,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (overLimit) ...[
            Text(l10n.chatContextPageOverLimit),
            const SizedBox(height: 12),
          ],
          OutlinedButton(
            key: const Key('context-compress'),
            style: contextButtonStyle(context),
            onPressed: refusal == null ? onCompress : null,
            child: Text(
              l10n.chatContextPageCompress,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ),
    );
  }
}
