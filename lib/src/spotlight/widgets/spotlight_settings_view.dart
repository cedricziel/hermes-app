import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';

/// The Spotlight dialog's content: the switch and what it does to the
/// chats' titles and messages.
class SpotlightSettingsView extends StatelessWidget {
  const SpotlightSettingsView({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GroupedSection(
    footer:
        "Your recent chats' titles and latest messages become searchable on "
        'this device while it is unlocked. Turning this off removes them.',
    children: [
      GroupedSwitchRow(
        key: const Key('spotlight-switch'),
        title: 'Show chats in Spotlight',
        value: enabled,
        onChanged: onChanged,
      ),
    ],
  );
}
