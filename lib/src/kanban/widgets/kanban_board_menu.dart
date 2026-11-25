import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/named_popup_menu_button.dart';
import '../kanban_models.dart';

/// The app bar menu that switches boards, with a way to manage them.
class KanbanBoardMenu extends StatelessWidget {
  const KanbanBoardMenu({
    super.key,
    required this.boards,
    required this.selected,
    required this.onSelected,
    required this.onManage,
  });

  final List<KanbanBoardInfo> boards;

  /// The slug of the board on screen.
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return NamedPopupMenuButton<String>(
      label: context.l10n.kanbanBoardSwitch,
      icon: AppIcons.boardMenu,
      onSelected: (slug) => slug.isEmpty ? onManage() : onSelected(slug),
      itemBuilder: (menu) => kanbanBoardMenuItems(menu.l10n, boards, selected),
    );
  }
}

/// The boards with [selected] checked, then Manage boards…, whose value is
/// the empty slug.
List<PopupMenuEntry<String>> kanbanBoardMenuItems(
  AppLocalizations l10n,
  List<KanbanBoardInfo> boards,
  String? selected,
) => [
  for (final b in boards)
    CheckedPopupMenuItem(
      value: b.slug,
      checked: b.slug == selected,
      child: Text('${b.name} (${b.total})'),
    ),
  const PopupMenuDivider(),
  PopupMenuItem(value: '', child: Text(l10n.kanbanBoardManage)),
];

/// Whether the board's event stream is connected.
class KanbanLiveDot extends StatelessWidget {
  const KanbanLiveDot({super.key, required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: live
        ? context.l10n.kanbanBoardLive
        : context.l10n.kanbanBoardReconnecting,
    child: AppIcon(
      AppIcons.radioOn,
      size: 10,
      color: live
          ? context.hermesColors.success
          : context.hermesColors.subtleText,
    ),
  );
}
