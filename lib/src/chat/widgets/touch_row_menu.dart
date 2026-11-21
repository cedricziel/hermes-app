import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

import '../../../l10n/l10n.dart';
import 'thread_actions_menu.dart';

/// Opens a chat row's actions in a popover menu on a touch layout that has
/// room for one (an iPad): a long press opens it at the row's trailing edge,
/// level with the row, and a secondary click (a trackpad or mouse) at the
/// pointer. [CupertinoMenuAnchor] sizes it (262 pt from 768 pt of screen, 250
/// below) and flips it at the screen edges.
///
/// A plain-model widget: it knows the row's [title] and whether it is
/// [pinned], and reports the chosen [ThreadAction] through [onAction]. Delete
/// is only reported; the caller asks for confirmation. The phone's action
/// sheet stays in `SwipeableThreadRow`.
class TouchRowMenu extends StatefulWidget {
  const TouchRowMenu({
    super.key,
    required this.title,
    required this.pinned,
    required this.onAction,
    required this.child,
    this.canonical = false,
    this.initiallyOpen = false,
  });

  final String title;
  final bool pinned;
  final ValueChanged<ThreadAction> onAction;
  final Widget child;

  /// A canonical Bot Chat: no Rename, and Archive reads "Retire Bot Chat…",
  /// as in `ThreadActionsButton`.
  final bool canonical;

  /// Opens the menu once the row is on screen, for the catalog.
  final bool initiallyOpen;

  @override
  State<TouchRowMenu> createState() => _TouchRowMenuState();
}

class _TouchRowMenuState extends State<TouchRowMenu> {
  final _menu = MenuController();

  @override
  void initState() {
    super.initState();
    if (widget.initiallyOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAtRowEnd();
      });
    }
  }

  /// The anchor scopes the open menu as a route but cannot give it a name, and
  /// a label-only node in the menu would be dropped for having no size. So the
  /// menu's name is spoken when it opens.
  void _announce() {
    final context = this.context;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.chatWidgetsThreadMenuLabel(widget.title),
        Directionality.of(context),
      ).catchError((Object _) {}),
    );
  }

  void _openAt(Offset local) {
    if (_menu.isOpen) _menu.close();
    _menu.open(position: local);
  }

  void _openAtRowEnd() {
    final size = context.size;
    if (size == null) return;
    _openAt(Offset(size.width, 0));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    CupertinoMenuItem item(ThreadAction action, String label) =>
        CupertinoMenuItem(
          onPressed: () => widget.onAction(action),
          child: Text(label),
        );
    return CupertinoMenuAnchor(
      controller: _menu,
      onOpen: _announce,
      menuChildren: [
        if (!widget.canonical)
          item(ThreadAction.rename, l10n.chatWidgetsThreadMenuRename),
        item(
          ThreadAction.pin,
          widget.pinned
              ? l10n.chatWidgetsThreadMenuUnpin
              : l10n.chatWidgetsThreadMenuPin,
        ),
        item(
          ThreadAction.archive,
          widget.canonical
              ? l10n.chatWidgetsThreadMenuRetire
              : l10n.chatWidgetsThreadMenuArchive,
        ),
        const CupertinoMenuDivider(),
        CupertinoMenuItem(
          isDestructiveAction: true,
          onPressed: () => widget.onAction(ThreadAction.delete),
          child: Text(l10n.chatWidgetsThreadMenuDelete),
        ),
      ],
      child: Semantics(
        onLongPressHint: l10n.chatWidgetsThreadMenuLabel(widget.title),
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onLongPress: _openAtRowEnd,
          onSecondaryTapUp: (details) => _openAt(details.localPosition),
          child: widget.child,
        ),
      ),
    );
  }
}
