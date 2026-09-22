import 'package:flutter/material.dart';

import '../kanban_models.dart';

/// The row of status chips on a narrow screen. It brings the selected chip
/// into view when it first appears (a fresh row starts at the left, which may
/// hide it, e.g. after the screen is rotated) and whenever the selection moves.
class KanbanStatusChips extends StatefulWidget {
  const KanbanStatusChips({
    super.key,
    required this.columns,
    required this.selected,
    required this.onSelected,
  });

  final List<KanbanColumn> columns;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<KanbanStatusChips> createState() => _KanbanStatusChipsState();
}

class _KanbanStatusChipsState extends State<KanbanStatusChips> {
  final _selectedChip = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(KanbanStatusChips old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _reveal();
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final chip = _selectedChip.currentContext;
    if (chip != null && mounted) Scrollable.ensureVisible(chip, alignment: 0.5);
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final c in widget.columns)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: c.name == widget.selected ? _selectedChip : null,
                label: Text('${kanbanStatusLabel(c.name)} ${c.tasks.length}'),
                selected: c.name == widget.selected,
                onSelected: (_) => widget.onSelected(c.name),
              ),
            ),
        ],
      ),
    ),
  );
}
