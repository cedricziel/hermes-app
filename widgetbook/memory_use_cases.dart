import 'package:flutter/material.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:hermes_app/src/memory/memory_provider.dart';
import 'package:hermes_app/src/memory/memory_settings.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';
import 'package:hermes_app/src/memory/widgets/memory_confirm_dialogs.dart';
import 'package:hermes_app/src/memory/widgets/memory_entry_editor.dart';
import 'package:hermes_app/src/memory/widgets/memory_entry_list.dart';
import 'package:hermes_app/src/memory/widgets/memory_fill_bar.dart';
import 'package:hermes_app/src/memory/widgets/memory_learning_section.dart';
import 'package:hermes_app/src/memory/widgets/memory_reset_dialog.dart';
import 'package:hermes_app/src/memory/widgets/memory_storage_section.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
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
    ])
      ...onEachPlatform(state, (_) => _editor(state)),
    ...onEachPlatform(
      'Delete confirmation',
      (_) => _behindDialog(MemoryDeleteAlert(onCancel: () {}, onDelete: () {})),
    ),
    ...onEachPlatform(
      'Leave confirmation',
      (_) => _behindDialog(
        MemoryLeaveAlert(pending: false, onKeep: () {}, onDiscard: () {}),
      ),
    ),
    ...onEachPlatform(
      'Leave confirmation, save pending',
      (_) => _behindDialog(
        MemoryLeaveAlert(pending: true, onKeep: () {}, onDiscard: () {}),
      ),
    ),
    ...onEachPlatform(
      'Reject all confirmation',
      (_) => _behindDialog(
        MemoryRejectAllAlert(count: 3, onCancel: () {}, onReject: () {}),
      ),
    ),
    ...onEachPlatform(
      'Reject all confirmation, one change',
      (_) => _behindDialog(
        MemoryRejectAllAlert(count: 1, onCancel: () {}, onReject: () {}),
      ),
    ),
    for (final (state, settings, unreadable, message) in [
      ('Learning, defaults', MemorySettings.defaults, false, null),
      ('Learning, all off', _allOff, false, null),
      ('Learning, unknown values', _unknown, false, null),
      (
        'Learning, a change failed',
        MemorySettings.defaults,
        false,
        "Couldn't change Keep agent notes. Try again.",
      ),
      ('Learning, unreadable', null, true, null),
    ])
      ...onEachPlatform(
        state,
        (_) => Scaffold(
          body: GroupedListView(
            children: [
              MemoryLearningSection(
                settings: settings,
                unreadable: unreadable,
                message: message,
                onChanged: (_, _) {},
                onRetry: () {},
              ),
            ],
          ),
        ),
      ),
    for (final (state, provider, failed, notice) in [
      ('Storage, built-in', MemoryProviderStatus.builtin, false, null),
      (
        'Storage, named provider',
        const MemoryProviderStatus(
          MemoryProviderState.ready,
          name: 'honcho',
          description: 'Honcho memory',
        ),
        false,
        null,
      ),
      (
        'Storage, provider missing',
        const MemoryProviderStatus(MemoryProviderState.missing, name: 'honcho'),
        false,
        null,
      ),
      (
        'Storage, needs setup',
        const MemoryProviderStatus(
          MemoryProviderState.needsConfig,
          name: 'mem0',
          description: 'Mem0 memory',
        ),
        false,
        null,
      ),
      ('Storage, read failed', null, true, null),
      (
        'Storage, reset done',
        MemoryProviderStatus.builtin,
        false,
        const MemoryNotice(
          'Reset about you. New chats start without it.',
          MemoryNoticeTone.success,
        ),
      ),
      (
        'Storage, reset refused',
        MemoryProviderStatus.builtin,
        false,
        const MemoryNotice(
          'The server refused the reset.',
          MemoryNoticeTone.error,
        ),
      ),
    ])
      ...onEachPlatform(
        state,
        (_) => Scaffold(
          body: GroupedListView(
            children: [
              MemoryStorageSection(
                provider: provider,
                providerFailed: failed,
                notice: notice,
                onOpenProviders: () {},
                onRetry: () {},
                onReset: () {},
              ),
            ],
          ),
        ),
      ),
    ...onEachPlatform(
      'Reset alert',
      (_) => Scaffold(
        body: MemoryResetAlert(
          profile: 'work',
          onPick: (_) {},
          onCancel: () {},
        ),
      ),
    ),
    ...onEachPlatform('Loading', (_) => _view(loading: true)),
    ...onEachPlatform('Empty', (_) => _view()),
    for (final (state, usage) in [
      ('Fill bar', _usage([300, 300, 306], limit: 1375)),
      ('Fill bar, nearly full', _usage([2100], limit: 2200)),
      ('Fill bar, no limit known', _usage([300, 300])),
      ('Fill bar, lower bound', _usage([1200, 40], limit: 1375, cut: true)),
      ('Fill bar, empty', _usage([], limit: 1375)),
    ])
      ...onEachPlatform(state, (_) => frame(MemoryFillBar(usage: usage))),
    for (final (state, texts, usage) in [
      (
        'Entries',
        _entries,
        _usage([for (final text in _entries) text.length], limit: 1375),
      ),
      ('Entries, nearly full', _entries, _usage([1300], limit: 1375)),
      ('Entries, empty', const <String>[], _usage([], limit: 1375)),
    ])
      ...onEachPlatform(
        state,
        (_) => Scaffold(
          body: MemoryEntryList(
            usage: usage,
            entries: texts,
            onOpen: (_) {},
            onRefresh: () {},
          ),
        ),
      ),
    for (final (state, draft, left) in [
      ('Editor, viewing', null, 463),
      ('Editor, characters left', 'Prefers metric units.', 453),
      ('Editor, over the limit', 'Prefers metric units.', -137),
      ('Editor, no limit known', 'Prefers metric units.', null),
    ])
      ...onEachPlatform(
        state,
        (_) => Scaffold(
          body: frame(
            MemoryEntryEditor(
              tab: MemoryTab.aboutYou,
              editing: draft != null,
              draft: draft,
              left: left,
              onChanged: (_) {},
              onEdit: () {},
              onSave: () {},
              onCancel: () {},
              onDelete: () {},
              onCheck: () {},
            ),
          ),
        ),
      ),
    ...onEachPlatform(
      'Full content',
      (_) => _view(
        place: 'Entry 2 of 4 in About you (USER.md)',
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

final _allOff = MemorySettings.defaults
    .withValue(MemorySetting.userProfile, false)
    .withValue(MemorySetting.agentNotes, false)
    .withValue(MemorySetting.reviewInterval, 0)
    .withValue(MemorySetting.updatesInChat, 'off');

final _unknown = MemorySettings.defaults
    .withValue(MemorySetting.reviewInterval, 15)
    .withValue(MemorySetting.updatesInChat, 'loud');

const _entries = [
  'Prefers metric units and 24-hour times.',
  'Works in Berlin, usually answers in the evening.',
  'Dislikes long introductions; wants the answer first.',
];

MemoryUsage _usage(List<int> sizes, {int? limit, bool cut = false}) =>
    MemoryUsage.of(
      [for (final size in sizes) 'x' * size],
      limit: limit,
      lowerBound: cut,
    );

Widget _view({
  List<MemoryEntry> entries = const [],
  MemoryDetail? detail,
  bool loading = false,
  MemoryFailure? failure,
  String? place,
}) => Scaffold(
  body: MemoryView(
    entries: entries,
    place: place,
    detail: detail,
    selected: detail?.entry,
    loading: loading,
    failure: failure,
    onOpen: (_) {},
    onRefresh: () {},
    onBack: () {},
  ),
);

/// The alert as the app shows it: centred over a dimmed page.
Widget _behindDialog(Widget alert) => Stack(
  children: [
    const Scaffold(body: Center(child: Text('Memory'))),
    const ModalBarrier(dismissible: false, color: Colors.black54),
    Center(child: alert),
  ],
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
