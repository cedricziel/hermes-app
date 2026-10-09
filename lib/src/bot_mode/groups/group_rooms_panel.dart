import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/grouped_list.dart';
import '../bot_mode_roster_repository.dart';
import '../group_protocol/hermes_groups_repository.dart';
import 'group_room_controller.dart';
import 'widgets/group_widgets.dart';

/// Hosted rooms only. Legacy Desktop metadata rooms have no migration contract.
class GroupRoomsPanel extends StatefulWidget {
  const GroupRoomsPanel({
    super.key,
    required this.repository,
    required this.bots,
    required this.onOpen,
  });
  final HermesGroupsRepository repository;
  final List<BotModeBot> bots;
  final ValueChanged<GroupRoom> onOpen;
  @override
  State<GroupRoomsPanel> createState() => GroupRoomsPanelState();
}

class GroupRoomsPanelState extends State<GroupRoomsPanel> {
  final _tombstones = <String>{};
  List<GroupRoom> _rooms = [];
  final _states = <String, GroupState>{};
  bool _loading = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(GroupRoomsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _rooms = [];
      _states.clear();
      _tombstones.clear();
      refresh();
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final repository = widget.repository;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final probe = await repository.probe();
      if (probe.availability == GroupsAvailability.unsupported ||
          probe.availability == GroupsAvailability.malformed) {
        throw StateError(
          'Hosted groups require a server update with protocol 2. Direct bot conversations remain available.',
        );
      }
      final rooms = <GroupRoom>[];
      int? offset;
      do {
        final page = await repository.list(offset: offset);
        rooms.addAll(page.rooms);
        if (page.nextOffset != null && page.nextOffset! <= (offset ?? -1)) {
          throw const FormatException('Invalid room pagination');
        }
        offset = page.nextOffset;
      } while (offset != null);
      final states = <String, GroupState>{};
      for (final room in rooms) {
        try {
          states[room.roomId] = await repository.state(room.roomId);
        } on Object {
          /* Listing survives a single unavailable room state. */
        }
      }
      if (!mounted || generation != _generation) return;
      for (final room in [
        ...rooms,
        ...states.values.map((state) => state.room),
      ]) {
        if (room.disbandedAt != null) _tombstones.add(room.roomId);
      }
      setState(() {
        _rooms = rooms
            .where((room) => !_tombstones.contains(room.roomId))
            .toList();
        _states
          ..clear()
          ..addAll(states);
      });
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = GroupFailure.from(error).message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void removeRoom(String roomId) {
    _tombstones.add(roomId);
    if (mounted) {
      setState(() {
        _rooms.removeWhere((room) => room.roomId == roomId);
        _states.remove(roomId);
      });
    }
  }

  Future<void> _create() async {
    final repository = widget.repository;
    final members = widget.bots
        .map(
          (bot) => GroupMember.fromJson({
            'member_id': bot.name,
            'profile': bot.name,
            'handle': bot.name,
            'display_name': bot.title,
          }),
        )
        .toList();
    final name = TextEditingController();
    final operation = groupOperationId();
    var selected = <String>{};
    var pending = false;
    var attempted = false;
    String? error;
    GroupRoom? created;
    try {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Create group'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      enabled: !pending && !attempted,
                      decoration: const InputDecoration(labelText: 'Room name'),
                      onChanged: (_) => update(() {}),
                    ),
                    const SizedBox(height: 16),
                    GroupMemberChecklist(
                      members: members,
                      selected: selected,
                      enabled: !pending && !attempted,
                      note: groupInteractionLimitation,
                      onChanged: (value) => update(() => selected = value),
                    ),
                    if (error != null) Text(error!),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: pending ? null : () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    pending ||
                        name.text.trim().isEmpty ||
                        selected.length < 2 ||
                        selected.length > 6
                    ? null
                    : () async {
                        update(() {
                          pending = true;
                          attempted = true;
                        });
                        try {
                          created = await repository.create(
                            name: name.text.trim(),
                            members: members
                                .where((m) => selected.contains(m.memberId))
                                .toList(),
                            operationId: operation,
                          );
                          if (dialog.mounted) Navigator.pop(dialog);
                        } on Object catch (failure) {
                          if (dialog.mounted) {
                            update(() {
                              error = GroupFailure.from(failure).message;
                              pending = false;
                            });
                          }
                        }
                      },
                child: Text(
                  pending
                      ? 'Creating…'
                      : error == null
                      ? 'Create'
                      : 'Retry',
                ),
              ),
            ],
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
      if (attempted && mounted && repository == widget.repository) {
        await refresh();
      }
      if (created != null && mounted && repository == widget.repository) {
        if (mounted && !_tombstones.contains(created!.roomId)) {
          widget.onOpen(created!);
        }
      }
    } finally {
      name.dispose();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = widget.repository.executionUnavailableReason;
    final canCreate = unavailable == null && widget.bots.length >= 2;
    final error = _error;
    return GroupedSection(
      header: 'Groups',
      dividerIndent: GroupedMetrics.of(context).indentAfterTile,
      footer:
          unavailable ??
          'Bots in a group work on a task together on the server. A group '
              'has 2–6 bots, fixed when it is created.',
      children: [
        if (_loading && _rooms.isEmpty)
          const GroupedRow(
            title: 'Loading groups',
            trailing: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ),
        if (error != null)
          GroupedRow(
            title: 'Could not load groups',
            warning: error,
            trailing: TextButton(
              onPressed: refresh,
              child: const Text('Retry'),
            ),
          ),
        if (!_loading && error == null && _rooms.isEmpty)
          const GroupedRow(
            title: 'No groups yet',
            subtitle: 'Create a room with 2–6 bots.',
          ),
        for (final room in _rooms)
          if (_states[room.roomId] case final state)
            GroupRoomRow(
              room: state?.room ?? room,
              needsAttention: state?.pendingActions.isNotEmpty == true,
              activity: state?.driverStatus?.working == true ? 'Working' : null,
              onOpen: () => widget.onOpen(room),
            ),
        Opacity(
          opacity: canCreate ? 1 : 0.45,
          child: GroupedRow(
            leading: const GroupedTile(child: AppIcon(AppIcons.add)),
            title: 'Create group',
            chevron: false,
            onTap: canCreate ? _create : null,
          ),
        ),
      ],
    );
  }
}
