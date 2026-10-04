import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/widgets/mac_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/macos/mac_source_list.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:widgetbook/widgetbook.dart';

import 'catalog_auth.dart';
import 'fixtures.dart';
import 'frame.dart';
import 'host.dart';

/// [child] with the Mac look, whatever the catalog's viewport.
Widget mac(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: child,
  ),
);

WidgetbookUseCase _case(String name, Widget Function() build) =>
    WidgetbookUseCase(name: name, builder: (_) => mac(build()));

Widget _row({required bool selected, String title = 'Plan the release'}) =>
    MacThreadRow(
      title: title,
      selected: selected,
      onTap: () {},
      onArchive: () {},
      menuItems: (_) => macThreadMenuItems(pinned: false, manageable: true),
      onAction: (_) {},
    );

/// A menu shown as it opens over a row, for the catalog to look at.
class _OpenMenu extends StatefulWidget {
  const _OpenMenu({required this.items});

  final List<PopupMenuEntry<ThreadAction>> items;

  @override
  State<_OpenMenu> createState() => _OpenMenuState();
}

class _OpenMenuState extends State<_OpenMenu> {
  final _menu = AdaptiveMenuController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _menu.open();
    });
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: AdaptivePopupMenuButton<ThreadAction>(
      controller: _menu,
      icon: const AppIcon(AppIcons.more),
      itemBuilder: (_) => widget.items,
    ),
  );
}

WidgetbookNode macSidebarNode() => WidgetbookFolder(
  name: 'macOS sidebar',
  children: [
    WidgetbookComponent(
      name: 'MacSourceListRow',
      useCases: [
        _case(
          'Destinations',
          () => frame(
            Column(
              children: [
                MacSourceListRow(
                  icon: AppIcons.chat,
                  label: 'Chat',
                  selected: true,
                  onTap: () {},
                ),
                MacSourceListRow(
                  icon: AppIcons.kanban,
                  label: 'Kanban',
                  caption: 'All profiles',
                  onTap: () {},
                ),
                MacSourceListRow(
                  icon: AppIcons.scheduleOutlined,
                  label: 'Schedules',
                  onTap: () {},
                ),
              ],
            ),
            maxWidth: 260,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'MacSidebarSectionHeader',
      useCases: [
        for (final (name, collapsed) in [('Open', false), ('Folded', true)])
          _case(
            name,
            () => frame(
              MacSidebarSectionHeader(
                label: 'Today',
                collapsed: collapsed,
                onToggle: () {},
              ),
              maxWidth: 260,
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'MacThreadRow',
      useCases: [
        _case('Plain', () => frame(_row(selected: false), maxWidth: 260)),
        _case('Selected', () => frame(_row(selected: true), maxWidth: 260)),
        _case(
          'Long title',
          () => frame(
            _row(
              selected: false,
              title: 'Compare the backup providers for the photo library',
            ),
            maxWidth: 260,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Thread menu',
      useCases: [
        _case(
          'Server thread',
          () => _OpenMenu(
            items: macThreadMenuItems(pinned: false, manageable: true),
          ),
        ),
        _case(
          'Pinned, with a new window',
          () => _OpenMenu(
            items: macThreadMenuItems(
              pinned: true,
              manageable: true,
              canOpenInNewWindow: true,
            ),
          ),
        ),
        _case(
          'Local draft',
          () => _OpenMenu(
            items: macThreadMenuItems(pinned: false, manageable: false),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ThreadSidebar (macOS)',
      useCases: [
        WidgetbookUseCase(
          name: 'Sections',
          builder: (_) => Hosted<CatalogAuth>(
            create: () => CatalogAuth(gated: true),
            dispose: (auth) => auth.dispose(),
            builder: (_, auth) => withAppProviders(
              auth,
              mac(
                fill(
                  ThreadSidebar(
                    threads: macThreads,
                    selectedId: 'thread-2',
                    onSelect: (_) {},
                    onNewThread: () {},
                  ),
                  width: 280,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ],
);
