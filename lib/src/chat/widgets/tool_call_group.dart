import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import 'tool_call_card.dart';

/// A run of tool calls the agent made back to back, with no reasoning
/// between them — assistant-ui folds a burst of tool use into one row
/// ("Ran 3 commands") instead of a card per call.
///
/// A single call in the run, whether finished or still running, shows as its
/// own [ToolCallCard] with no group chrome. Two or more collapse behind a
/// header naming the call still running, or how many ran once none are; it
/// starts folded and opens on tap, showing each call's own [ToolCallCard].
class ToolCallGroup extends StatefulWidget {
  const ToolCallGroup({super.key, required this.calls});

  final List<ToolCall> calls;

  @override
  State<ToolCallGroup> createState() => _ToolCallGroupState();
}

class _ToolCallGroupState extends State<ToolCallGroup> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final calls = widget.calls;
    if (calls.length == 1) return ToolCallCard(call: calls.single);

    final running = calls.where((c) => c.status == ToolCallStatus.running);
    final status = running.isNotEmpty
        ? ToolCallStatus.running
        : calls.any((c) => c.status == ToolCallStatus.error)
        ? ToolCallStatus.error
        : ToolCallStatus.completed;
    final label = running.isNotEmpty
        ? 'Running ${running.last.name}…'
        : 'Ran ${calls.length} commands';

    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToolCallStatusIcon(status: status),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _open ? Icons.expand_less : Icons.chevron_right,
                    size: 16,
                    color: subtle,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final call in calls) ...[
                  ToolCallCard(call: call),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
