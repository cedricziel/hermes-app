import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import 'tool_call_card.dart';

/// A run of tool calls the agent made back to back, with no reasoning
/// between them — assistant-ui folds a burst of tool use into one row
/// ("Used 3 tools") instead of a card per call.
///
/// A single call in the run, whether finished or still running, shows as its
/// own [ToolCallCard] with no group chrome. Two or more collapse behind a
/// header naming the call still running, or how many ran once none are; it
/// starts folded and opens on tap, showing each call's own [ToolCallCard].
/// While a call waits on the user's approval the group stays open, so the
/// question is never folded away.
class ToolCallGroup extends StatefulWidget {
  const ToolCallGroup({
    super.key,
    required this.calls,
    this.approvals = const {},
    this.onAnswerApproval,
  });

  final List<ToolCall> calls;

  /// The approvals that hold up a call, by its position in [calls].
  final Map<int, ApprovalRequest> approvals;

  /// Sends the answer to one of [approvals].
  final Future<void> Function(String requestId, String choice)?
  onAnswerApproval;

  @override
  State<ToolCallGroup> createState() => _ToolCallGroupState();
}

class _ToolCallGroupState extends State<ToolCallGroup> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final calls = widget.calls;
    Widget card(int i) {
      final approval = widget.approvals[i];
      final answer = widget.onAnswerApproval;
      return ToolCallCard(
        call: calls[i],
        approval: approval,
        onAnswerApproval: approval == null || answer == null
            ? null
            : (choice) => answer(approval.requestId, choice),
      );
    }

    if (calls.length == 1) return card(0);

    final waiting = widget.approvals.entries
        .where((e) => e.value.status == InputRequestStatus.pending)
        .map((e) => calls[e.key]);
    final running = calls.where((c) => c.status == ToolCallStatus.running);
    final status = running.isNotEmpty
        ? ToolCallStatus.running
        : calls.any((c) => c.status == ToolCallStatus.error)
        ? ToolCallStatus.error
        : calls.every((c) => c.status == ToolCallStatus.cancelled)
        ? ToolCallStatus.cancelled
        : ToolCallStatus.completed;
    // Calls run in order, so the one running is the first that started; the
    // rest are still being written.
    final started = running.where((c) => !c.preparing);
    final label = waiting.isNotEmpty
        ? 'Waiting on ${waiting.first.name}'
        : started.isNotEmpty
        ? 'Running ${started.first.name}…'
        : running.isNotEmpty
        ? 'Preparing ${running.first.name}…'
        : 'Used ${calls.length} tools';
    final open = _open || waiting.isNotEmpty;

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
                  ToolCallStatusIcon(
                    status: status,
                    waiting: waiting.isNotEmpty,
                  ),
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
                    open ? Icons.expand_less : Icons.chevron_right,
                    size: 16,
                    color: subtle,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, _) in calls.indexed) ...[
                  card(i),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
