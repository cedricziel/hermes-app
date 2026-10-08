import 'package:flutter/material.dart';
import 'package:hermes_app/src/platform_hint/platform_hint_repository.dart';
import 'package:hermes_app/src/platform_hint/widgets/platform_hint_prompt.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

Widget _prompt({
  List<String> profiles = const ['default'],
  bool update = false,
  bool busy = false,
  List<String> failed = const [],
}) => frame(
  Card(
    margin: EdgeInsets.zero,
    child: PlatformHintPrompt(
      profiles: profiles,
      text: appPlatformHint,
      update: update,
      busy: busy,
      failed: failed,
      onAdd: () {},
      onLater: () {},
      onNever: () {},
    ),
  ),
  maxWidth: 520,
);

WidgetbookNode platformHintNode() => WidgetbookComponent(
  name: 'PlatformHintPrompt',
  useCases: [
    WidgetbookUseCase(name: 'One profile', builder: (_) => _prompt()),
    WidgetbookUseCase(
      name: 'Several profiles',
      builder: (_) => _prompt(profiles: const ['default', 'work', 'research']),
    ),
    WidgetbookUseCase(
      name: 'Update',
      builder: (_) =>
          _prompt(profiles: const ['default', 'work'], update: true),
    ),
    WidgetbookUseCase(
      name: 'Adding',
      builder: (_) => _prompt(profiles: const ['default', 'work'], busy: true),
    ),
    WidgetbookUseCase(
      name: 'One profile failed',
      builder: (_) => _prompt(
        profiles: const ['default', 'work', 'research'],
        failed: const ['work'],
      ),
    ),
    WidgetbookUseCase(
      name: 'All failed',
      builder: (_) => _prompt(failed: const ['default']),
    ),
  ],
);
