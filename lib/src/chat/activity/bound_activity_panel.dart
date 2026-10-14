import 'package:flutter/widgets.dart';

import '../chat_controller.dart';
import '../chat_models.dart';
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
class BoundActivityPanel extends StatelessWidget {
  const BoundActivityPanel({
    super.key,
    required this.chat,
    required this.thread,
    this.onClose,
    this.scrollController,
  });

  final ChatController chat;
  final ChatThread? thread;
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
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) => _sections(context, t),
    );
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
      ]),
      builder: (context, _) {
        final state = chat.sessionStateIn(t);
        final processes = chat.processOutputsIn(t);
        final acknowledgement = reactions?.acknowledgement;
        return ActivityPanel(
          key: ObjectKey(t),
          onClose: onClose,
          scrollController: scrollController,
          now: [
            if (state != null &&
                state.visible &&
                sessionStateTier(state) == ActivityTier.working)
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
            for (final progress in chat.moaIn(t))
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
