import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../chat/widgets/thread_actions_menu.dart';
import '../macos/mac_commands.dart';
import 'conversation_windows.dart';

/// Hooks the open conversation windows into the Mac menu bar: lists them in
/// the Window menu, and while one of them is key sends the window and chat
/// commands (⌘W, ⇧⌘P, ⌘0, Rename, Archive, …) to it instead of the main
/// window. The menu bar belongs to the main engine, so this runs there.
class ConversationWindowsMenu extends StatelessWidget {
  const ConversationWindowsMenu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    ConversationWindows? windows;
    try {
      windows = context.watch<ConversationWindows?>();
    } on ProviderNotFoundException {
      windows = null;
    }
    if (windows == null) return child;
    MacCommandScope.registryOf(context)?.windows = [
      for (final window in windows.windows)
        MacWindowEntry(
          id: window.windowId,
          title: window.args.title,
          onSelect: () => windows!.focus(window.windowId),
        ),
    ];
    final key = windows.keyWindow;
    MacCommandHandler run(ThreadAction action, {String? title}) =>
        MacCommandHandler(() => windows!.runInKeyWindow(action), title: title);
    return MacCommandScope(
      priority: 1,
      commands: key == null
          ? const {}
          : {
              MacCommand.closeWindow: MacCommandHandler(windows.closeKeyWindow),
              MacCommand.showMainWindow: MacCommandHandler(
                windows.showMainWindow,
              ),
              MacCommand.openInNewWindow: const MacCommandHandler(null),
              // A settings page in the main window stays put.
              MacCommand.back: const MacCommandHandler(null),
              MacCommand.pinThread: run(
                ThreadAction.pin,
                title: key.pinned ? 'Unpin' : 'Pin',
              ),
              MacCommand.renameThread: run(ThreadAction.rename),
              MacCommand.copyTranscript: run(ThreadAction.copyTranscript),
              MacCommand.archiveThread: run(ThreadAction.archive),
              MacCommand.deleteThread: run(ThreadAction.delete),
            },
      child: child,
    );
  }
}
