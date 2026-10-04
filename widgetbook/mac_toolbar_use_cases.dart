import 'package:flutter/material.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:hermes_app/src/macos/mac_toolbar.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:widgetbook/widgetbook.dart';

import 'host.dart';

/// The toolbar of a Mac window, shown on macOS in either viewport.
Widget _mac(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: Align(alignment: Alignment.topCenter, child: child),
  ),
);

List<Widget> _actions({bool inspector = false}) => [
  MacToolbarButton(
    label: 'New Task',
    shortcut: '⌘N',
    icon: AppIcons.add,
    onPressed: () {},
  ),
  MacToolbarButton(
    label: 'Filter by profile',
    icon: AppIcons.filter,
    onPressed: () {},
  ),
  const MacToolbarSeparator(),
  MacToolbarButton(
    label: 'Inspector',
    shortcut: '⌥⌘I',
    icon: AppIcons.inspector,
    selected: inspector,
    onPressed: () {},
  ),
  const MacToolbarButton(
    label: 'Unavailable',
    icon: AppIcons.more,
    onPressed: null,
  ),
];

WidgetbookUseCase _use(String name, Widget child) =>
    WidgetbookUseCase(name: name, builder: (_) => _mac(child));

WidgetbookNode macToolbarNode() => WidgetbookFolder(
  name: 'macOS',
  children: [
    WidgetbookComponent(
      name: 'MacToolbar',
      useCases: [
        _use('Title only', const MacToolbar(title: 'Kanban')),
        _use(
          'Title, subtitle and actions',
          MacToolbar(
            title: 'Kanban',
            subtitle: 'Default · all profiles · 12 tasks',
            actions: _actions(),
          ),
        ),
        _use(
          'Toggle on, with a rule',
          MacToolbar(
            title: 'Kanban',
            subtitle: 'Default · all profiles · 12 tasks',
            border: true,
            actions: _actions(inspector: true),
          ),
        ),
        _use(
          'Sidebar hidden',
          Hosted<MacSidebarController>(
            create: () => MacSidebarController()..toggle(),
            dispose: (sidebar) => sidebar.dispose(),
            builder: (_, sidebar) => MacSidebarScope(
              controller: sidebar,
              child: ShellMenu(
                onOpen: sidebar.toggle,
                leadingInset: kMacTrafficLightsWidth,
                child: MacToolbar(
                  title:
                      'A title long enough to be cut short before the buttons',
                  subtitle: 'Default · all profiles · 12 tasks',
                  actions: _actions(),
                ),
              ),
            ),
          ),
        ),
        _use(
          'Narrow window',
          ShellMenu(
            onOpen: () {},
            child: const MacToolbar(title: 'Kanban', subtitle: '3 tasks'),
          ),
        ),
      ],
    ),
  ],
);
