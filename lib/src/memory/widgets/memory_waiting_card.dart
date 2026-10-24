import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/grouped_list.dart';

/// "2 changes waiting for you": opens the inbox from the top of the Memory
/// screen. The caller leaves it out when nothing waits.
class MemoryWaitingCard extends StatelessWidget {
  const MemoryWaitingCard({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      GroupedRow(
        key: const Key('memory-waiting-card'),
        title: count == 1
            ? '1 change waiting for you'
            : '$count changes waiting for you',
        subtitle: 'Not saved until you approve them',
        leading: GroupedTile(child: AppIcon(AppIcons.memory)),
        onTap: onTap,
      ),
    ],
  );
}
