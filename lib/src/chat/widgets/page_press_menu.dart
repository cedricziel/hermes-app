import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_popup_menu_button.dart' show showRingMenu;
import '../../widgets/app_action_sheet.dart';
import '../page_link.dart';
import '../report_chat_bug.dart';

/// One entry of a page's press menu.
class PagePressAction {
  const PagePressAction(this.label, this.run);

  final String label;
  final FutureOr<void> Function() run;
}

/// The press menu entries of the page at [link]: Open in browser when it
/// opens and [onOpen] is set, and Copy link when it has a link to copy (never
/// one that carries credentials). Copying is announced to a screen reader.
List<PagePressAction> pagePressActions(
  BuildContext context,
  PageLink link, {
  required ValueChanged<Uri>? onOpen,
}) {
  final l10n = context.l10n;
  final uri = link.uri;
  final copyText = link.copyText;
  final copied = l10n.chatWidgetsToolValueCopied;
  final view = View.of(context);
  final direction = Directionality.of(context);
  return [
    if (uri != null && onOpen != null)
      PagePressAction(l10n.chatWidgetsLinkOpen, () => onOpen(uri)),
    if (copyText != null)
      PagePressAction(l10n.chatWidgetsLinkCopy, () async {
        try {
          await Clipboard.setData(ClipboardData(text: copyText));
        } on Object catch (error, stack) {
          reportChatBug(error, stack, 'a page link copy');
          return;
        }
        unawaited(
          SemanticsService.sendAnnouncement(
            view,
            copied,
            direction,
          ).catchError((Object _) {}),
        );
      }),
  ];
}

/// The centre of [context]'s box, where a long press puts the menu.
Offset centreOf(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(box.size.center(Offset.zero));
}

/// The press menu: an action sheet on iOS, a menu at the pointer elsewhere.
Future<void> showPagePressMenu(
  BuildContext context,
  List<PagePressAction> actions,
  Offset at,
  String title,
) async {
  final PagePressAction? chosen;
  if (platformChromeOf(context) == PlatformChrome.ios) {
    chosen = await showAppActionSheet<PagePressAction>(
      context: context,
      title: title,
      entries: [
        for (final action in actions)
          AppActionSheetEntry(label: action.label, value: action),
      ],
    );
  } else {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    chosen = await showRingMenu<PagePressAction>(
      context: context,
      position: RelativeRect.fromRect(
        at & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        for (final action in actions)
          PopupMenuItem(value: action, child: Text(action.label)),
      ],
    );
  }
  await chosen?.run();
}

/// The tile that stands for a page: the first letter of its host on a quiet
/// square. Nothing is requested from the host for an icon.
class PageTile extends StatelessWidget {
  const PageTile({super.key, required this.letter, required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: Theme.of(context).textTheme.titleSmall!
              .copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
