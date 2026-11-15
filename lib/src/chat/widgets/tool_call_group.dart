import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/disclosure_toggled.dart';
import '../chat_models.dart';
import '../tool_call_presentation.dart';
import 'tool_call_card.dart';
import 'tool_call_expansion.dart';

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
///
/// Which cards the reader opened is kept here, by call, so a card opened while
/// it was the only call stays open when the next call turns the run into a
/// group (which then opens, so the card does not fold away under the reader),
/// and when the group is folded and opened again. A group the reader folded
/// stays folded when more calls arrive.
///
/// That is kept in [expansion] under [expansionScope] when both are given, so
/// it outlives this widget: a row scrolled out of the list and back, or the
/// list mounted anew, shows the cards and the group as the reader left them.
/// Without them it is kept here, for as long as the widget lives.
class ToolCallGroup extends StatefulWidget {
  const ToolCallGroup({
    super.key,
    required this.calls,
    this.approvals = const {},
    this.onAnswerApproval,
    this.preview,
    this.expansion,
    this.expansionScope = '',
  });

  final List<ToolCall> calls;

  /// Drawn right under the run, outside any card: below the card of a run of
  /// one call, below the header of a longer run, so it stays in view while that
  /// is folded. The still picture of the screen a `computer_use` call drives.
  final Widget? preview;

  /// The approvals that hold up a call, by its position in [calls].
  final Map<int, ApprovalRequest> approvals;

  /// Sends the answer to one of [approvals].
  final Future<void> Function(String requestId, String choice)?
  onAnswerApproval;

  /// Where what the reader opened is kept beyond this widget; this widget's
  /// own state when null.
  final ToolCallExpansionStore? expansion;

  /// Tells this run from the others in [expansion]: the id of its message.
  final String expansionScope;

  @override
  State<ToolCallGroup> createState() => _ToolCallGroupState();
}

class _ToolCallGroupState extends State<ToolCallGroup> {
  final _local = ToolCallExpansionStore();

  ToolCallExpansionStore get _store => widget.expansion ?? _local;

  String get _scope => widget.expansionScope;

  bool get _open => _store.groupOpen(_scope);

  /// The key of a card: the call's id, or its place in the run for a call the
  /// server sent no id for.
  static String _key(List<ToolCall> calls, int i) =>
      calls[i].id.isNotEmpty ? 'id:${calls[i].id}' : 'at:$i';

  String _keyOf(int i) => _key(widget.calls, i);

  @override
  void didUpdateWidget(ToolCallGroup old) {
    super.didUpdateWidget(old);
    // A call that was still being written has no id until it starts.
    for (var i = 0; i < old.calls.length && i < widget.calls.length; i++) {
      if (old.calls[i].id.isEmpty && widget.calls[i].id.isNotEmpty) {
        _store.moveCard(_scope, _key(old.calls, i), _keyOf(i));
      }
    }
    if (old.calls.length == 1 &&
        widget.calls.length > 1 &&
        _store.cardOpen(_scope, _keyOf(0))) {
      _store.setGroupOpen(_scope, true);
    }
    _store.retainCards(_scope, {
      for (var i = 0; i < widget.calls.length; i++) _keyOf(i),
    });
  }

  @override
  Widget build(BuildContext context) {
    final calls = widget.calls;
    Widget card(int i) {
      final approval = widget.approvals[i];
      final answer = widget.onAnswerApproval;
      return ToolCallCard(
        call: calls[i],
        initiallyOpen: _store.cardOpen(_scope, _keyOf(i)),
        onOpenChanged: (open) => _store.setCardOpen(_scope, _keyOf(i), open),
        approval: approval,
        onAnswerApproval: approval == null || answer == null
            ? null
            : (choice) => answer(approval.requestId, choice),
      );
    }

    // Both shapes keep the preview in the child list's second place, which
    // with its key is all it takes for it to move without losing its state.
    if (calls.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(0),
          if (widget.preview case final preview?)
            Padding(padding: const EdgeInsets.only(top: 6), child: preview),
        ],
      );
    }

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
        ? 'Waiting on ${waiting.first.displayName}'
        : started.isNotEmpty
        ? 'Running ${started.first.displayName}…'
        : running.isNotEmpty
        ? 'Preparing ${running.first.displayName}…'
        : 'Used ${calls.length} tools';
    final open = _open || waiting.isNotEmpty;

    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final minTap = platformChromeOf(context) == PlatformChrome.ios
        ? kAppleMinTapTarget
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              DisclosureToggledNotification.send(context);
              setState(() => _store.setGroupOpen(_scope, !_open));
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minTap),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ToolCallStatusIcon(
                        status: status,
                        waiting: waiting.isNotEmpty,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      if (calls.any((call) => call.outputRisk != null))
                        Tooltip(
                          message: 'Tool output warning',
                          child: AppIcon(
                            AppIcons.warning,
                            size: 16,
                            color: scheme.error,
                          ),
                        ),
                      AppIcon(
                        open ? AppIcons.expandLess : AppIcons.chevronRight,
                        size: 16,
                        color: subtle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.preview case final preview?)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 2),
            child: SizedBox(width: double.infinity, child: preview),
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
