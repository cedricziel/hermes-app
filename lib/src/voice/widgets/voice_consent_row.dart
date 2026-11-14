import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_list.dart';

/// The bordered card on the call start screen: what automatic sending means,
/// then the switch that allows it for this call only. Nothing here is stored.
class VoiceConsentRow extends StatelessWidget {
  const VoiceConsentRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.showSentence = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// False leaves the sentence out, for a screen that shows it elsewhere and
  /// keeps only the switch in reach.
  final bool showSentence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showSentence)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                l10n.voiceConsentSentence,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          GroupedSwitchRow(
            title: l10n.voiceConsentSwitch,
            titleMaxLines: null,
            subtitle: l10n.voiceConsentSwitchSubtitle,
            subtitleMaxLines: null,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
