import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../bot_screen/bot_screen_card_model.dart';
import '../../bot_screen/bot_screen_controller.dart';
import '../../bot_screen/widgets/bound_bot_screen_card.dart';
import '../../memory/memory_destination.dart';
import '../chat_controller.dart';
import '../chat_models.dart';
import '../chat_session_state.dart';
import '../process_output_state.dart';
import '../memory/memory_activity_card.dart';
import '../reactions/reaction_cards.dart';
import '../session_usage/session_usage_card.dart';
import '../side_results/side_result_card.dart';
import '../side_results/side_result_state.dart';
import '../subagents/activity_selection.dart';
import '../subagents/agent_detail_mapper.dart';
import '../subagents/bound_agent_detail.dart';
import '../subagents/roster_row.dart';
import '../subagents/subagent_roster.dart';
import '../subagents/widgets/agent_row.dart';
import '../todo_plan/todo_plan_card.dart';
import '../widgets/agent_notice_card.dart';
import '../widgets/billing_verification_card.dart';
import '../widgets/connector_operation_cards.dart';
import '../widgets/moa_progress_card.dart';
import '../widgets/session_status_card.dart';
import 'activity_tier.dart';
import 'bound_process_card.dart';
import 'widgets/activity_panel.dart';

/// The [ActivityPanel] of [thread] in [chat]: Working items (the session
/// status, process output, live mixture-of-agents progress) under Now, the
/// plan, and the For reference items under This session.
///
/// With a [screen] (the chat's profile's Bot Screen) the panel also lists the
/// Bot screen card under Now, and asks the controller for frames while it is
/// open. Surfaces that have no Bot Screen (conversation windows) pass none.
class BoundActivityPanel extends StatelessWidget {
  const BoundActivityPanel({
    super.key,
    required this.chat,
    required this.thread,
    this.screen,
    this.onEnlargeScreen,
    this.onClose,
    this.scrollController,
    this.selection,
    this.readOnly = false,
  });

  final ChatController chat;

  /// Which agent's detail is open, owned by the window's chat screen. Null
  /// lists the agents without a way to open one.
  final ActivitySelection? selection;

  /// A surface that holds no session (a conversation window): agents are
  /// listed and described from what their frames said, nothing is read from
  /// the session, and nothing can be stopped or sent.
  final bool readOnly;
  final ChatThread? thread;
  final BotScreenController? screen;

  /// Opens the Bot screen's live viewer from the card; the card offers no
  /// Enlarge without it.
  final VoidCallback? onEnlargeScreen;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final t = thread;
    if (t == null) {
      return ActivityPanel(
        onClose: onClose,
        scrollController: scrollController,
      );
    }
    // The chat replaces a thread's controllers when its session changes, so
    // they are looked up again on every chat change, then listened to.
    final panel = ListenableBuilder(
      listenable: chat,
      builder: (context, _) => _sections(context, t),
    );
    final screen = this.screen;
    final shown = screen == null
        ? panel
        : BotScreenDemand(controller: screen, child: panel);
    // The roster reads the list only while the panel is shown.
    final roster = readOnly ? null : chat.subagentsIn(t);
    return roster == null ? shown : _RosterDemand(roster: roster, child: shown);
  }

  /// What the Bot screen card shows, or null when it is not listed.
  BotScreenCardModel? _screenCard(ChatThread t) {
    final controller = screen;
    if (controller == null) return null;
    final model = BotScreenCardModel.from(controller);
    if (model == null) return null;
    final used = !model.screenRunning && threadUsedScreen(t);
    return model.listed(usedByChat: used) ? model : null;
  }

  /// Whether the session state is live work: control, a resume, or a wait of
  /// the turn running now (the rule the activity line uses). A wait of an
  /// earlier turn, or a plain status, is for reference.
  bool _working(ChatThread t, ChatSessionState state) =>
      sessionStateTier(state) == ActivityTier.working &&
      (state.control?.isEmpty == false ||
          state.resume != null ||
          state.waits.keys.any(
            (kind) =>
                kind != 'status' &&
                kind != 'lifecycle' &&
                chat.workingWaitIsCurrent(t, kind),
          ));

  List<Widget> _agentRows(SubagentRoster roster, List<PlacedAgent> placed) {
    final selection = this.selection;
    return [
      for (final agent in placed)
        _AgentRowTile(
          key: ValueKey(agent.row.id),
          row: agent.row,
          level: agent.level,
          onShowDetails: selection == null
              ? null
              : () => selection.select(agentKeyOf(roster, agent.row.id)),
          onStop:
              selection == null ||
                  readOnly ||
                  !agent.row.active ||
                  agent.row.delegationOnly
              ? null
              : () => selection.select(
                  agentKeyOf(roster, agent.row.id),
                  stop: true,
                ),
        ),
    ];
  }

  Widget? _detail(ChatThread t, SubagentRoster? roster) {
    final selection = this.selection;
    final agent = selection?.key;
    if (selection == null || agent == null || roster == null) return null;
    if (agent.threadId != roster.threadId || agent.profile != roster.profile) {
      // Another chat or profile's selection is not this panel's.
      WidgetsBinding.instance.addPostFrameCallback((_) => selection.clear());
      return null;
    }
    return BoundAgentDetail(
      key: ValueKey((agent, roster)),
      chat: chat,
      roster: roster,
      agent: agent,
      source: selection.source,
      stopRequested: selection.stopRequested,
      onStopAsked: selection.consumeStop,
      readOnly: readOnly,
      onBack: selection.clear,
      onClose: onClose,
    );
  }

  Widget _sections(BuildContext context, ChatThread t) {
    final roster = chat.subagentsIn(t);
    final usage = chat.usageIn(t),
        billing = chat.billingVerificationIn(t),
        plan = chat.todoPlanIn(t),
        connectors = chat.connectorOperationsIn(t),
        connection = chat.connectionOperations,
        sideResults = chat.sideResultsIn(t),
        reactions = chat.reactionsIn(t);
    return ListenableBuilder(
      listenable: Listenable.merge([
        usage,
        billing,
        plan,
        connectors,
        connection,
        sideResults,
        reactions,
        ?screen,
        ?roster,
        ?selection,
      ]),
      builder: (context, _) {
        final state = chat.sessionStateIn(t);
        final processes = chat.processOutputsIn(t);
        final acknowledgement = reactions?.acknowledgement;
        final screenModel = _screenCard(t);
        // A process card is open until it closes; closed ones are history.
        final openProcesses = [
          for (final c in processes?.cards ?? const <ProcessOutput>[])
            if (!c.closed) c,
        ];
        final closedProcesses = [
          for (final c in processes?.cards ?? const <ProcessOutput>[])
            if (c.closed) c,
        ];
        final omitted = processes?.omittedCards ?? false;
        final omittedNote = Padding(
          padding: const EdgeInsets.all(12),
          child: Text(context.l10n.chatActivityProcessesOmitted),
        );
        // The original review remains bound to its reply in the model. Its
        // presentation is reference activity, outside the transcript.
        final reviewNotes = t.messages.reversed
            .map((message) => message.reviewNotes)
            .firstWhere(
              (items) => items.isNotEmpty,
              orElse: () => const <String>[],
            );
        return ActivityPanel(
          key: ObjectKey(t),
          onClose: onClose,
          scrollController: scrollController,
          detail: _detail(t, roster),
          now: [
            if (screenModel != null)
              BoundBotScreenCard(
                key: const Key('bot-screen-card'),
                controller: screen!,
                model: screenModel,
                onEnlarge: onEnlargeScreen,
              ),
            if (roster != null) ..._agentRows(roster, roster.sections.now),
            if (state != null && state.visible && _working(t, state))
              SessionStatusCard(
                state: state,
                onDetails: chat.sessionDetailsOpened,
              ),
            for (final progress
                in chat.moaIn(t).where((progress) => progress.live))
              MoaProgressCard(
                key: ObjectKey(progress.turn),
                progress: progress,
                onDetails: chat.moaDetailsOpened,
              ),
            for (final process in openProcesses)
              BoundProcessCard(
                key: ValueKey(process.processId),
                chat: chat,
                output: process,
                roster: readOnly ? null : roster,
                readOnly: readOnly,
              ),
            if (openProcesses.isNotEmpty && omitted) omittedNote,
          ],
          plan: plan != null && plan.hasPlan
              ? TodoPlanCard(state: plan, initiallyOpen: true)
              : null,
          session: [
            if (roster != null) ...[
              ..._agentRows(roster, roster.sections.session),
              if (roster.sections.hiddenEnded > 0)
                _EarlierAgentsLine(roster.sections.hiddenEnded),
            ],
            if (state != null &&
                state.visible &&
                sessionStateTier(state) != ActivityTier.needsYou &&
                !_working(t, state))
              SessionStatusCard(
                state: state,
                onDetails: chat.sessionDetailsOpened,
              ),
            for (final process in closedProcesses)
              BoundProcessCard(
                key: ValueKey(process.processId),
                chat: chat,
                output: process,
                roster: readOnly ? null : roster,
                readOnly: readOnly,
              ),
            if (openProcesses.isEmpty && omitted) omittedNote,
            for (final progress
                in chat.moaIn(t).where((progress) => !progress.live))
              MoaProgressCard(
                key: ObjectKey(progress.turn),
                progress: progress,
                onDetails: chat.moaDetailsOpened,
              ),
            if (state?.memoryRecalls.isNotEmpty == true ||
                reviewNotes.isNotEmpty)
              MemoryActivityCard(
                recalls: state?.memoryRecalls ?? const [],
                earlierRecallsOmitted: state?.earlierRecallsOmitted ?? false,
                reviewNotes: reviewNotes,
                onOpenMemory: chat.repository == null || chat.profile == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MemoryDestination(profile: chat.profile),
                        ),
                      ),
              ),
            if (usage != null && usage.shown)
              SessionUsageCard(controller: usage),
            if (billing != null &&
                billing.supported &&
                billingTier(billing) == ActivityTier.reference)
              BillingVerificationCard(controller: billing),
            if (connectors != null)
              ...connectorOperationCards(
                connectors,
                tier: ActivityTier.reference,
              ),
            if (connection != null)
              if (connectorOperationCards(
                    connection,
                    tier: ActivityTier.reference,
                    connectionWide: true,
                  )
                  case final cards when cards.isNotEmpty) ...[
                // Connection-wide operations belong to no chat; say so.
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('Connection activity'),
                ),
                ...cards,
              ],
            for (final result in sideResults?.results ?? const <SideResult>[])
              SideResultCard(
                key: ValueKey((result.kind, result.taskId)),
                result: result,
                onDetails: sideResults?.detailsOpened,
              ),
            for (final notice in chat.noticesIn(t))
              AgentNoticeCard(
                key: ObjectKey(notice),
                notice: notice,
                onDismiss: () => chat.dismissNotice(t, notice),
                onDetails: chat.warningDetailsOpened,
              ),
            if (acknowledgement != null)
              SessionAcknowledgementCard(
                acknowledgement: acknowledgement,
                onDetails: reactions?.detailsOpened,
              ),
          ],
        );
      },
    );
  }
}

/// Reads the chat's agents while the panel is on screen, and not when it is
/// hidden or under another page.
class _RosterDemand extends StatefulWidget {
  const _RosterDemand({required this.roster, required this.child});

  final SubagentRoster roster;
  final Widget child;

  @override
  State<_RosterDemand> createState() => _RosterDemandState();
}

class _RosterDemandState extends State<_RosterDemand> {
  RosterWatch? _watch;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        Visibility.of(context) && TickerMode.valuesOf(context).enabled;
    if (visible) {
      _watch ??= widget.roster.watch();
    } else {
      _watch?.close();
      _watch = null;
    }
  }

  @override
  void didUpdateWidget(_RosterDemand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.roster, widget.roster)) {
      // Only a panel that is shown reads: a covered one waits for its next
      // visibility change.
      final wasWatching = _watch != null;
      _watch?.close();
      _watch = wasWatching ? widget.roster.watch() : null;
    }
  }

  @override
  void dispose() {
    _watch?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One agent row of the panel; the run time of a running agent moves each
/// second.
class _AgentRowTile extends StatefulWidget {
  const _AgentRowTile({
    super.key,
    required this.row,
    required this.level,
    required this.onShowDetails,
    required this.onStop,
  });

  final RosterRow row;
  final int level;
  final VoidCallback? onShowDetails;
  final VoidCallback? onStop;

  @override
  State<_AgentRowTile> createState() => _AgentRowTileState();
}

class _AgentRowTileState extends State<_AgentRowTile> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_AgentRowTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.row.active) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return AgentRow(
      model: AgentRowModel(
        goal: row.goal,
        state: row.state,
        runTime: agentRunTime(row),
        toolCount: row.toolCount ?? 0,
        currentTool: row.lastTool,
        currentPreview: row.lastToolPreview,
        level: widget.level,
      ),
      onShowDetails: widget.onShowDetails,
      onStop: widget.onStop,
    );
  }
}

/// "3 earlier agents not shown", under the ended agents.
class _EarlierAgentsLine extends StatelessWidget {
  const _EarlierAgentsLine(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Text(
      context.l10n.chatSubagentsEarlierNotShown(count),
      style: TextStyle(color: context.hermesColors.subtleText),
    ),
  );
}
