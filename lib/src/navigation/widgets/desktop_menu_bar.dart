import 'package:flutter/material.dart';

import '../desktop_menu_models.dart';

/// The optional menu bar of Windows and Linux: File, View, Chat and Help in a
/// Material [MenuBar], 40 px high. Each item shows its chord after the label;
/// the keys are bound elsewhere, so an item never binds one itself.
///
/// A plain model: [menus] and the callbacks inside them, nothing to read from
/// the app.
class DesktopMenuBar extends StatefulWidget {
  const DesktopMenuBar({super.key, required this.menus, this.initiallyOpen});

  /// The height of the bar, the Material default.
  static const double height = 40;

  final List<DesktopMenuModel> menus;

  /// The index of a menu to open on the first frame, for the catalog and for
  /// tests that look at an open menu.
  final int? initiallyOpen;

  @override
  State<DesktopMenuBar> createState() => _DesktopMenuBarState();
}

class _DesktopMenuBarState extends State<DesktopMenuBar> {
  final _controllers = <MenuController>[];

  @override
  void initState() {
    super.initState();
    final open = widget.initiallyOpen;
    if (open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && open < _controllers.length) _controllers[open].open();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    while (_controllers.length < widget.menus.length) {
      _controllers.add(MenuController());
    }
    return SizedBox(
      height: DesktopMenuBar.height,
      width: double.infinity,
      child: MenuBar(
        children: [
          for (final (index, menu) in widget.menus.indexed)
            SubmenuButton(
              controller: _controllers[index],
              menuChildren: [
                for (var i = 0; i < menu.groups.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  for (final item in menu.groups[i]) _MenuItem(item: item),
                ],
              ],
              child: Text(menu.label),
            ),
        ],
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
    return MenuItemButton(
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
    );
  }
}
