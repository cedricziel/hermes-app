import 'package:flutter/material.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/widgets/menu_bar_item_section.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

/// The macOS menu bar item. Its menu is drawn by the system and cannot be
/// shown here; the icons are template images, drawn dark on a light menu bar
/// and light on a dark one. The runner uses the SF Symbols named below.
WidgetbookNode menuBarExtraNode() => WidgetbookFolder(
  name: 'Menu bar item',
  children: [
    WidgetbookComponent(
      name: 'Icon',
      useCases: [
        WidgetbookUseCase(
          name: 'Idle, working and needs attention',
          builder: (_) => frame(const _IconStrips()),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Settings row',
      useCases: [
        for (final on in [true, false])
          WidgetbookUseCase(
            name: on ? 'On' : 'Off',
            builder: (_) => fill(
              GroupedDialog(
                title: 'Settings',
                children: [MenuBarItemSection(value: on, onChanged: (_) {})],
              ),
            ),
          ),
      ],
    ),
  ],
);

const _states = [
  ('Idle', 'bubble.left', Icons.chat_bubble_outline),
  ('Working', 'ellipsis.bubble', Icons.mark_unread_chat_alt_outlined),
  ('Needs attention', 'exclamationmark.bubble', Icons.feedback_outlined),
];

/// The three icons on a light and on a dark menu bar.
class _IconStrips extends StatelessWidget {
  const _IconStrips();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final dark in [false, true]) ...[
        _Strip(dark: dark),
        const SizedBox(height: 16),
      ],
    ],
  );
}

class _Strip extends StatelessWidget {
  const _Strip({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : Colors.black;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2A2C) : const Color(0xFFE9E9EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            for (final (name, symbol, icon) in _states)
              Semantics(
                label: '$name, $symbol',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(height: 4),
                    Text(name, style: TextStyle(fontSize: 11, color: color)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
