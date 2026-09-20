import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// What the model reasoned before it answered, folded away until the user
/// opens it — assistant-ui's collapsible reasoning part.
class ReasoningBlock extends StatefulWidget {
  const ReasoningBlock({super.key, required this.text, this.active = false});

  final String text;

  /// The reply is still being written, so more reasoning may follow.
  final bool active;

  @override
  State<ReasoningBlock> createState() => _ReasoningBlockState();
}

class _ReasoningBlockState extends State<ReasoningBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined, size: 16, color: subtle),
                const SizedBox(width: 6),
                Text(
                  widget.active ? 'Thinking…' : 'Reasoning',
                  style: TextStyle(fontSize: 13, color: subtle),
                ),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: subtle,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 4, left: 7),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: scheme.outline)),
            ),
            child: Text(
              widget.text,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: subtle),
            ),
          ),
      ],
    );
  }
}
