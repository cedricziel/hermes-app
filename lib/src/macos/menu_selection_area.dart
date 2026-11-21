import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'edit_menu_state.dart';

/// A [SelectionArea] that tells the Mac Edit menu while it holds selected
/// text, so Copy stays on for it. Outside a Mac menu bar it is a plain
/// [SelectionArea].
class MenuSelectionArea extends StatefulWidget {
  const MenuSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<MenuSelectionArea> createState() => _MenuSelectionAreaState();
}

class _MenuSelectionAreaState extends State<MenuSelectionArea> {
  EditMenuState? _menu;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _menu = context.read<EditMenuState>();
    } on ProviderNotFoundException {
      _menu = null;
    }
  }

  @override
  void dispose() {
    _menu?.reportSelection(this, selected: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    onSelectionChanged: (content) => _menu?.reportSelection(
      this,
      selected: content != null && content.plainText.isNotEmpty,
    ),
    child: widget.child,
  );
}
