import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:provider/provider.dart';

import 'edit_menu_state.dart';

/// A [SelectionArea] that tells the Mac Edit menu while it holds selected
/// text, so Copy stays on for it. Outside a Mac menu bar it is a plain
/// [SelectionArea].
class MenuSelectionArea extends StatefulWidget {
  const MenuSelectionArea({
    super.key,
    required this.child,
    this.selectionKey,
    this.onSelectionChanged,
  });

  final Widget child;

  /// Key of the inner [SelectionArea], for a caller that clears or reads its
  /// selection.
  final GlobalKey<SelectionAreaState>? selectionKey;

  /// Called with each change of the selection, besides the menu being told.
  final ValueChanged<SelectedContent?>? onSelectionChanged;

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
    key: widget.selectionKey,
    onSelectionChanged: (content) {
      _menu?.reportSelection(
        this,
        selected: content != null && content.plainText.isNotEmpty,
      );
      widget.onSelectionChanged?.call(content);
    },
    child: widget.child,
  );
}
