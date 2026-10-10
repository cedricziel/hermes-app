import 'package:flutter/material.dart';

import '../../../widgets/grouped_list.dart';

/// The Settings section that shows or hides the menu bar item.
class MenuBarItemSection extends StatelessWidget {
  const MenuBarItemSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GroupedSection(
    footer:
        'Shows running replies and approvals in the menu bar. Hermes keeps '
        'running after its last window closes either way.',
    children: [
      GroupedSwitchRow(
        key: const ValueKey('setting-menuBarExtra'),
        title: 'Menu bar item',
        value: value,
        onChanged: onChanged,
      ),
    ],
  );
}
