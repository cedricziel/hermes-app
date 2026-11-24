import 'package:flutter/material.dart';

import '../../theme/focus_ring.dart';
import '../desktop_menu_models.dart';

/// Moves the keyboard into a [DesktopMenuBar] from outside it.
class DesktopMenuBarController {
  _DesktopMenuBarState? _state;

  /// Opens the first menu and puts the focus on its button, which is how the
  /// keyboard enters the bar: Flutter's [MenuBar] has no Tab stop.
  void focusFirstMenu() => _state?._focusFirst();

  /// Whether the focus is in the bar, on a menu button or in an open menu.
  bool get hasFocus => _state?._nodes.any((node) => node.hasFocus) ?? false;
}

/// The optional menu bar of Windows and Linux: File, View, Chat and Help in a
/// Material [MenuBar], 40 px high. Each item shows its chord after the label;
/// the keys are bound elsewhere, so an item never binds one itself.
///
/// A plain model: [menus] and the callbacks inside them, nothing to read from
/// the app.
class DesktopMenuBar extends StatefulWidget {
  const DesktopMenuBar({
    super.key,
    required this.menus,
    this.initiallyOpen,
    this.controller,
  });

  /// The height of the bar, the Material default.
  static const double height = 40;

  final List<DesktopMenuModel> menus;

  /// The index of a menu to open on the first frame, for the catalog and for
  /// tests that look at an open menu.
  final int? initiallyOpen;

  /// Lets the app move the keyboard into the bar.
  final DesktopMenuBarController? controller;

  @override
  State<DesktopMenuBar> createState() => _DesktopMenuBarState();
}

class _DesktopMenuBarState extends State<DesktopMenuBar> {
  final _controllers = <MenuController>[];
  final _nodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    final open = widget.initiallyOpen;
    if (open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && open < _controllers.length) _controllers[open].open();
      });
    }
  }

  @override
  void didUpdateWidget(DesktopMenuBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  void _focusFirst() {
    if (_controllers.isEmpty) return;
    _controllers.first.open();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    while (_controllers.length < widget.menus.length) {
      _controllers.add(MenuController());
      _nodes.add(FocusNode(debugLabel: 'DesktopMenuBar menu'));
    }
    final theme = Theme.of(context);
    final popup = theme.popupMenuTheme;
    final surface = popup.color ?? theme.colorScheme.surface;
    final edge = popup.shape is OutlinedBorder
        ? (popup.shape! as OutlinedBorder).side
        : BorderSide(color: theme.colorScheme.outline);
    // The panels of the menus take what a popup menu has on Windows and
    // Linux: its surface, its elevation and its edge, so they stand out from
    // the page in the dark theme too.
    final panel = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(popup.shape as OutlinedBorder?),
    );
    return SizedBox(
      height: DesktopMenuBar.height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: edge)),
        child: MenuBar(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(surface),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          children: [
            for (final (index, menu) in widget.menus.indexed)
              FocusRing(
                radius: 4,
                fill: theme.hoverColor,
                onlyFor: _nodes[index],
                child: SubmenuButton(
                  controller: _controllers[index],
                  focusNode: _nodes[index],
                  menuStyle: panel,
                  menuChildren: [
                    for (var i = 0; i < menu.groups.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      for (final item in menu.groups[i]) _MenuItem(item: item),
                    ],
                  ],
                  child: Text(menu.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.item});

  final DesktopMenuItemModel item;

  @override
  Widget build(BuildContext context) {
    final chord = item.chord;
    return FocusRing(
      radius: 4,
      fill: Theme.of(context).hoverColor,
      child: MenuItemButton(
        onPressed: item.onSelected,
        trailingIcon: chord == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  chord.text,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
        child: Text(item.label),
      ),
    );
  }
}
