import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// The line under a call screen that says when the call ends by itself.
/// iOS keeps a call running in the background, so it has none.
enum VoiceCallFooter { none, androidLeave, desktopHide }

class VoiceCallFooterText extends StatelessWidget {
  const VoiceCallFooterText(this.footer, {super.key});

  final VoiceCallFooter footer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (footer) {
      VoiceCallFooter.none => null,
      VoiceCallFooter.androidLeave => l10n.voiceCallFooterAndroid,
      VoiceCallFooter.desktopHide => l10n.voiceCallFooterDesktop,
    };
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
