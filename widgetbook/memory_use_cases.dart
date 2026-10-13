import 'package:flutter/material.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode memoryNode() => WidgetbookComponent(
  name: 'Memory',
  useCases: [
    for (final state in [
      'Dirty editor',
      'Blank content',
      'Conflict',
      'Server rejection',
      'Pending save',
      'Uncertain save',
      'Permanent deletion',
    ])
      ...onEachPlatform(state, (_) => _editor(state)),
    ...onEachPlatform('Loading', (_) => _view(loading: true)),
    ...onEachPlatform('Empty', (_) => _view()),
    ...onEachPlatform(
      'Sources',
      (_) => _view(
        entries: const [
          MemoryEntry('memory', 'Preferred language', source: 'memory'),
          MemoryEntry('user', 'Work preferences', source: 'profile'),
        ],
      ),
    ),
    ...onEachPlatform(
      'Full content',
      (_) => _view(
        detail: MemoryDetail(
          const MemoryEntry('memory', 'Preferred language'),
          'User prefers Dart examples.\n${'Full memory content. ' * 100}',
        ),
      ),
    ),
    ...onEachPlatform(
      'Unavailable',
      (_) => _view(failure: MemoryFailure.unsupported),
    ),
    ...onEachPlatform(
      'Stale detail',
      (_) => _view(failure: MemoryFailure.missing),
    ),
  ],
);

Widget _view({
  List<MemoryEntry> entries = const [],
  MemoryDetail? detail,
  bool loading = false,
  MemoryFailure? failure,
}) => Scaffold(
  body: MemoryView(
    entries: entries,
    detail: detail,
    selected: detail?.entry,
    loading: loading,
    failure: failure,
    onOpen: (_) {},
    onRefresh: () {},
    onBack: () {},
  ),
);

Widget _editor(String state) {
  final controller = MemoryController()
    ..detail = const MemoryDetail(
      MemoryEntry('memory', 'Example memory'),
      'Original full content',
    )
    ..editing = true
    ..draft = state == 'Blank content' ? ' ' : 'Edited full content'
    ..mutation = switch (state) {
      'Conflict' => MemoryMutation.conflict,
      'Server rejection' => MemoryMutation.failed,
      'Pending save' => MemoryMutation.pending,
      'Uncertain save' => MemoryMutation.uncertain,
      _ => MemoryMutation.idle,
    }
    ..mutationMessage = switch (state) {
      'Conflict' =>
        'This memory changed. Discard and refresh before trying again.',
      'Server rejection' => 'The server rejected the change.',
      'Uncertain save' =>
        'The change may have completed. Check current memories.',
      _ => null,
    };
  if (state == 'Permanent deletion') {
    return const Scaffold(
      body: AlertDialog(
        title: Text('Permanently delete this memory?'),
        content: Text(
          'This removes the selected memory permanently. It cannot be restored from the app.',
        ),
      ),
    );
  }
  return Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: MemoryEditor(
        controller: controller,
        onDelete: () {},
        onCancel: () {},
      ),
    ),
  );
}
