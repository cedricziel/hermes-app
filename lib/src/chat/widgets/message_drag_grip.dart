import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../drag_out/drag_out_item.dart';
import '../../drag_out/drag_out_source.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';

/// A message with a grip at its top end, shown under the pointer, that drags
/// the message's Markdown [text] out of the app as plain text and as Markdown.
///
/// The text itself belongs to the `SelectionArea` inside [child], so it cannot
/// be the handle. Where drag-out does not exist (any platform but macOS, the
/// catalog, conversation windows) or [text] is empty, this is [child].
class MessageDragGrip extends StatefulWidget {
  const MessageDragGrip({super.key, required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  State<MessageDragGrip> createState() => _MessageDragGripState();
}

class _MessageDragGripState extends State<MessageDragGrip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final available =
        widget.text.isNotEmpty && context.watch<DragOutSource?>() != null;
    if (!available) return widget.child;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          widget.child,
          if (_hovered)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: _Grip(text: widget.text),
            ),
        ],
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragOut(
      kind: DragOutKind.text,
      item: () => DragOutText(text),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Semantics(
          label: 'Drag message text',
          child: Tooltip(
            message: 'Drag message text',
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AppIcon(
                AppIcons.dragHandle,
                size: 16,
                color: context.hermesColors.subtleText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
