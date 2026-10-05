import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/thread_list_preferences.dart';
import 'package:hermes_app/src/chat/widgets/thread_grouping_controls.dart';
import 'package:hermes_app/src/macos/mac_source_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode threadGroupingNode() => WidgetbookComponent(
  name: 'Chat grouping',
  useCases: [
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS])
      for (final grouping in ThreadGrouping.values)
        WidgetbookUseCase(
          name: '${platform.name} ${grouping.name}',
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(platform: platform),
            child: frame(
              ThreadGroupingMenu(grouping: grouping, onChanged: (_) {}),
            ),
          ),
        ),
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS])
      WidgetbookUseCase(
        name: '${platform.name} Inline menu',
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(platform: platform),
          child: frame(
            ThreadSectionHeading(
              label: 'Pinned',
              grouping: ThreadGrouping.folder,
              onToggle: () {},
              onGroupingChanged: (_) {},
            ),
            maxWidth: 240,
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'Empty chat list heading',
      builder: (_) => frame(
        ThreadSectionHeading(
          label: 'Chats',
          grouping: ThreadGrouping.folder,
          onGroupingChanged: (_) {},
        ),
        maxWidth: 240,
      ),
    ),
    for (final collapsed in [false, true])
      WidgetbookUseCase(
        name: 'iOS ${collapsed ? 'Collapsed' : 'Expanded'} folder',
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: frame(
            ThreadSectionHeader(
              label: 'hermes-app',
              count: 12,
              collapsed: collapsed,
              onToggle: () {},
            ),
            maxWidth: 280,
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'Long folder path',
      builder: (_) => frame(
        ThreadSectionHeader(
          label: '/workspace/personal/very-long-folder-name/hermes-app',
          count: 123,
          collapsed: false,
          onToggle: () {},
        ),
        maxWidth: 240,
      ),
    ),
    WidgetbookUseCase(
      name: 'Mac folder count',
      builder: (_) => frame(
        MacSidebarSectionHeader(
          label: 'hermes-app',
          count: 12,
          collapsed: false,
          onToggle: () {},
        ),
        maxWidth: 240,
      ),
    ),
  ],
);
