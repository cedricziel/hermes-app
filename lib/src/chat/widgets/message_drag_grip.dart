import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../drag_out/drag_out_item.dart';
import '../../drag_out/drag_out_source.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';

/// The width reserved beside a message for its grip.
const double kMessageGripGutter = 26;

/// A message with a gutter beside it holding a grip, shown under the pointer,
/// that drags the message's Markdown [text] out of the app as plain text and
/// as Markdown.
///
/// The text itself belongs to the `SelectionArea` inside [child], so it cannot
/// be the handle, and the grip sits beside the message, not over it: nothing
/// in it (a code block's copy button, the end of a line) is ever covered.
/// With drag-out missing (any platform but macOS, a conversation window) or
/// no [text], this is [child]. While [enabled] is false (a reply still
/// streaming) the gutter stays, so the message does not jump when it ends, but
/// there is no grip.
class MessageDragGrip extends StatefulWidget {
  const MessageDragGrip({
    super.key,
    required this.text,
    required this.child,
    this.enabled = true,
  });

  final String text;
  final Widget child;
  final bool enabled;

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
    final shown = widget.enabled && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: widget.child),
          SizedBox(
            width: kMessageGripGutter,
            child: shown ? _Grip(text: widget.text) : null,
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
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topEnd,
    child: DragOut(
      kind: DragOutKind.text,
      item: () => DragOutText(text),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: 'Drag message text',
          child: Padding(
            padding: const EdgeInsets.all(3),
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
