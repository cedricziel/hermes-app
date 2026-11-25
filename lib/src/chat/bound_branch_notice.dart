import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'chat_controller.dart';
import 'chat_models.dart';
import 'widgets/chat_branch_notice.dart';

/// The "Branched from …" row of [thread], bound to [chat]: nothing for a chat
/// that is not a branch, a tap that opens the original, and one spoken
/// announcement for each state a tap leads to (opening, and why it failed).
class BoundBranchNotice extends StatefulWidget {
  const BoundBranchNotice({
    super.key,
    required this.chat,
    required this.thread,
  });

  final ChatController chat;
  final ChatThread thread;

  @override
  State<BoundBranchNotice> createState() => _BoundBranchNoticeState();
}

class _BoundBranchNoticeState extends State<BoundBranchNotice> {
  /// The state last seen, spoken or not: a chat opened while its original is
  /// already deleted or unreachable says nothing; only a change seen here, which
  /// a tap caused, is announced.
  late BranchParentStatus? _announced = widget.chat.branchParentStatusOf(
    widget.thread,
  );

  @override
  void didUpdateWidget(BoundBranchNotice old) {
    super.didUpdateWidget(old);
    if (old.thread.id != widget.thread.id) {
      _announced = widget.chat.branchParentStatusOf(widget.thread);
    }
  }

  void _announce(BranchParentStatus? status) {
    if (status == _announced) return;
    _announced = status;
    final l10n = context.l10n;
    final text = switch (status) {
      BranchParentStatus.opening => l10n.chatWidgetsBranchNoticeOpening,
      BranchParentStatus.deleted => l10n.chatWidgetsBranchNoticeDeleted,
      BranchParentStatus.unreachable => l10n.chatWidgetsBranchNoticeUnreachable,
      _ => null,
    };
    if (text == null) return;
    final view = View.of(context);
    final direction = Directionality.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        text,
        direction,
      ).catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.chat,
    builder: (context, _) {
      final chat = widget.chat;
      final thread = widget.thread;
      final status = chat.branchParentStatusOf(thread);
      if (status == null) return const SizedBox.shrink();
      _announce(status);
      final title = chat.branchParentTitleOf(thread);
      return ChatBranchNotice(
        state: switch (status) {
          BranchParentStatus.opening => ChatBranchNoticeState.opening,
          BranchParentStatus.deleted => ChatBranchNoticeState.deleted,
          BranchParentStatus.unreachable => ChatBranchNoticeState.unreachable,
          BranchParentStatus.resting when title != null =>
            ChatBranchNoticeState.title,
          BranchParentStatus.resting => ChatBranchNoticeState.unknown,
        },
        parentTitle: title,
        onTap: chat.canOpenBranchParent(thread)
            ? () => unawaited(chat.openBranchParent(thread))
            : null,
      );
    },
  );
}
