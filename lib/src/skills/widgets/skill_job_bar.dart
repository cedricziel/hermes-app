import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';
import '../../widgets/busy_bar.dart';

class SkillJobBar extends StatelessWidget {
  const SkillJobBar({super.key, required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.maxWidth),
          child: GroupedSection(
            children: [
              GroupedRow(
                title: '$title…',
                onTap: onTap,
                trailing: const SizedBox(
                  width: 44,
                  child: BusyBar(minHeight: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
