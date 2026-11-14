import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../chat_controller.dart';
import '../chat_models.dart';
import 'widgets/activity_line.dart';
import 'widgets/activity_line_model.dart';
import 'widgets/mac_toolbar_subtitle.dart';

/// The activity line of [thread] in [chat]: it says what Hermes is doing now
/// and folds away when nothing is, so it is always built and decides itself.
/// [onOpen] opens the Activity panel.
class BoundActivityLine extends StatelessWidget {
  const BoundActivityLine({
    super.key,
    required this.chat,
    required this.thread,
    required this.onOpen,
  });

  final ChatController chat;
  final ChatThread thread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    // The plan changes without the chat notifying, and its controller is
    // replaced with the session, so it is looked up on every chat change.
    builder: (context, _) => ListenableBuilder(
      listenable: chat.todoPlanIn(thread) ?? chat,
      builder: (context, _) {
        final summary = chat.workingSummaryIn(thread);
        return ActivityLine(
          model: summary == null
              ? null
              : ActivityLineModel.fromSummary(context.l10n, summary),
          onOpen: onOpen,
        );
      },
    ),
  );
}

/// What a Mac toolbar draws as its subtitle: "profile · model", and while
/// [thread] works the newest sentence after it.
///
/// Pass [subtitle] and [subtitleBuilder] to `MacChatToolbar` or
/// `ConversationWindowToolbar`. The subtitle is never null while working, so
/// the toolbar runs the builder even with neither a profile nor a model.
({String? subtitle, Widget Function(BuildContext, Widget)? subtitleBuilder})
workingToolbarSubtitle(
  ChatController chat,
  ChatThread? thread, {
  String? profile,
  String? model,
}) {
  final lead = [?profile, ?model];
  final summary = thread == null ? null : chat.workingSummaryIn(thread);
  if (summary == null) {
    return (
      subtitle: lead.isEmpty ? null : lead.join(' · '),
      subtitleBuilder: null,
    );
  }
  return (
    subtitle: lead.join(' · '),
    subtitleBuilder: (context, _) => MacToolbarSubtitle(
      profile: profile,
      model: model,
      status: workingSentenceText(context.l10n, summary.sentence),
      busy: true,
    ),
  );
}
