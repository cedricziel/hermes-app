import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_list.dart';

/// The Settings section with the "Show menu bar" switch of Windows and Linux.
class DesktopMenuBarSection extends StatelessWidget {
  const DesktopMenuBarSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      GroupedSwitchRow(
        key: const ValueKey('setting-desktopMenuBar'),
        title: context.l10n.settingsShowMenuBar,
        value: value,
        onChanged: onChanged,
      ),
    ],
  );
}
