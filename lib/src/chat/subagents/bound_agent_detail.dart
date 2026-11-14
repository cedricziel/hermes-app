import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../chat_controller.dart';
import 'agent_detail_mapper.dart';
import 'agent_models.dart';
import 'subagent_detail_controller.dart';
import 'subagent_roster.dart';
import 'widgets/agent_detail_view.dart';
import 'widgets/confirm_stop_agent.dart';

/// One agent's detail in the Activity panel, bound to its roster and its own
/// [SubagentDetailController]. It lives while the detail is open: closing it
/// drops the output, the typed note and the notes sent.
///
/// With [readOnly] (a conversation window, which holds no session) it only
/// describes the agent from the roster: nothing is read from the session and
/// nothing can be stopped or sent.
class BoundAgentDetail extends StatefulWidget {
  const BoundAgentDetail({
    super.key,
    required this.chat,
    required this.roster,
    required this.agent,
    required this.onBack,
    this.onClose,
    this.stopRequested = false,
    this.source = 'panel',
    this.readOnly = false,
    this.outputMaxHeight,
    this.onStopAsked,
  });

  final ChatController chat;
  final SubagentRoster roster;
  final AgentKey agent;
  final VoidCallback onBack;
  final VoidCallback? onClose;

  /// Open with the stop confirmation, as "Stop agent" on a row asks.
  final bool stopRequested;

  /// Called when the request to open with the confirmation was used.
  final VoidCallback? onStopAsked;
  final String source;
  final bool readOnly;
  final double? outputMaxHeight;

  @override
  State<BoundAgentDetail> createState() => _BoundAgentDetailState();
}

class _BoundAgentDetailState extends State<BoundAgentDetail> {
  SubagentDetailController? _controller;
  RosterWatch? _watch;
  Timer? _clock;
  final _noteField = TextEditingController();
  final _focus = FocusNode(debugLabel: 'agent-detail');
  final _ended = ValueNotifier(false);
  var _asking = false;

  @override
  void initState() {
    super.initState();
    // Escape goes back from the detail, also where an overlay holds focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    final roster = widget.roster;
    if (!widget.readOnly) {
      _watch = roster.watch();
      _controller = SubagentDetailController(
        key: widget.agent,
        repository: roster.repository,
        host: roster.hostFor(widget.agent.subagentId),
        events: widget.chat.events,
        breadcrumbs: widget.chat.breadcrumbs,
      )..addListener(_changed);
    }
    roster.addListener(_changed);
    widget.chat.breadcrumbs('subagent.detail.opened', {
      'source': widget.source == 'transcript' ? 'transcript' : 'panel',
    });
    // The run time of a running agent moves between frames and reads.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (roster.row(widget.agent.subagentId)?.active ?? false)) {
        setState(() {});
      }
    });
    if (widget.stopRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onStopAsked?.call();
        _controller?.startStop();
      });
    }
  }

  void _changed() {
    if (!mounted) return;
    final controller = _controller;
    _ended.value = controller?.stopPhase == StopPhase.ended;
    if (controller != null && controller.note != _noteField.text) {
      // A queued note clears the field; a frozen one cannot be edited.
      _noteField.text = controller.note;
    }
    setState(() {});
    if (controller != null &&
        controller.stopPhase == StopPhase.confirming &&
        !_asking) {
      unawaited(_ask(controller));
    }
  }

  Future<void> _ask(SubagentDetailController controller) async {
    _asking = true;
    final goal = widget.roster.row(widget.agent.subagentId)?.goal ?? '';
    final confirmed = await confirmStopAgent(
      context,
      goal: goal,
      dismissWhen: _ended,
    );
    _asking = false;
    if (!mounted) return;
    if (confirmed) {
      unawaited(controller.confirmStop());
    } else {
      controller.cancelStop();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    widget.roster.removeListener(_changed);
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _watch?.close();
    _noteField.dispose();
    _focus.dispose();
    _ended.dispose();
    widget.chat.breadcrumbs('subagent.detail.closed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.roster.row(widget.agent.subagentId);
    if (row == null) {
      // The agent left the roster (a sign-out, a new profile): nothing to show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onBack();
      });
      return const SizedBox.shrink();
    }
    final controller = _controller;
    final model = agentDetailModel(
      row: row,
      controller: controller,
      readOnly: widget.readOnly,
    );
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onBack();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: AgentDetailView(
            model: model,
            onBack: widget.onBack,
            onClose: widget.onClose,
            onStop: controller != null && controller.canStop
                ? controller.startStop
                : null,
            onSendNote: controller != null && controller.canSendNote
                ? () => unawaited(controller.sendNote())
                : null,
            onNoteChanged: (text) => controller?.setNote(text),
            onCopyNote: () => unawaited(
              Clipboard.setData(ClipboardData(text: controller?.note ?? '')),
            ),
            onJumpToLatest: () => controller?.jumpToLatest(),
            onHolding: (holding) => controller?.setReaderHolding(holding),
            noteController: _noteField,
            outputMaxHeight: widget.outputMaxHeight,
          ),
        ),
      ),
    );
  }
}
