import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/macos/mac_menu_bar.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';

/// Answers the menu channel as the macOS engine does and keeps the last menu
/// hierarchy the app set.
class FakeMenuChannel {
  FakeMenuChannel(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.menu,
      (call) async {
        if (call.method == 'Menu.setMenus') {
          final windows = call.arguments as Map<Object?, Object?>;
          menus = (windows['0']! as List).cast<Map<Object?, Object?>>();
          setCount++;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.menu,
        null,
      ),
    );
  }

  final WidgetTester tester;
  List<Map<Object?, Object?>>? menus;
  int setCount = 0;

  List<Map<Object?, Object?>> _children(Map<Object?, Object?> menu) =>
      (menu['children']! as List).cast<Map<Object?, Object?>>();

  Map<Object?, Object?> menu(String label) =>
      menus!.firstWhere((m) => m['label'] == label);

  /// The labels in [label]'s menu, with '-' for a separator and the
  /// platform-provided items by their type index as `#n`.
  List<String> labels(String label) => [
    for (final item in _children(menu(label)))
      if (item['isDivider'] == true)
        '-'
      else if (item['platformProvidedMenu'] != null)
        '#${item['platformProvidedMenu']}'
      else
        item['label']! as String,
  ];

  Map<Object?, Object?> item(String menuLabel, String label) =>
      _children(menu(menuLabel)).firstWhere((i) => i['label'] == label);

  bool enabled(String menuLabel, String label) =>
      item(menuLabel, label)['enabled']! as bool;

  /// Picks an item as a click or its key equivalent would.
  Future<void> select(String menuLabel, String label) async {
    final id = item(menuLabel, label)['id'];
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.menu.name,
      SystemChannels.menu.codec.encodeMethodCall(
        MethodCall('Menu.selectedCallback', id),
      ),
      (_) {},
    );
    await tester.pump();
  }
}

void main() {
  setUp(() => MacWindow.enabled = true);
  tearDown(() => MacWindow.enabled = false);

  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  Future<FakeMenuChannel> pump(WidgetTester tester, Widget home) async {
    final channel = FakeMenuChannel(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) =>
            MacMenuBar(navigatorKey: navigatorKey, child: child!),
        home: home,
      ),
    );
    await tester.pump();
    return channel;
  }

  testWidgets('sets the Mac menus in order', (tester) async {
    final channel = await pump(tester, const SizedBox());
    expect(channel.menus!.map((m) => m['label']), [
      'Hermes',
      'File',
      'Edit',
      'View',
      'Chat',
      'Window',
      'Help',
    ]);
    expect(channel.labels('Hermes'), [
      'About Hermes',
      '-',
      'Settings…',
      '-',
      'Connection Details',
      'Sign Out…',
      '-',
      '#${PlatformProvidedMenuItemType.servicesSubmenu.index}',
      '-',
      '#${PlatformProvidedMenuItemType.hide.index}',
      '#${PlatformProvidedMenuItemType.hideOtherApplications.index}',
      '#${PlatformProvidedMenuItemType.showAllApplications.index}',
      '-',
      '#${PlatformProvidedMenuItemType.quit.index}',
    ]);
    expect(channel.labels('File'), [
      'New Chat',
      'Open in New Window',
      '-',
      'Close Window',
    ]);
    expect(channel.labels('Edit'), [
      'Undo',
      'Redo',
      '-',
      'Cut',
      'Copy',
      'Paste',
      'Select All',
    ]);
    expect(channel.labels('Chat'), [
      'Find…',
      '-',
      'Pin',
      'Rename…',
      'Copy Transcript',
      '-',
      'Archive',
      'Delete…',
    ]);
    expect(channel.labels('Help'), ['Hermes Help']);
    expect(channel.item('File', 'New Chat')['shortcutTrigger'], isNotNull);
  }, variant: mac);

  testWidgets('commands without a handler are disabled', (tester) async {
    final channel = await pump(tester, const SizedBox());
    expect(channel.enabled('File', 'New Chat'), isFalse);
    expect(channel.enabled('Chat', 'Delete…'), isFalse);
    expect(channel.enabled('Hermes', 'About Hermes'), isTrue);
    expect(channel.enabled('File', 'Close Window'), isTrue);
  }, variant: mac);

  testWidgets('a registered handler enables its item and runs once', (
    tester,
  ) async {
    var created = 0;
    final channel = await pump(
      tester,
      MacCommandScope(
        commands: {
          MacCommand.newChat: MacCommandHandler(() => created++),
          MacCommand.pinThread: MacCommandHandler(() {}, title: 'Unpin'),
        },
        child: const SizedBox(),
      ),
    );
    expect(channel.enabled('File', 'New Chat'), isTrue);
    expect(channel.labels('Chat'), contains('Unpin'));
    await channel.select('File', 'New Chat');
    expect(created, 1);
  }, variant: mac);

  testWidgets('View > Back leaves a settings page', (tester) async {
    final channel = await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const SettingsScaffold(title: 'Plugins', body: Text('body')),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
    expect(channel.enabled('View', 'Back'), isFalse);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(channel.enabled('View', 'Back'), isTrue);
    expect(channel.item('View', 'Back')['shortcutTrigger'], isNotNull);

    await channel.select('View', 'Back');
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
    expect(channel.enabled('View', 'Back'), isFalse);
  }, variant: mac);

  testWidgets('View > Back waits while a dialog covers the settings page', (
    tester,
  ) async {
    final channel = await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const SettingsScaffold(title: 'Plugins', body: Text('body')),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: tester.element(find.text('body')),
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();
    expect(channel.enabled('View', 'Back'), isFalse);

    Navigator.of(tester.element(find.text('dialog'))).pop();
    await tester.pumpAndSettle();
    expect(channel.enabled('View', 'Back'), isTrue);
    expect(find.text('body'), findsOneWidget);
  }, variant: mac);

  testWidgets('sets no menu bar off macOS', (tester) async {
    final channel = await pump(tester, const SizedBox());
    expect(find.byType(PlatformMenuBar), findsNothing);
    expect(channel.menus, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('a rebuild with new callbacks does not reset the menus', (
    tester,
  ) async {
    late StateSetter rebuild;
    var calls = <String>[];
    final channel = await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          final round = calls.length;
          return MacCommandScope(
            commands: {
              MacCommand.find: MacCommandHandler(() => calls.add('$round')),
            },
            child: const SizedBox(),
          );
        },
      ),
    );
    final sets = channel.setCount;
    calls = ['x'];
    rebuild(() {});
    await tester.pump();
    expect(channel.setCount, sets);
    await channel.select('Chat', 'Find…');
    expect(calls.last, '1');
  }, variant: mac);

  group('in a text field', () {
    late TextEditingController text;
    late FocusNode focus;

    setUp(() {
      text = TextEditingController(text: 'first line second');
      focus = FocusNode();
    });

    tearDown(() {
      text.dispose();
      focus.dispose();
    });

    Future<FakeMenuChannel> pumpField(
      WidgetTester tester, {
      VoidCallback? onDelete,
    }) async {
      final channel = await pump(
        tester,
        MacCommandScope(
          commands: {MacCommand.deleteThread: MacCommandHandler(onDelete)},
          child: Scaffold(
            body: TextField(controller: text, focusNode: focus),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      return channel;
    }

    testWidgets('Delete… deletes to the line start, not the chat', (
      tester,
    ) async {
      var deleted = 0;
      final channel = await pumpField(tester, onDelete: () => deleted++);
      text.selection = const TextSelection.collapsed(offset: 10);
      await tester.pump();
      await channel.select('Chat', 'Delete…');
      expect(deleted, 0);
      expect(text.text, ' second');
    }, variant: mac);

    testWidgets('Delete… deletes the chat once focus leaves the field', (
      tester,
    ) async {
      var deleted = 0;
      final channel = await pumpField(tester, onDelete: () => deleted++);
      focus.unfocus();
      await tester.pump();
      await channel.select('Chat', 'Delete…');
      expect(deleted, 1);
      expect(text.text, 'first line second');
    }, variant: mac);

    testWidgets('Select All, Copy, Cut and Paste act on the field', (
      tester,
    ) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') {
            return {'text': clipboard};
          }
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboard != null};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final channel = await pumpField(tester);
      await channel.select('Edit', 'Select All');
      expect(text.selection, isNot(const TextSelection.collapsed(offset: 0)));
      expect(text.selection.textInside(text.text), 'first line second');
      await channel.select('Edit', 'Copy');
      expect(clipboard, 'first line second');
      await channel.select('Edit', 'Cut');
      await tester.pumpAndSettle();
      expect(text.text, isEmpty);
      await channel.select('Edit', 'Paste');
      await tester.pumpAndSettle();
      expect(text.text, 'first line second');
    }, variant: mac);
  });
}
