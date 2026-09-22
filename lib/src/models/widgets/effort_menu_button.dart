import 'package:flutter/material.dart';

import 'model_menu_chip.dart';

/// The composer's reasoning-effort picker, next to [ModelMenuButton]. Hidden
/// when the selected model takes no effort level, since `reasoning_effort` is
/// an unconstrained string the server may not accept for every model.
class EffortMenuButton extends StatefulWidget {
  const EffortMenuButton({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.initiallyOpen = false,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  /// Opens the dropdown as soon as it is built, for the catalog.
  final bool initiallyOpen;

  @override
  State<EffortMenuButton> createState() => _EffortMenuButtonState();
}

class _EffortMenuButtonState extends State<EffortMenuButton> {
  final _controller = MenuController();

  @override
  void initState() {
    super.initState();
    if (widget.initiallyOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.open();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    return MenuAnchor(
      controller: _controller,
      menuChildren: [
        for (final option in widget.options)
          MenuItemButton(
            key: Key('effort-option-$option'),
            trailingIcon: option == widget.selected
                ? const Icon(Icons.check, size: 18)
                : null,
            onPressed: () {
              _controller.close();
              widget.onSelected(option);
            },
            child: Text(_label(option)),
          ),
      ],
      builder: (context, controller, child) => ModelMenuChip(
        label: widget.selected == null ? 'Effort' : _label(widget.selected!),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  String _label(String effort) =>
      effort.isEmpty ? effort : effort[0].toUpperCase() + effort.substring(1);
}
