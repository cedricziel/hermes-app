import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../chat/chat_models.dart' show ApprovalRequest;
import '../../../chat/widgets/approval_card.dart';
import '../../../widgets/disclosure_tile.dart';
import '../../../widgets/markdown_links.dart';
import '../../group_protocol/hermes_groups_repository.dart';

String groupMemberName(List<GroupMember> members, String id) {
  for (final member in members) {
    if (member.memberId == id) return member.displayName ?? member.profile;
  }
  return id;
}

class GroupInteractionNotice extends StatelessWidget {
  const GroupInteractionNotice({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Interactive requests cannot be answered in hosted groups. A member may wait for a response; use Stop if the task stalls.',
          ),
        ),
      ],
    ),
  );
}

class GroupRoomRow extends StatelessWidget {
  const GroupRoomRow({
    super.key,
    required this.room,
    required this.onOpen,
    this.needsAttention = false,
    this.activity,
  });
  final GroupRoom room;
  final VoidCallback onOpen;
  final bool needsAttention;
  final String? activity;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.groups_outlined),
    title: Text(room.name, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${room.members.length} members · ${needsAttention ? 'Needs your attention' : activity ?? 'Hosted conversation'}',
    ),
    onTap: onOpen,
  );
}

class GroupMemberChecklist extends StatefulWidget {
  const GroupMemberChecklist({
    super.key,
    required this.members,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });
  final List<GroupMember> members;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  @override
  State<GroupMemberChecklist> createState() => _GroupMemberChecklistState();
}

class _GroupMemberChecklistState extends State<GroupMemberChecklist> {
  var _query = '';
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        decoration: const InputDecoration(labelText: 'Search members'),
        onChanged: (query) => setState(() => _query = query.toLowerCase()),
      ),
      for (final member in widget.members)
        if ('${member.displayName ?? ''} ${member.profile} ${member.handle}'
            .toLowerCase()
            .contains(_query))
          CheckboxListTile(
            title: Text(member.displayName ?? member.profile),
            subtitle: Text('@${member.handle}'),
            value: widget.selected.contains(member.memberId),
            onChanged:
                !widget.enabled ||
                    (!widget.selected.contains(member.memberId) &&
                        widget.selected.length >= 6)
                ? null
                : (value) => widget.onChanged(
                    {...widget.selected, if (value == true) member.memberId}
                      ..removeWhere(
                        (id) => value == false && id == member.memberId,
                      ),
                  ),
          ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Choose 2–6 bots. Membership is fixed for this room.'),
      ),
    ],
  );
}

/// Durable prose retains the recorded actor and thread. Other event kinds
/// are activity, with their payload inspectable instead of impersonating prose.
class GroupEventRow extends StatelessWidget {
  const GroupEventRow({
    super.key,
    required this.event,
    required this.members,
    this.onReply,
    this.threadLabel,
  });
  final GroupEvent event;
  final List<GroupMember> members;
  final VoidCallback? onReply;
  final String? threadLabel;
  @override
  Widget build(BuildContext context) {
    final prose =
        {
          'message.user',
          'message.assistant',
          'message.member',
        }.contains(event.kind) &&
        event.payload['text'] is String;
    final author = event.actorKind == 'user'
        ? 'You'
        : groupMemberName(members, event.actorId);
    final thread = event.payload['thread_id'];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: scheme.onSurface,
                  child: Text(
                    author.characters.first.toUpperCase(),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(author, style: theme.textTheme.labelLarge),
                ),
                if (thread is String)
                  Text(
                    threadLabel ?? 'Discussion thread',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
              ],
            ),
            if (prose) ...[
              const SizedBox(height: 10),
              GptMarkdown(
                event.payload['text'] as String,
                onLinkTap: markdownLinkHandler(),
              ),
              if (onReply != null && thread is String)
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply in thread'),
                ),
            ] else
              DisclosureTile(
                title: Text(switch (event.kind) {
                  'turn.started' => 'Started work',
                  'turn.settled' => 'Work completed',
                  'turn.failed' => 'Work failed — review details',
                  'turn.cancelled' => 'Work stopped',
                  'room.created' => 'Group created',
                  'room.renamed' => 'Group renamed',
                  'room.disbanded' => 'Group disbanded',
                  _ => 'Room event: ${event.kind}',
                }),
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(event.payload),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String? _actionText(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

ApprovalRequest _approvalRequest(
  GroupPendingAction action, {
  bool allowOnce = true,
}) {
  final details = action.details['approval'] is Map
      ? action.details['approval'] as Map
      : action.details;
  return ApprovalRequest(
    requestId: action.requestId!,
    command: _actionText(details['command']) ?? '',
    description:
        _actionText(details['description']) ??
        'This member is waiting for your approval.',
    choices: allowOnce ? const ['once', 'deny'] : const ['deny'],
  );
}

class GroupActivity extends StatelessWidget {
  const GroupActivity({
    super.key,
    required this.working,
    required this.blocked,
    required this.counts,
    required this.members,
    required this.actions,
    required this.pending,
    required this.onStop,
    required this.onApprove,
    required this.onRetry,
    this.unavailableReason,
  });
  final bool working, blocked, pending;
  final Map<String, int> counts;
  final List<GroupMember> members;
  final List<GroupPendingAction> actions;
  final VoidCallback onStop;
  final Future<void> Function(GroupPendingAction, GroupApprovalChoice)
  onApprove;
  final ValueChanged<GroupPendingAction> onRetry;
  final String? unavailableReason;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unavailableReason != null) Text(unavailableReason!),
        if (working || blocked) const GroupInteractionNotice(),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              blocked
                  ? Icons.warning_amber_rounded
                  : working
                  ? Icons.autorenew
                  : Icons.check_circle_outline,
              size: 18,
            ),
            Text(
              blocked
                  ? 'Waiting for approval'
                  : working
                  ? 'Working'
                  : 'Idle',
            ),
            for (final entry in counts.entries)
              if (entry.value > 0) Text('${entry.value} ${entry.key}'),
            if (working || blocked)
              OutlinedButton(
                onPressed: pending ? null : onStop,
                child: const Text('Stop'),
              ),
          ],
        ),
        for (final action in actions)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.memberId == null
                        ? 'Task needs attention'
                        : groupMemberName(members, action.memberId!),
                  ),
                  if (action.kind == 'approval')
                    ApprovalCard(
                      key: ValueKey(
                        '${action.taskId}/${action.executionGeneration}/${action.requestId}',
                      ),
                      request: _approvalRequest(
                        action,
                        allowOnce: unavailableReason == null,
                      ),
                      onAnswer: pending
                          ? null
                          : (choice) => onApprove(
                              action,
                              choice == 'once'
                                  ? GroupApprovalChoice.once
                                  : GroupApprovalChoice.deny,
                            ),
                    )
                  else
                    Text(
                      _actionText(action.details['reason']) ??
                          'Pending ${action.kind}',
                    ),
                  if (!{'approval', 'retry'}.contains(action.kind))
                    const Text(
                      'This input cannot be answered in the hosted room. Stop the task if it stalls.',
                    ),
                  if (action.kind == 'retry')
                    TextButton(
                      onPressed: pending || unavailableReason != null
                          ? null
                          : () => onRetry(action),
                      child: const Text('Review retry'),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class GroupNotice extends StatelessWidget {
  const GroupNotice({
    super.key,
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) const CircularProgressIndicator.adaptive(),
        Text(message),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class GroupTextComposer extends StatelessWidget {
  const GroupTextComposer({
    super.key,
    required this.controller,
    required this.members,
    required this.discussionLabel,
    required this.pending,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
    required this.onNewTopic,
    this.retrySend = false,
  });
  final TextEditingController controller;
  final List<GroupMember> members;
  final String discussionLabel;
  final bool pending, enabled, retrySend;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend, onNewTopic;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(controller.text);
    final mentions = match == null
        ? <GroupMember>[]
        : members
              .where(
                (m) => m.handle.toLowerCase().startsWith(
                  match.group(1)!.toLowerCase(),
                ),
              )
              .toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  discussionLabel,
                  style: theme.textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: pending ? null : onNewTopic,
                child: const Text('New topic'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (mentions.isNotEmpty)
            Wrap(
              children: [
                for (final member in mentions)
                  TextButton(
                    onPressed: pending
                        ? null
                        : () {
                            final text = controller.text.replaceRange(
                              match!.end - match.group(1)!.length - 1,
                              match.end,
                              '@${member.handle} ',
                            );
                            controller.value = TextEditingValue(
                              text: text,
                              selection: TextSelection.collapsed(
                                offset: text.length,
                              ),
                            );
                            onChanged(text);
                          },
                    child: Text('@${member.handle}'),
                  ),
              ],
            ),
          TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: 1,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message group',
              hintText: 'Text and @mentions',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed:
                  enabled && !pending && controller.text.trim().isNotEmpty
                  ? onSend
                  : null,
              icon: const Icon(Icons.arrow_upward, size: 18),
              label: Text(
                pending
                    ? 'Sending…'
                    : retrySend
                    ? 'Review message retry'
                    : 'Send',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GroupConfirmation extends StatelessWidget {
  const GroupConfirmation({
    super.key,
    required this.title,
    required this.detail,
    required this.action,
    required this.onCancel,
    required this.onConfirm,
  });
  final String title, detail, action;
  final VoidCallback onCancel, onConfirm;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(detail),
    actions: [
      TextButton(onPressed: onCancel, child: const Text('Cancel')),
      FilledButton(onPressed: onConfirm, child: Text(action)),
    ],
  );
}
