import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';

/// The mark before the title of a chat that was branched from another, in the
/// chat list, the Mac source list and search results: 14 pt, 12 pt in the Mac
/// source list ([size]), muted, with 4 pt after it. It has no label of its
/// own; [branchTitled] adds "Branch" to the title's.
class BranchGlyph extends StatelessWidget {
  const BranchGlyph({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: AppIcon(
        AppIcons.branch,
        size: size,
        color: context.hermesColors.subtleText,
      ),
    ),
  );
}

/// [title], the row's visible title, read as "<title>, Branch" when [branch],
/// so the title stays the first words of the label.
Widget branchTitled(
  BuildContext context, {
  required bool branch,
  required String title,
  required Widget child,
}) => branch
    ? Semantics(
        label: '$title, ${context.l10n.chatWidgetsBranchRowLabel}',
        excludeSemantics: true,
        child: child,
      )
    : child;
