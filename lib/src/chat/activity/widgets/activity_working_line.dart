import 'package:flutter/material.dart';

import '../../../theme/hermes_theme.dart';
import '../../../widgets/busy_bar.dart';

/// A line under Now for work the user started and can leave, such as
/// "Compressing the conversation…": the words and a thin progress bar that
/// stops moving when the system asks for less motion.
///
/// It is not a Needs-you item and never marks the Activity button; it only
/// says that something runs. Takes plain values only.
class ActivityWorkingLine extends StatelessWidget {
  const ActivityWorkingLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: context.hermesColors.subtleText,
              ),
            ),
            const SizedBox(height: 6),
            const BusyBar(minHeight: 2),
          ],
        ),
      ),
    ),
  );
}
