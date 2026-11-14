import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/dialog_presentation.dart';
import '../../widgets/named_popup_menu_button.dart';
import '../server_path.dart';

/// What the page's … menu offers besides the full path, which is only shown.
enum FilesMenuChoice { copyPath, toggleHidden, refresh, about }

/// The items of the page menu, in the order the design fixes: the full path
/// (an info row, not a button), Copy path, a divider, Show hidden files
/// (checked when on), Refresh and About this list. With [onChoice] each
/// item acts through its own `onTap`, for a bar that has no `onSelected`.
List<PopupMenuEntry<FilesMenuChoice>> filesPageMenuItems(
  BuildContext context, {
  required ServerPath path,
  required bool showHidden,
  ValueChanged<FilesMenuChoice>? onChoice,
}) {
  final l10n = context.l10n;
  VoidCallback? tap(FilesMenuChoice choice) =>
      onChoice == null ? null : () => onChoice(choice);
  final scheme = Theme.of(context).colorScheme;
  return [
    PopupMenuItem<FilesMenuChoice>(
      enabled: false,
      child: Semantics(
        label: l10n.filesMenuFullPath(path.value),
        excludeSemantics: true,
        child: Text(
          path.value,
          style: TextStyle(fontFamily: 'monospace', color: scheme.onSurface),
        ),
      ),
    ),
    PopupMenuItem<FilesMenuChoice>(
      value: FilesMenuChoice.copyPath,
      onTap: tap(FilesMenuChoice.copyPath),
      child: Text(l10n.filesActionCopyPath),
    ),
    const PopupMenuDivider(),
    CheckedPopupMenuItem<FilesMenuChoice>(
      value: FilesMenuChoice.toggleHidden,
      checked: showHidden,
      onTap: tap(FilesMenuChoice.toggleHidden),
      child: Text(l10n.filesActionShowHidden),
    ),
    PopupMenuItem<FilesMenuChoice>(
      value: FilesMenuChoice.refresh,
      onTap: tap(FilesMenuChoice.refresh),
      child: Text(l10n.filesActionRefresh),
    ),
    PopupMenuItem<FilesMenuChoice>(
      value: FilesMenuChoice.about,
      onTap: tap(FilesMenuChoice.about),
      child: Text(l10n.filesAboutList),
    ),
  ];
}

/// The page's … button, with [filesPageMenuItems].
class FilesPageMenuButton extends StatelessWidget {
  const FilesPageMenuButton({
    super.key,
    required this.path,
    required this.showHidden,
    required this.onSelected,
  });

  final ServerPath path;
  final bool showHidden;
  final ValueChanged<FilesMenuChoice> onSelected;

  @override
  Widget build(BuildContext context) => NamedPopupMenuButton<FilesMenuChoice>(
    label: context.l10n.filesMenuMore,
    icon: AppIcons.more,
    itemBuilder: (context) =>
        filesPageMenuItems(context, path: path, showHidden: showHidden),
    onSelected: onSelected,
  );
}

/// "About this list": an alert that says what Hermes leaves out, with OK.
Future<void> showFilesAboutList(BuildContext context) => showAppDialog<void>(
  context: context,
  builder: (dialog) => AppAlertDialog(
    title: Text(dialog.l10n.filesAboutList),
    content: Text(dialog.l10n.filesAboutListMessage),
    actions: [
      AppDialogAction(
        isDefault: true,
        onPressed: () => Navigator.pop(dialog),
        child: Text(MaterialLocalizations.of(dialog).okButtonLabel),
      ),
    ],
  ),
);
