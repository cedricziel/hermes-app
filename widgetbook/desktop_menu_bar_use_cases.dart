import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/navigation/desktop_menu_models.dart';
import 'package:hermes_app/src/navigation/widgets/desktop_menu_bar.dart';
import 'package:hermes_app/src/navigation/widgets/desktop_menu_bar_section.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'platform_theme.dart';

void _nothing() {}

/// The menus of a Windows and Linux window as [desktopMenus] builds them from
/// the shared layout, over a registry that offers [commands].
List<DesktopMenuModel> _menus(
  BuildContext context,
  Map<MacCommand, MacCommandHandler> commands,
) {
  final registry = MacCommandRegistry()..register(commands);
  final menus = desktopMenus(registry, context.l10n);
  registry.dispose();
  return menus;
}

const _app = {
  MacCommand.about: MacCommandHandler(_nothing),
  MacCommand.help: MacCommandHandler(_nothing),
  MacCommand.keyboardShortcuts: MacCommandHandler(_nothing),
  MacCommand.settings: MacCommandHandler(_nothing),
  MacCommand.signOut: MacCommandHandler(_nothing),
  MacCommand.connectionDetails: MacCommandHandler(_nothing),
};

/// What a chat on screen adds.
const _chat = {
  MacCommand.newChat: MacCommandHandler(_nothing),
  MacCommand.reload: MacCommandHandler(_nothing),
  MacCommand.back: MacCommandHandler(_nothing),
  MacCommand.forward: MacCommandHandler(_nothing),
  MacCommand.toggleSidebar: MacCommandHandler(_nothing),
  MacCommand.showFiles: MacCommandHandler(_nothing),
  MacCommand.find: MacCommandHandler(_nothing),
  MacCommand.pinThread: MacCommandHandler(_nothing),
  MacCommand.renameThread: MacCommandHandler(_nothing),
  MacCommand.copyTranscript: MacCommandHandler(_nothing),
  MacCommand.exportThread: MacCommandHandler(_nothing),
  MacCommand.archiveThread: MacCommandHandler(_nothing),
};

Widget _window(
  BuildContext context,
  TargetPlatform platform,
  Map<MacCommand, MacCommandHandler> commands, {
  int? open,
}) => Theme(
  data: platformTheme(context, platform),
  child: Builder(
    builder: (context) => Scaffold(
      // `fill`, not `frame`: the window's Expanded needs a bounded height,
      // which frame's scroll view would take away.
      body: fill(
        width: 960,
        Column(
          children: [
            DesktopMenuBar(
              menus: _menus(context, commands),
              initiallyOpen: open,
            ),
            const Expanded(child: Center(child: Text('Chat'))),
          ],
        ),
      ),
    ),
  ),
);

/// The optional menu bar of Windows and Linux. Its entries come from the same
/// layout as the Mac's menus, with the Windows and Linux chords.
WidgetbookNode desktopMenuBarNode() => WidgetbookFolder(
  name: 'Desktop menu bar',
  children: [
    WidgetbookComponent(
      name: 'DesktopMenuBar',
      useCases: [
        WidgetbookUseCase(
          name: 'Closed (Windows)',
          builder: (context) =>
              _window(context, TargetPlatform.windows, {..._app, ..._chat}),
        ),
        WidgetbookUseCase(
          name: 'Closed (Linux)',
          builder: (context) =>
              _window(context, TargetPlatform.linux, {..._app, ..._chat}),
        ),
        for (final (index, name) in ['File', 'View', 'Chat', 'Help'].indexed)
          WidgetbookUseCase(
            name: '$name open',
            builder: (context) => _window(context, TargetPlatform.windows, {
              ..._app,
              ..._chat,
            }, open: index),
          ),
        WidgetbookUseCase(
          name: 'Bar alone (framed)',
          builder: (context) => Theme(
            data: platformTheme(context, TargetPlatform.linux),
            child: Builder(
              builder: (context) => frame(
                maxWidth: 960,
                DesktopMenuBar(menus: _menus(context, {..._app, ..._chat})),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Chat open, no chat on screen (disabled items)',
          builder: (context) =>
              _window(context, TargetPlatform.linux, _app, open: 2),
        ),
        WidgetbookUseCase(
          name: 'View open, nothing offered (all disabled)',
          builder: (context) =>
              _window(context, TargetPlatform.linux, const {}, open: 1),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'DesktopMenuBarSection',
      useCases: [
        for (final on in [false, true])
          WidgetbookUseCase(
            name: on ? 'On' : 'Off (default)',
            builder: (_) => frame(
              GroupedDialog(
                title: 'Settings',
                children: [DesktopMenuBarSection(value: on, onChanged: (_) {})],
              ),
            ),
          ),
      ],
    ),
  ],
);
