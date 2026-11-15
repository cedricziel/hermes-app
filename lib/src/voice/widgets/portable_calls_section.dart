import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_list.dart';

/// The switch that turns voice calls on for this device, with the note that
/// they are new on this platform.
class PortableCallsSection extends StatelessWidget {
  const PortableCallsSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GroupedSection(
      footer: l10n.voiceCallsDeviceNote,
      children: [
        GroupedSwitchRow(
          key: const Key('portable-calls-switch'),
          title: l10n.voiceCallsDeviceTitle,
          titleMaxLines: null,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
