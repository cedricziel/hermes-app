import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../../bot_screen/bot_screen_card_model.dart';
import '../../bot_screen/bot_screen_controller.dart';
import '../../bot_screen/widgets/bound_bot_screen_card.dart';
import '../../memory/memory_destination.dart';
import '../chat_controller.dart';
import '../chat_models.dart';
import '../memory/memory_activity_card.dart';
import '../reactions/reaction_cards.dart';
import '../session_usage/session_usage_card.dart';
import '../side_results/side_result_card.dart';
import '../side_results/side_result_state.dart';
import '../todo_plan/todo_plan_card.dart';
import '../widgets/agent_notice_card.dart';
import '../widgets/billing_verification_card.dart';
import '../widgets/connector_operation_cards.dart';
import '../widgets/moa_progress_card.dart';
import '../widgets/process_output_card.dart';
import '../widgets/session_status_card.dart';
import 'activity_tier.dart';
import 'widgets/activity_panel.dart';

/// The [ActivityPanel] of [thread] in [chat]: Working items under Now, the
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
  });

  final ChatController chat;
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
    return screen == null
        ? panel
        : BotScreenDemand(controller: screen, child: panel);
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

  Widget _sections(BuildContext context, ChatThread t) {
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
      ]),
      builder: (context, _) {
        final state = chat.sessionStateIn(t);
        final processes = chat.processOutputsIn(t);
        final acknowledgement = reactions?.acknowledgement;
        final screenModel = _screenCard(t);
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
          now: [
            if (screenModel != null)
              BoundBotScreenCard(
                key: const Key('bot-screen-card'),
                controller: screen!,
                model: screenModel,
                onEnlarge: onEnlargeScreen,
              ),
            if (state != null &&
                state.visible &&
                sessionStateTier(state) == ActivityTier.working)
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
          ],
          plan: plan != null && plan.hasPlan
              ? TodoPlanCard(state: plan, initiallyOpen: true)
              : null,
          session: [
            if (state != null &&
                state.visible &&
                sessionStateTier(state) == ActivityTier.reference)
              SessionStatusCard(
                state: state,
                onDetails: chat.sessionDetailsOpened,
              ),
            if (processes != null) ...[
              for (final process in processes.cards)
                ProcessOutputCard(
                  key: ValueKey(process.processId),
                  output: process,
                  onDetails: chat.processOutputDetailsOpened,
                ),
              if (processes.omittedCards)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Earlier process cards omitted.'),
                ),
            ],

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
