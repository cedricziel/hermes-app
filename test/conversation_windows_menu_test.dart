import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show MaterialApp, Material, TextField;
import 'package:hermes_app/src/macos/edit_menu_state.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:hermes_app/src/windows/conversation_windows_menu.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';
import 'support/test_localizations.dart';

/// The menu bar while conversation windows are open: their list in the
/// Window menu, and the window commands going to the key one.
void main() {
  late MacCommandRegistry registry;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late List<String> mainCommands;

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    registry = MacCommandRegistry();
    host = FakeConversationWindowHost();
    mainCommands = [];
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      ownerKey: () => 'test-owner',
      connection: () => (baseUrl: 'https://hermes.test', authRequired: true),
      headers: ({rejected}) async => const {},
    );
    addTearDown(() {
      windows.dispose();
      host.dispose();
      registry.dispose();
    });
    Widget app(Widget child) => locale == null
        ? child
        : Localizations(
            locale: locale,
            delegates: kTestLocalizationsDelegates,
            child: child,
          );
    await tester.pumpWidget(
      app(
        ChangeNotifierProvider<ConversationWindows?>.value(
          value: windows,
          child: MacCommandScope.root(
            registry: registry,
            child: MacCommandScope(
              priority: 1,
              commands: {
                MacCommand.back: MacCommandHandler(
                  () => mainCommands.add('back'),
                ),
                MacCommand.forward: MacCommandHandler(
                  () => mainCommands.add('forward'),
                ),
                MacCommand.closeWindow: MacCommandHandler(
                  () => mainCommands.add('close'),
                ),
                MacCommand.pinThread: MacCommandHandler(
                  () => mainCommands.add('pin'),
                ),
                MacCommand.showMainWindow: MacCommandHandler(
                  () => mainCommands.add('main'),
                ),
                MacCommand.openParentChat: MacCommandHandler(
                  () => mainCommands.add('parent'),
                ),
              },
              child: const ConversationWindowsMenu(child: SizedBox()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
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
      MacCommand.toggleInspector,
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
      'inspector',
    ]);
    expect(host.closedNatively, ['w0']);
    expect(host.mainShown, 1);
    expect(mainCommands, isEmpty);
  });

  testWidgets('Show Files is disabled while a conversation window is key', (
    tester,
  ) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');

    expect(registry.handlerFor(MacCommand.showFiles)?.enabled, isFalse);
    expect(registry.invoke(MacCommand.showFiles), isFalse);
    expect(host.commands, isEmpty);
  });

  testWidgets('Reload, Enclosing Folder and the change steps are disabled '
      'while a conversation window is key', (tester) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');

    for (final command in [
      MacCommand.reload,
      MacCommand.enclosingFolder,
      MacCommand.previousChange,
      MacCommand.nextChange,
    ]) {
      expect(
        registry.handlerFor(command)?.enabled,
        isFalse,
        reason: '$command',
      );
      expect(registry.invoke(command), isFalse);
    }
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

  testWidgets('the key window\'s Pin and Show Inspector titles are German', (
    tester,
  ) async {
    await pump(tester, locale: const Locale('de'));
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');
    expect(registry.handlerFor(MacCommand.pinThread)!.title, 'Anheften');
    expect(
      registry.handlerFor(MacCommand.toggleInspector)!.title,
      'Informationen einblenden',
    );

    await host.call('title', {'window_id': 'w0', 'title': 'A', 'pinned': true});
    await tester.pump();

    expect(registry.handlerFor(MacCommand.pinThread)!.title, 'Lösen');
  });

  testWidgets('Open in New Window is off while a conversation window is key', (
    tester,
  ) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');

    expect(registry.handlerFor(MacCommand.openInNewWindow)?.enabled, isFalse);
  });

  testWidgets('Open Parent Chat is off while a conversation window is key', (
    tester,
  ) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    expect(registry.handlerFor(MacCommand.openParentChat)?.enabled, isTrue);

    await focus(tester, 'w0');

    expect(registry.handlerFor(MacCommand.openParentChat)?.enabled, isFalse);
    expect(registry.invoke(MacCommand.openParentChat), isFalse);
    expect(mainCommands, isEmpty);
  });

  testWidgets('Compress Conversation… is off while a conversation window is '
      'key', (tester) async {
    await pump(tester);
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');

    expect(registry.handlerFor(MacCommand.compress)?.enabled, isFalse);
    expect(registry.invoke(MacCommand.compress), isFalse);
    expect(host.commands, isEmpty);
  });

  testWidgets('key conversation disables root Back and Forward', (
    tester,
  ) async {
    await pump(tester);
    expect(registry.invoke(MacCommand.forward), isTrue);
    mainCommands.clear();
    await windows.open('s1', profile: null, title: 'A');
    await focus(tester, 'w0');
    expect(registry.invoke(MacCommand.back), isFalse);
    expect(registry.invoke(MacCommand.forward), isFalse);
    expect(mainCommands, isEmpty);
  });

  testWidgets('the Edit items go off while a conversation window is key', (
    tester,
  ) async {
    final edit = EditMenuState();
    addTearDown(edit.dispose);
    await pump(tester);
    await tester.pumpWidget(
      InheritedProvider<EditMenuState>.value(
        value: edit,
        child: ChangeNotifierProvider<ConversationWindows?>.value(
          value: windows,
          child: MacCommandScope.root(
            registry: registry,
            child: const MaterialApp(
              home: Material(
                child: ConversationWindowsMenu(
                  child: TextField(autofocus: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(edit.value.selectAll, isTrue);

    await windows.open('s1', profile: null, title: 'A');
    await tester.pump();
    await focus(tester, 'w0');
    await tester.pump();
    expect(edit.value, EditAvailability.none);

    await host.call('focused', {'window_id': 'w0', 'focused': false});
    await tester.pump();
    await tester.pump();
    expect(edit.value.selectAll, isTrue);
  });

  testWidgets('the Edit items go off while the quick panel is shown', (
    tester,
  ) async {
    final edit = EditMenuState();
    addTearDown(edit.dispose);
    await pump(tester);
    await tester.pumpWidget(
      InheritedProvider<EditMenuState>.value(
        value: edit,
        child: ChangeNotifierProvider<ConversationWindows?>.value(
          value: windows,
          child: MacCommandScope.root(
            registry: registry,
            child: const MaterialApp(
              home: Material(
                child: ConversationWindowsMenu(
                  child: TextField(autofocus: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(edit.value.selectAll, isTrue);

    await windows.togglePanel();
    await host.call('panel', {'window_id': 'p0', 'event': 'shown'});
    await tester.pump();
    await tester.pump();
    expect(edit.value, EditAvailability.none);

    await host.call('panel', {
      'window_id': 'p0',
      'event': 'hidden',
      'reason': 'focus_lost',
    });
    await tester.pump();
    await tester.pump();
    expect(edit.value.selectAll, isTrue);
  });

  testWidgets('signing out while the quick panel is shown turns the Edit '
      'items back on', (tester) async {
    final edit = EditMenuState();
    addTearDown(edit.dispose);
    await pump(tester);
    await tester.pumpWidget(
      InheritedProvider<EditMenuState>.value(
        value: edit,
        child: ChangeNotifierProvider<ConversationWindows?>.value(
          value: windows,
          child: MacCommandScope.root(
            registry: registry,
            child: const MaterialApp(
              home: Material(
                child: ConversationWindowsMenu(
                  child: TextField(autofocus: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await windows.togglePanel();
    await host.call('panel', {'window_id': 'p0', 'event': 'shown'});
    await tester.pump();
    await tester.pump();
    expect(edit.value, EditAvailability.none);

    await windows.closeAll();
    await tester.pump();
    await tester.pump();
    expect(edit.value.selectAll, isTrue);
  });

  testWidgets('the quick panel going away while shown turns the '
      'Edit items back on', (tester) async {
    final edit = EditMenuState();
    addTearDown(edit.dispose);
    await pump(tester);
    await tester.pumpWidget(
      InheritedProvider<EditMenuState>.value(
        value: edit,
        child: ChangeNotifierProvider<ConversationWindows?>.value(
          value: windows,
          child: MacCommandScope.root(
            registry: registry,
            child: const MaterialApp(
              home: Material(
                child: ConversationWindowsMenu(
                  child: TextField(autofocus: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await windows.togglePanel();
    await host.call('panel', {'window_id': 'p0', 'event': 'shown'});
    await tester.pump();
    await tester.pump();
    expect(edit.value, EditAvailability.none);

    host.closed('p0');
    await tester.pump();
    await tester.pump();
    expect(edit.value.selectAll, isTrue);
  });
}
