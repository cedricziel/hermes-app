import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/content_column.dart';
import '../../widgets/settings_scaffold.dart';
import '../group_protocol/hermes_groups_repository.dart';
import 'group_room_controller.dart';
import 'widgets/group_widgets.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.repository,
    required this.room,
    this.onDisbanded,
  });
  final HermesGroupsRepository repository;
  final GroupRoom room;
  final VoidCallback? onDisbanded;
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with WidgetsBindingObserver {
  late GroupRoomController _room;
  final _text = TextEditingController();
  bool _reportedDisband = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attach();
  }

  void _attach() {
    _reportedDisband = false;
    _room = GroupRoomController(widget.repository, widget.room)
      ..addListener(_changed);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _room.setResumed(
      lifecycle == null || lifecycle == AppLifecycleState.resumed,
    );
  }

  @override
  void didUpdateWidget(GroupChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.room.roomId != widget.room.roomId) {
      _room.dispose();
      _text.clear();
      _attach();
      _room.setVisible(
        Visibility.of(context) && TickerMode.valuesOf(context).enabled,
      );
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_text.text != _room.draft) {
      _text.value = TextEditingValue(
        text: _room.draft,
        selection: TextSelection.collapsed(offset: _room.draft.length),
      );
    }
    setState(() {});
    if (_room.disbanded && !_reportedDisband) {
      _reportedDisband = true;
      widget.onDisbanded?.call();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _room.setVisible(
      Visibility.of(context) && TickerMode.valuesOf(context).enabled,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _room.setResumed(state == AppLifecycleState.resumed);
  Future<bool> _confirm(String title, String detail, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => GroupConfirmation(
          title: title,
          detail: detail,
          action: action,
          onCancel: () => Navigator.pop(dialog, false),
          onConfirm: () => Navigator.pop(dialog, true),
        ),
      ) ??
      false;
  Future<void> _rename() async {
    final name = TextEditingController(text: _room.room.name);
    try {
      final route = DialogRoute<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Rename group'),
          content: TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Room name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) {
                  Navigator.pop(dialog, name.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      final value = await Navigator.of(context).push(route);
      await route.completed;
      if (value != null && mounted) await _room.rename(value);
    } finally {
      name.dispose();
    }
  }

  Future<void> _disband() async {
    if (await _confirm(
          'Disband ${_room.room.name}?',
          'This stops group work and removes the room from the roster. Membership cannot be changed.',
          'Disband group',
        ) &&
        mounted) {
      await _room.disband();
    }
  }

  Future<void> _retry(GroupPendingAction action) async {
    if (await _confirm(
          'Retry task?',
          'The selected task is indeterminate or deferred. Review the room history before repeating its work.',
          'Retry task',
        ) &&
        mounted) {
      await _room.retryTask(action);
    }
  }

  Future<void> _send() async {
    final retry = _room.canRetrySend;
    if (retry &&
        !await _confirm(
          'Retry message?',
          'The app will check the durable log before retrying this exact message with its original identity.',
          'Retry message',
        )) {
      return;
    }
    if (mounted) await _room.send(retry: retry);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _room.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driver = _room.state?.driverStatus;
    final actionable = !_room.pending && !_room.disbanded;
    return SettingsScaffold(
      title: _room.room.name,
      subtitle: '${_room.room.members.length} members',
      previousTitle: 'Bots',
      actions: [
        SettingsBarAction.menu(
          label: 'Room actions',
          icon: AppIcons.more,
          menu: (_) => [
            PopupMenuItem(
              enabled: actionable,
              onTap: _rename,
              child: const Text('Rename'),
            ),
            PopupMenuItem(
              enabled: actionable,
              onTap: _disband,
              child: const Text('Disband'),
            ),
          ],
        ),
      ],
      body: _room.disbanded
          ? const Center(
              child: GroupNotice(message: 'This room has been disbanded.'),
            )
          : SafeArea(
              child: ContentColumn(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          if (_room.loading)
                            const GroupNotice(
                              message: 'Loading room history',
                              loading: true,
                            ),
                          if (_room.failure != null)
                            GroupNotice(
                              message: _room.failure!.message,
                              onRetry: () => unawaited(_room.refresh()),
                            ),
                          GroupActivity(
                            working: driver?.working ?? false,
                            blocked: driver?.blocked ?? false,
                            counts: driver?.counts ?? const {},
                            members: _room.room.members,
                            actions: _room.state?.pendingActions ?? const [],
                            pending: _room.pending,
                            unavailableReason: _room.unavailableReason,
                            onStop: () => unawaited(_room.stop()),
                            onApprove: _room.approve,
                            onRetry: (action) => unawaited(_retry(action)),
                          ),
                          for (final event in _room.events)
                            GroupEventRow(
                              key: ValueKey(event.eventId),
                              event: event,
                              threadLabel: _room.labelForThread(
                                event.payload['thread_id'] is String
                                    ? event.payload['thread_id'] as String
                                    : '',
                              ),
                              members: _room.room.members,
                              onReply: () => _room.replyTo(event),
                            ),
                        ],
                      ),
                    ),
                    GroupTextComposer(
                      controller: _text,
                      members: _room.mentionMembers,
                      discussionLabel: _room.discussionLabel,
                      pending: _room.pending,
                      enabled: _room.unavailableReason == null,
                      retrySend: _room.canRetrySend,
                      onChanged: (value) => _room.draft = value,
                      onSend: () => unawaited(_send()),
                      onNewTopic: _room.newTopic,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
