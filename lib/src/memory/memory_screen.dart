import 'package:flutter/material.dart';

import '../widgets/content_column.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'memory_controller.dart';
import 'memory_repository.dart';

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

class _MemoryScreenState extends State<MemoryScreen> {
  bool _allowPop = false;
  MemoryController get controller => widget.controller;

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
        body: MemoryView(
          entries: controller.entries,
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
    final blocked =
        pending ||
        controller.mutation == MemoryMutation.uncertain ||
        controller.mutation == MemoryMutation.conflict;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.editing)
          TextFormField(
            key: ValueKey(controller.detail),
            initialValue: controller.draft,
            enabled: !pending,
            minLines: 4,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Full memory content',
              border: OutlineInputBorder(),
            ),
            onChanged: controller.setDraft,
          ),
        if (controller.mutationMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(controller.mutationMessage!),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!controller.editing)
              TextButton(
                onPressed: blocked ? null : controller.beginEdit,
                child: const Text('Edit'),
              ),
            if (controller.editing)
              FilledButton(
                onPressed: controller.canSave
                    ? () => controller.mutate(delete: false)
                    : null,
                child: Text(pending ? 'Saving...' : 'Save'),
              ),
            if (controller.editing)
              TextButton(
                onPressed: pending ? null : onCancel,
                child: const Text('Cancel edit'),
              ),
            TextButton(
              onPressed: blocked ? null : onDelete,
              child: const Text('Delete'),
            ),
            if (controller.mutation == MemoryMutation.uncertain)
              TextButton(
                onPressed: controller.reconcile,
                child: const Text('Check current memories'),
              ),
          ],
        ),
        if (pending) const LinearProgressIndicator(),
      ],
    );
  }
}

class MemoryView extends StatelessWidget {
  const MemoryView({
    super.key,
    this.entries = const [],
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
  final List<MemoryEntry> entries;
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
              const SizedBox(height: 12),
              if (showContent) SelectableText(opened.content),
              if (editor != null) ...[const SizedBox(height: 20), editor!],
            ],
          ),
        ),
      );
    }
    if (entries.isEmpty) {
      return ContentColumn(
        child: StateMessage(
          title: 'No memories in this profile',
          action: FilledButton(
            onPressed: onRefresh,
            child: const Text('Refresh'),
          ),
        ),
      );
    }
    return GroupedListView(
      children: [
        GroupedSection(
          children: [
            for (final entry in entries)
              GroupedRow(
                title: entry.label,
                subtitle: entry.sourceLabel,
                onTap: () => onOpen(entry),
              ),
          ],
        ),
        GroupedSection(
          children: [GroupedRow(title: 'Refresh', onTap: onRefresh)],
        ),
      ],
    );
  }
}
