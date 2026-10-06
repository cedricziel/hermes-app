import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:hermes_app/src/windows/conversation_windows_menu.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';

/// The menu bar while conversation windows are open: their list in the
/// Window menu, and the window commands going to the key one.
void main() {
  late MacCommandRegistry registry;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late List<String> mainCommands;

  Future<void> pump(WidgetTester tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    registry = MacCommandRegistry();
    host = FakeConversationWindowHost();
    mainCommands = [];
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      connection: () => (baseUrl: 'https://hermes.test', authRequired: true),
      headers: ({rejected}) async => const {},
    );
    addTearDown(() {
      windows.dispose();
      host.dispose();
      registry.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<ConversationWindows?>.value(
        value: windows,
        child: MacCommandScope.root(
          registry: registry,
          child: MacCommandScope(
            commands: {
              MacCommand.closeWindow: MacCommandHandler(
                () => mainCommands.add('close'),
              ),
              MacCommand.pinThread: MacCommandHandler(
                () => mainCommands.add('pin'),
              ),
              MacCommand.showMainWindow: MacCommandHandler(
                () => mainCommands.add('main'),
              ),
            },
            child: const ConversationWindowsMenu(child: SizedBox()),
          ),
        ),
      ),
    );
  }

  Future<void> focus(WidgetTester tester, String id) async {
    await host.call('focused', {'window_id': id, 'focused': true});
    await tester.pump();
  }

  testWidgets('lists the open windows in the Window menu', (tester) async {
    await pump(tester);
    await windows.open('s1', profile: 'work', title: 'Trip plan');
    await windows.open('s2', profile: null, title: 'Groceries');
    await tester.pump();

    expect(registry.windows.map((w) => w.title), ['Trip plan', 'Groceries']);

    registry.windows.last.onSelect();
    expect(host.focused, ['w1']);
  });

  testWidgets('window commands act on the main window while it is key', (
    tester,
  ) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    await tester.pump();

    registry.invoke(MacCommand.closeWindow);
    registry.invoke(MacCommand.pinThread);

    expect(mainCommands, ['close', 'pin']);
    expect(host.commands, isEmpty);
  });

  testWidgets('window commands go to the key conversation window', (
    tester,
  ) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');

    for (final command in [
      MacCommand.pinThread,
      MacCommand.renameThread,
      MacCommand.copyTranscript,
      MacCommand.archiveThread,
      MacCommand.deleteThread,
      MacCommand.closeWindow,
    ]) {
      expect(registry.invoke(command), isTrue, reason: '$command');
    }
    registry.invoke(MacCommand.showMainWindow);
    await tester.pump();

    expect(host.commands.map((c) => c.$2), [
      'pin',
      'rename',
      'copyTranscript',
      'archive',
      'delete',
    ]);
    expect(host.closedNatively, ['w0']);
    expect(host.mainShown, 1);
    expect(mainCommands, isEmpty);
  });

  testWidgets('Pin reads Unpin for a pinned chat in the key window', (
    tester,
  ) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');
    expect(registry.handlerFor(MacCommand.pinThread)!.title, 'Pin');

    await host.call('title', {'window_id': 'w0', 'title': 'A', 'pinned': true});
    await tester.pump();

    expect(registry.handlerFor(MacCommand.pinThread)!.title, 'Unpin');
  });

  testWidgets('Open in New Window is off while a conversation window is key', (
    tester,
  ) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');

    expect(registry.handlerFor(MacCommand.openInNewWindow)?.enabled, isFalse);
  });
}
