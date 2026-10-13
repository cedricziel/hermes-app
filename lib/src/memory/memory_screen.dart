import 'package:flutter/material.dart';

import '../widgets/content_column.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'memory_controller.dart';
import 'memory_repository.dart';

class MemoryScreen extends StatelessWidget {
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => SettingsScaffold(
      title: 'Memory',
      subtitle: controller.profile,
      subtitleMenu: profiles.isEmpty
          ? null
          : SettingsSubtitleMenu<Object?>(
              label: 'Choose memory profile',
              onSelected: (value) {
                if (value is String && value != controller.profile) {
                  onProfile?.call(value);
                }
              },
              itemBuilder: (_) => [
                for (final entry in profiles.entries)
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
        onRefresh: controller.load,
        onBack: controller.showList,
      ),
    ),
  );
}

class MemoryView extends StatelessWidget {
  const MemoryView({
    super.key,
    this.entries = const [],
    this.selected,
    this.detail,
    this.loading = false,
    this.failure,
    required this.onOpen,
    required this.onRefresh,
    required this.onBack,
  });
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
              SelectableText(opened.content),
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
