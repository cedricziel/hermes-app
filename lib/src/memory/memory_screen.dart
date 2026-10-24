import 'package:flutter/material.dart';

import '../widgets/content_column.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'memory_controller.dart';
import 'memory_repository.dart';
import 'memory_usage.dart';
import 'widgets/memory_entry_editor.dart';
import 'widgets/memory_entry_list.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({
    super.key,
    required this.controller,
    this.profiles = const {},
    this.onProfile,
  });
  final MemoryController controller;
  final Map<String, String> profiles;
  final ValueChanged<String>? onProfile;
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with SingleTickerProviderStateMixin {
  bool _allowPop = false;
  bool _switching = false;
  late final _tabs = TabController(length: MemoryTab.values.length, vsync: this)
    ..addListener(_onTab);
  MemoryController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_syncTab);
  }

  @override
  void dispose() {
    controller.removeListener(_syncTab);
    _tabs.dispose();
    super.dispose();
  }

  void _syncTab() {
    if (_tabs.index != controller.tab.index) _tabs.index = controller.tab.index;
  }

  Future<void> _onTab() async {
    final next = MemoryTab.values[_tabs.index];
    if (_switching || next == controller.tab) return;
    _switching = true;
    final leave = await _leave();
    _switching = false;
    if (!mounted) return;
    if (leave) {
      controller.selectTab(next);
    } else {
      _tabs.index = controller.tab.index;
    }
  }

  String? _place() {
    final open = controller.selected, position = controller.position;
    if (open == null || position == null) return null;
    return 'Entry ${position.index} of ${position.count} in '
        '${open.tab.label} (${open.tab.file})';
  }

  Future<bool> _leave() async {
    if (!controller.needsLeaveConfirmation) return true;
    FocusManager.instance.primaryFocus?.unfocus();
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this memory?'),
        content: Text(
          controller.mutation == MemoryMutation.pending
              ? 'The request may still complete in the original profile. Leaving discards this draft.'
              : 'Leaving discards your unsaved draft. Any unconfirmed change may still have completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard and leave'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _delete() async {
    final original = controller.detail;
    final profile = controller.profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete this memory?'),
        content: const Text(
          'This removes the selected memory permanently. It cannot be restored from the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        identical(original, controller.detail) &&
        profile == controller.profile) {
      await controller.mutate(delete: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope(
      canPop: _allowPop || !controller.needsLeaveConfirmation,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !await _leave() || !mounted) return;
        controller.discardEdit();
        setState(() => _allowPop = true);
        if (context.mounted) Navigator.of(context).pop();
      },
      child: SettingsScaffold(
        title: 'Memory',
        subtitle: controller.profile,
        subtitleMenu: widget.profiles.isEmpty
            ? null
            : SettingsSubtitleMenu<Object?>(
                label: 'Choose memory profile',
                onSelected: (value) async {
                  if (value is String &&
                      value != controller.profile &&
                      await _leave() &&
                      mounted) {
                    widget.onProfile?.call(value);
                  }
                },
                itemBuilder: (_) => [
                  for (final entry in widget.profiles.entries)
                    PopupMenuItem<Object?>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
              ),
        tabs: [for (final tab in MemoryTab.values) tab.label],
        tabController: _tabs,
        body: MemoryView(
          usage: controller.usageOf(controller.tab),
          entries: controller.entriesIn(controller.tab),
          place: _place(),
          selected: controller.selected,
          detail: controller.detail,
          loading: controller.loading,
          failure: controller.failure,
          onOpen: controller.open,
          onRefresh: () async {
            if (await _leave() && mounted) await controller.load();
          },
          onBack: () async {
            if (await _leave() && mounted) controller.showList();
          },
          showContent: !controller.editing,
          editor: controller.detail == null
              ? null
              : MemoryEditor(
                  controller: controller,
                  onDelete: _delete,
                  onCancel: () async {
                    if (await _leave() && mounted) controller.discardEdit();
                  },
                ),
        ),
      ),
    ),
  );
}

class MemoryEditor extends StatelessWidget {
  const MemoryEditor({
    super.key,
    required this.controller,
    required this.onDelete,
    required this.onCancel,
  });
  final MemoryController controller;
  final VoidCallback onDelete, onCancel;
  @override
  Widget build(BuildContext context) {
    final pending = controller.mutation == MemoryMutation.pending;
    final uncertain = controller.mutation == MemoryMutation.uncertain;
    return MemoryEntryEditor(
      tab: controller.selected?.tab ?? controller.tab,
      editing: controller.editing,
      draft: controller.draft,
      fieldKey: controller.detail,
      left: controller.leftWithDraft,
      message: controller.mutationMessage,
      pending: pending,
      blocked:
          pending ||
          uncertain ||
          controller.mutation == MemoryMutation.conflict,
      canSave: controller.canSave,
      uncertain: uncertain,
      onChanged: controller.setDraft,
      onEdit: controller.beginEdit,
      onSave: () => controller.mutate(delete: false),
      onCancel: onCancel,
      onDelete: onDelete,
      onCheck: controller.reconcile,
    );
  }
}

class MemoryView extends StatelessWidget {
  const MemoryView({
    super.key,
    this.usage = const MemoryUsage(used: 0, entries: 0),
    this.entries = const [],
    this.place,
    this.selected,
    this.detail,
    this.loading = false,
    this.failure,
    this.editor,
    this.showContent = true,
    required this.onOpen,
    required this.onRefresh,
    required this.onBack,
  });
  final bool showContent;
  final Widget? editor;
  final MemoryUsage usage;

  /// The entries of the file shown.
  final List<MemoryEntry> entries;

  /// Where the open entry lives, such as "Entry 2 of 4 in About you (USER.md)".
  final String? place;
  final MemoryEntry? selected;
  final MemoryDetail? detail;
  final bool loading;
  final MemoryFailure? failure;
  final ValueChanged<MemoryEntry> onOpen;
  final VoidCallback onRefresh, onBack;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final error = failure;
    if (error != null) {
      return ContentColumn(
        child: StateMessage(
          title: error.message,
          action: FilledButton(
            onPressed: onRefresh,
            child: const Text('Refresh'),
          ),
        ),
      );
    }
    final opened = detail;
    if (opened != null) {
      return ContentColumn(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(onPressed: onBack, child: const Text('All memories')),
              if (place != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    place!,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              const SizedBox(height: 12),
              if (showContent) SelectableText(opened.content),
              if (editor != null) ...[const SizedBox(height: 20), editor!],
            ],
          ),
        ),
      );
    }
    return MemoryEntryList(
      usage: usage,
      entries: [for (final entry in entries) entry.text],
      onOpen: (index) => onOpen(entries[index]),
      onRefresh: onRefresh,
    );
  }
}
