import 'package:flutter/material.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode memoryNode() => WidgetbookComponent(
  name: 'Memory',
  useCases: [
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
