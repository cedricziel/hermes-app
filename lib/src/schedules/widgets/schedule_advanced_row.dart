import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';

/// The row that shows or hides the advanced fields under it.
class ScheduleAdvancedRow extends StatelessWidget {
  const ScheduleAdvancedRow({
    super.key,
    required this.open,
    required this.onTap,
  });

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      expanded: open,
      child: GroupedRowInk(
        onTap: onTap,
        child: GroupedRow(
          title: context.l10n.schedulesFormAdvanced,
          trailing: AnimatedRotation(
            turns: open ? 0.25 : 0,
            duration: const Duration(milliseconds: 150),
            child: AppIcon(
              AppIcons.chevronRight,
              size: 18,
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
      ),
    ),
  );
}
