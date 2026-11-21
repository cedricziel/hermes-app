import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

/// Shows [child] as it looks when the keyboard has moved focus to its
/// [focusIndex]-th focusable control: the highlight mode is forced to
/// traditional, as it is after a Tab press, and put back when the use case
/// goes away. A null [focusIndex] leaves every control at rest.
class _KeyboardFocus extends StatefulWidget {
  const _KeyboardFocus({required this.focusIndex, required this.child});

  final int? focusIndex;
  final Widget child;

  @override
  State<_KeyboardFocus> createState() => _KeyboardFocusState();
}

class _KeyboardFocusState extends State<_KeyboardFocus> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = widget.focusIndex;
      if (!mounted || index == null) return;
      final nodes = FocusScope.of(context).traversalDescendants.toList();
      if (index < nodes.length) nodes[index].requestFocus();
    });
  }

  @override
  void dispose() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void _noop() {}

Widget _buttons() => Wrap(
  spacing: 16,
  runSpacing: 16,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    FilledButton(onPressed: _noop, child: const Text('Filled')),
    OutlinedButton(onPressed: _noop, child: const Text('Outlined')),
    TextButton(onPressed: _noop, child: const Text('Text')),
    IconButton(onPressed: _noop, tooltip: 'Add', icon: const Icon(Icons.add)),
  ],
);

Widget _rows() => const GroupedSection(
  header: 'Messaging',
  children: [
    GroupedRow(title: 'Telegram', value: 'Set up', onTap: _noop),
    GroupedRow(title: 'Discord', value: 'Off', onTap: _noop),
    GroupedRow(title: 'Slack', value: 'Off', onTap: _noop),
  ],
);

/// A real menu, opened under the host and with its second item focused, since
/// a menu item only builds inside a menu route.
class _OpenMenu extends StatefulWidget {
  const _OpenMenu();

  @override
  State<_OpenMenu> createState() => _OpenMenuState();
}

class _OpenMenuState extends State<_OpenMenu> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final menu = showMenu<int>(
        context: context,
        position: const RelativeRect.fromLTRB(16, 16, 0, 0),
        items: const [
          FocusRingMenuItem<int>(value: 1, child: Text('Rename')),
          FocusRingMenuItem<int>(value: 2, child: Text('Duplicate')),
          FocusRingMenuItem<int>(value: 3, child: Text('Archive')),
        ],
      );
      await WidgetsBinding.instance.endOfFrame;
      final items = FocusManager.instance.rootScope.traversalDescendants
          .where(
            (n) =>
                n.context
                    ?.findAncestorWidgetOfExactType<FocusRingMenuItem<int>>() !=
                null,
          )
          .toList();
      if (items.length > 1) items[1].requestFocus();
      await menu;
    });
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 200, child: Text('The menu opens at the corner.'));
}

Widget _segments() => PillSegmentedControl<int>(
  value: 0,
  segments: const {0: 'Chats', 1: 'Files', 2: 'Tasks'},
  onChanged: (_) {},
);

Widget _at(int? index, Widget child) =>
    frame(_KeyboardFocus(focusIndex: index, child: child));

/// The keyboard focus ring: 2 px in the link colour, 2 px outside a button
/// (its radius plus 2), 2 px inside a list row, menu item or segment that a
/// container clips. It shows only after the keyboard moved focus, never after
/// a pointer press; a text field keeps its own focus border. Each use case
/// forces keyboard mode and focuses one control; "Resting" is the same
/// controls with nothing focused, and "Try it" is for pressing Tab.
WidgetbookNode focusRingNode() => WidgetbookComponent(
  name: 'Keyboard focus ring',
  useCases: [
    WidgetbookUseCase(name: 'Resting', builder: (_) => _at(null, _buttons())),
    WidgetbookUseCase(
      name: 'Filled button',
      builder: (_) => _at(0, _buttons()),
    ),
    WidgetbookUseCase(
      name: 'Outlined button',
      builder: (_) => _at(1, _buttons()),
    ),
    WidgetbookUseCase(name: 'Text button', builder: (_) => _at(2, _buttons())),
    WidgetbookUseCase(name: 'Icon button', builder: (_) => _at(3, _buttons())),
    WidgetbookUseCase(name: 'Grouped row', builder: (_) => _at(1, _rows())),
    WidgetbookUseCase(
      name: 'Menu item',
      builder: (_) => _at(null, const _OpenMenu()),
    ),
    WidgetbookUseCase(name: 'Segment', builder: (_) => _at(1, _segments())),
    WidgetbookUseCase(
      name: 'Text field (own border)',
      builder: (_) => _at(
        0,
        const TextField(decoration: InputDecoration(labelText: 'Name')),
      ),
    ),
    WidgetbookUseCase(
      name: 'Try it (press Tab)',
      builder: (_) => _at(
        null,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buttons(), const SizedBox(height: 16), _rows()],
        ),
      ),
    ),
  ],
);
