import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/chat_header.dart';
import 'package:hermes_app/src/chat/widgets/new_chat_fab.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/macos/mac_menu_bar.dart';
import 'package:hermes_app/src/macos/menu_layout.dart';
import 'package:hermes_app/src/navigation/desktop_command_shortcuts.dart';
import 'package:hermes_app/src/navigation/keyboard_shortcuts.dart';
import 'package:hermes_app/src/navigation/widgets/keyboard_shortcuts_view.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

import '../support/test_localizations.dart';

/// The Windows and Linux column of the F1 command set in
/// `docs/design-briefs/windows-linux-platform-fixes.md`, typed out again here
/// so a change to `menu_layout.dart` has to change the brief's table too.
const _desktopTable = <MacCommand, List<String>>{
  MacCommand.newChat: ['Ctrl+N'],
  MacCommand.find: ['Ctrl+F'],
  MacCommand.settings: ['Ctrl+,'],
  MacCommand.back: ['Alt+Left'],
  MacCommand.forward: ['Alt+Right'],
  MacCommand.reload: ['Ctrl+R', 'F5'],
  MacCommand.toggleSidebar: ['Ctrl+B'],
  MacCommand.showFiles: ['Ctrl+Shift+F'],
  MacCommand.enclosingFolder: ['Alt+Up'],
  MacCommand.previousChange: ['F8'],
  MacCommand.nextChange: ['Shift+F8'],
  MacCommand.pinThread: ['Ctrl+Shift+P'],
  MacCommand.keyboardShortcuts: ['F1'],
};

/// The Mac column of the same table.
const _macTable = <MacCommand, String>{
  MacCommand.newChat: '⌘N',
  MacCommand.find: '⌘F',
  MacCommand.settings: '⌘,',
  MacCommand.back: '⌘[',
  MacCommand.forward: '⌘]',
  MacCommand.reload: '⌘R',
  MacCommand.toggleSidebar: '⌃⌘S',
  MacCommand.showFiles: '⇧⌘F',
  MacCommand.enclosingFolder: '⌘↑',
  MacCommand.previousChange: '⌥↑',
  MacCommand.nextChange: '⌥↓',
  MacCommand.pinThread: '⇧⌘P',
  MacCommand.deleteThread: '⌘⌫',
};

/// A chord of the table as the key events that press it.
({LogicalKeyboardKey key, List<LogicalKeyboardKey> modifiers}) _keys(
  String chord,
) {
  final parts = chord.split('+');
  // "Ctrl+," ends in the comma; a lone "," never splits further.
  final name = parts.last.isEmpty ? '+' : parts.last;
  final key = switch (name) {
    'N' => LogicalKeyboardKey.keyN,
    'F' => LogicalKeyboardKey.keyF,
    'R' => LogicalKeyboardKey.keyR,
    'B' => LogicalKeyboardKey.keyB,
    'P' => LogicalKeyboardKey.keyP,
    ',' => LogicalKeyboardKey.comma,
    'Left' => LogicalKeyboardKey.arrowLeft,
    'Right' => LogicalKeyboardKey.arrowRight,
    'Up' => LogicalKeyboardKey.arrowUp,
    'F1' => LogicalKeyboardKey.f1,
    'F5' => LogicalKeyboardKey.f5,
    'F8' => LogicalKeyboardKey.f8,
    _ => throw ArgumentError(chord),
  };
  return (
    key: key,
    modifiers: [
      for (final modifier in parts.take(parts.length - 1))
        switch (modifier) {
          'Ctrl' => LogicalKeyboardKey.controlLeft,
          'Alt' => LogicalKeyboardKey.altLeft,
          'Shift' => LogicalKeyboardKey.shiftLeft,
          _ => throw ArgumentError(chord),
        },
    ],
  );
}

Future<void> _press(WidgetTester tester, String chord) async {
  final (:key, :modifiers) = _keys(chord);
  for (final modifier in modifiers) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyEvent(key);
  for (final modifier in modifiers.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pump();
}

Future<void> _pressMeta(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

/// Every command of the table with a handler that records the call.
Map<MacCommand, MacCommandHandler> _handlers(List<MacCommand> fired) => {
  for (final command in MacCommand.values)
    command: MacCommandHandler(() => fired.add(command)),
};

Widget _app(
  TargetPlatform platform,
  MacCommandRegistry registry, {
  Widget? body,
}) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(platform: platform),
  builder: (context, child) => MacCommandScope.root(
    registry: registry,
    child: DesktopCommandShortcuts(child: child!),
  ),
  home: Scaffold(
    body: body ?? Focus(autofocus: true, child: const SizedBox.expand()),
  ),
);

Future<void> _pressActivator(WidgetTester tester, SingleActivator a) async {
  final modifiers = [
    if (a.control) LogicalKeyboardKey.controlLeft,
    if (a.alt) LogicalKeyboardKey.altLeft,
    if (a.shift) LogicalKeyboardKey.shiftLeft,
    if (a.meta) LogicalKeyboardKey.metaLeft,
  ];
  for (final modifier in modifiers) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyEvent(a.trigger);
  for (final modifier in modifiers.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pump();
}

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

bool _same(SingleActivator a, SingleActivator b) =>
    a.trigger == b.trigger &&
    a.control == b.control &&
    a.alt == b.alt &&
    a.shift == b.shift &&
    a.meta == b.meta;

void main() {
  late MacCommandRegistry registry;
  late List<MacCommand> fired;
  late MacCommandRegistration registration;

  setUp(() {
    registry = MacCommandRegistry();
    fired = [];
    registration = registry.register(_handlers(fired));
  });

  tearDown(() {
    registration.dispose();
    registry.dispose();
  });

  group('the declared chords', () {
    final en = lookupAppLocalizations(const Locale('en'));

    test('the Windows and Linux chords are the F1 table', () {
      final declared = {
        for (final section in menuLayout)
          for (final group in section.groupsOn(MenuPlatform.desktop))
            for (final entry in group)
              if (entry.shortcutsOn(MenuPlatform.desktop).isNotEmpty)
                entry.command: [
                  for (final chord in chordsOf(entry, MenuPlatform.desktop, en))
                    chord.text,
                ],
      };
      expect(declared, _desktopTable);
    });

    test('the Mac chords are the F1 table', () {
      final declared = {
        for (final section in menuLayout)
          for (final group in section.groupsOn(MenuPlatform.mac))
            for (final entry in group)
              if (entry.shortcutsOn(MenuPlatform.mac).isNotEmpty)
                entry.command: chordsOf(
                  entry,
                  MenuPlatform.mac,
                  en,
                ).single.keys.join(),
      };
      expect(declared, {
        ..._macTable,
        MacCommand.openInNewWindow: '⌥⌘O',
        MacCommand.closeWindow: '⌘W',
        MacCommand.toggleInspector: '⌥⌘I',
      });
    });

    test(
      'no Ctrl chord is a text editing key, and none is AltGr or a bracket',
      () {
        for (final chords in _desktopTable.values) {
          for (final chord in chords) {
            final (:key, :modifiers) = _keys(chord);
            final ctrl = modifiers.contains(LogicalKeyboardKey.controlLeft);
            final alt = modifiers.contains(LogicalKeyboardKey.altLeft);
            // Ctrl+Alt is AltGr on many layouts, and brackets need AltGr off
            // a US layout.
            expect(ctrl && alt, isFalse, reason: chord);
            expect(
              [LogicalKeyboardKey.bracketLeft, LogicalKeyboardKey.bracketRight],
              isNot(contains(key)),
              reason: chord,
            );
            // The keys that edit text: letters of the clipboard and undo, and
            // Ctrl with a word or line key.
            if (ctrl) {
              expect(
                [
                  LogicalKeyboardKey.keyA,
                  LogicalKeyboardKey.keyC,
                  LogicalKeyboardKey.keyV,
                  LogicalKeyboardKey.keyX,
                  LogicalKeyboardKey.keyZ,
                  LogicalKeyboardKey.keyY,
                  LogicalKeyboardKey.backspace,
                  LogicalKeyboardKey.delete,
                  LogicalKeyboardKey.arrowLeft,
                  LogicalKeyboardKey.arrowRight,
                  LogicalKeyboardKey.arrowUp,
                  LogicalKeyboardKey.arrowDown,
                ],
                isNot(contains(key)),
                reason: chord,
              );
            }
          }
        }
      },
    );

    test('the key names follow the language', () {
      final de = lookupAppLocalizations(const Locale('de'));
      final chord = ctrlActivator(LogicalKeyboardKey.keyF, shift: true);
      expect(desktopChordOf(chord, en).text, 'Ctrl+Shift+F');
      expect(desktopChordOf(chord, de).text, 'Strg+Umschalt+F');
      expect(
        desktopChordOf(
          const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true),
          de,
        ).text,
        'Alt+Links',
      );
    });

    test('a command with a chord on Windows and Linux is listed once', () {
      final commands = [
        for (final section in menuLayout)
          for (final group in section.groups)
            for (final entry in group) entry.command,
      ];
      expect(commands.toSet().length, commands.length);
      expect(en.navigationKeyboardShortcutsTitle, 'Keyboard shortcuts');
    });
  });

  for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
    group('on $platform', () {
      for (final MapEntry(key: command, value: chords)
          in _desktopTable.entries) {
        for (final chord in chords) {
          testWidgets('$chord runs $command', (tester) async {
            await tester.pumpWidget(_app(platform, registry));
            await _press(tester, chord);
            expect(fired, [command]);
          });
        }
      }

      testWidgets('the Mac chords do nothing', (tester) async {
        await tester.pumpWidget(_app(platform, registry));
        for (final key in [
          LogicalKeyboardKey.keyN,
          LogicalKeyboardKey.keyF,
          LogicalKeyboardKey.keyR,
          LogicalKeyboardKey.comma,
          LogicalKeyboardKey.bracketLeft,
        ]) {
          await _pressMeta(tester, key);
        }
        expect(fired, isEmpty);
      });

      testWidgets('a command with no chord stays unbound', (tester) async {
        await tester.pumpWidget(_app(platform, registry));
        // Delete the chat is ⌘⌫ on a Mac; Ctrl+Backspace deletes a word.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(fired, isEmpty);
      });
    });
  }

  group('on a Mac, an iPad and Android', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.iOS,
      TargetPlatform.android,
    ]) {
      testWidgets('the Ctrl chords do nothing on $platform', (tester) async {
        await tester.pumpWidget(_app(platform, registry));
        for (final chords in _desktopTable.values) {
          for (final chord in chords) {
            await _press(tester, chord);
          }
        }
        expect(fired, isEmpty);
      });
    }
  });

  group('a chord with nothing to do', () {
    testWidgets(
      'goes on to what has focus, and is taken when it has a handler',
      (tester) async {
        registration.dispose();
        final seen = <LogicalKeyboardKey>[];
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: kTestLocalizationsDelegates,
            theme: ThemeData(platform: TargetPlatform.linux),
            builder: (context, child) => MacCommandScope.root(
              registry: registry,
              child: Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent) seen.add(event.logicalKey);
                  return KeyEventResult.ignored;
                },
                child: DesktopCommandShortcuts(child: child!),
              ),
            ),
            home: Scaffold(
              body: Focus(autofocus: true, child: const SizedBox()),
            ),
          ),
        );

        // No screen offers New chat, so the key is not taken.
        await _press(tester, 'Ctrl+N');
        expect(seen, contains(LogicalKeyboardKey.keyN));
        seen.clear();

        // A handler that is off does not take it either.
        registration = registry.register({
          MacCommand.newChat: const MacCommandHandler(null),
        });
        await _press(tester, 'Ctrl+N');
        expect(seen, contains(LogicalKeyboardKey.keyN));
        seen.clear();

        registration.dispose();
        registration = registry.register(_handlers(fired));
        await _press(tester, 'Ctrl+N');
        expect(seen, isNot(contains(LogicalKeyboardKey.keyN)));
        expect(fired, [MacCommand.newChat]);
      },
    );
  });

  group('a text field keeps the keys text editing binds', () {
    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      testWidgets(
        'Alt+Left, Alt+Right and Alt+Up move the caret on $platform',
        (tester) async {
          await _onPlatform(platform, () async {
            final controller = TextEditingController();
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              _app(
                platform,
                registry,
                body: TextField(
                  controller: controller,
                  maxLines: null,
                  autofocus: true,
                ),
              ),
            );
            await tester.pump();
            // Typed in, so the caret is at the end of the second line.
            await tester.enterText(
              find.byType(TextField),
              'one two\nthree four',
            );
            await tester.pump();
            expect(controller.selection.baseOffset, 18);

            // Linux and Windows: line start, line end, start of the text.
            await _press(tester, 'Alt+Left');
            expect(controller.selection.baseOffset, 8, reason: 'start of line');
            await _press(tester, 'Alt+Right');
            expect(controller.selection.baseOffset, 18, reason: 'end of line');
            await _press(tester, 'Alt+Up');
            expect(controller.selection.baseOffset, 0, reason: 'start of text');

            expect(fired, isEmpty);
          });
        },
      );

      testWidgets('every declared chord that text editing binds stays with '
          'the field on $platform', (tester) async {
        await _onPlatform(platform, () async {
          await tester.pumpWidget(
            _app(
              platform,
              registry,
              body: const TextField(maxLines: null, autofocus: true),
            ),
          );
          await tester.pump();

          final declared = [
            for (final section in menuLayout)
              for (final group in section.groupsOn(MenuPlatform.desktop))
                for (final entry in group)
                  ...entry.shortcutsOn(MenuPlatform.desktop),
          ];
          final clashes = [
            for (final chord in declared)
              if (textEditingChords().any((text) => _same(text, chord))) chord,
          ];
          // Alt+Left, Alt+Right and Alt+Up are the known ones; a new clash is
          // pressed here too.
          expect(clashes.length, greaterThanOrEqualTo(3));
          for (final chord in clashes) {
            await _pressActivator(tester, chord);
          }
          expect(fired, isEmpty);
        });
      });
    }

    testWidgets('and without a field, the same chords run the commands', (
      tester,
    ) async {
      await tester.pumpWidget(_app(TargetPlatform.linux, registry));
      await _press(tester, 'Alt+Left');
      await _press(tester, 'Alt+Right');
      await _press(tester, 'Alt+Up');
      expect(fired, [
        MacCommand.back,
        MacCommand.forward,
        MacCommand.enclosingFolder,
      ]);
    });
  });

  group('a text field', () {
    testWidgets('keeps Ctrl+Backspace and the other editing keys', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'hello brave world');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 17);
      await tester.pumpWidget(
        _app(
          TargetPlatform.linux,
          registry,
          body: TextField(controller: controller, autofocus: true),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.text, 'hello brave ');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(fired, isEmpty);
    });

    testWidgets('still runs a command whose key text editing does not use', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.linux,
          registry,
          body: const TextField(autofocus: true),
        ),
      );
      await tester.pump();
      await _press(tester, 'Ctrl+N');
      await _press(tester, 'F1');
      expect(fired, [MacCommand.newChat, MacCommand.keyboardShortcuts]);
    });
  });

  group('the Keyboard shortcuts page', () {
    final navigatorKey = GlobalKey<NavigatorState>();

    Widget appWithMenuBar(TargetPlatform platform, {Widget? home}) =>
        MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: platform),
          builder: (context, child) =>
              MacMenuBar(navigatorKey: navigatorKey, child: child!),
          home:
              home ??
              Scaffold(body: Focus(autofocus: true, child: const SizedBox())),
        );

    testWidgets('F1 opens it on Linux, once', (tester) async {
      await tester.pumpWidget(appWithMenuBar(TargetPlatform.linux));
      await tester.pump();
      expect(find.byType(KeyboardShortcutsPage), findsNothing);

      await _press(tester, 'F1');
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardShortcutsPage), findsOneWidget);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);

      await _press(tester, 'F1');
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardShortcutsPage), findsOneWidget);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardShortcutsPage), findsNothing);
    });

    testWidgets('F1 does nothing on a Mac', (tester) async {
      await tester.pumpWidget(appWithMenuBar(TargetPlatform.macOS));
      await tester.pump();
      await _press(tester, 'F1');
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardShortcutsPage), findsNothing);
    });

    testWidgets('lists exactly the declared commands, each once', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appWithMenuBar(TargetPlatform.linux));
      await tester.pump();
      await _press(tester, 'F1');
      await tester.pumpAndSettle();

      final titles = <String>[];
      final list = find.byType(KeyboardShortcutsView);
      expect(list, findsOneWidget);
      for (final row in tester.widgetList<GroupedRow>(
        find.byType(GroupedRow),
      )) {
        titles.add(row.title);
      }
      expect(titles, hasLength(_desktopTable.length));
      expect(titles.toSet(), hasLength(titles.length));
      expect(titles.toSet(), {
        'New Chat',
        'Settings',
        'Reload',
        'Back',
        'Forward',
        'Enclosing Folder',
        'Show Sidebar',
        'Show Files',
        'Previous Change',
        'Next Change',
        'Find',
        'Pin',
        'Keyboard shortcuts',
      });
      // Both keys of Reload are shown.
      expect(find.text('F5'), findsOneWidget);
      expect(find.text('or'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('the Settings row opens it on Windows, Linux and a Mac', (
      tester,
    ) async {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        await tester.pumpWidget(
          appWithMenuBar(
            platform,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(showSettingsDialog(context)),
                child: const Text('open settings'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open settings'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('setting-keyboardShortcuts')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(KeyboardShortcutsPage),
          findsOneWidget,
          reason: '$platform',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the Settings row is left out on a phone', (tester) async {
      await tester.pumpWidget(
        appWithMenuBar(
          TargetPlatform.android,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(showSettingsDialog(context)),
              child: const Text('open settings'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open settings'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setting-about')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('setting-keyboardShortcuts')),
        findsNothing,
      );
    });
  });

  group('the tooltips', () {
    Future<void> pump(WidgetTester tester, TargetPlatform platform) =>
        tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Column(
                children: [
                  NewChatButton(onPressed: () {}),
                  NewChatFab(onPressed: () {}),
                  Builder(
                    builder: (context) => Text(
                      withChordHint(context, 'Reload', MacCommand.reload),
                    ),
                  ),
                  Builder(
                    builder: (context) => Text(
                      withChordHint(context, 'Delete', MacCommand.deleteThread),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      testWidgets('show the chord on $platform', (tester) async {
        await pump(tester, platform);
        expect(find.byTooltip('New chat (Ctrl+N)'), findsNWidgets(2));
        // The first chord of a command with two.
        expect(find.text('Reload (Ctrl+R)'), findsOneWidget);
        // A command with no chord keeps its label.
        expect(find.text('Delete'), findsOneWidget);
      });
    }

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      testWidgets('keep the label alone on $platform', (tester) async {
        await pump(tester, platform);
        expect(find.byTooltip('New chat'), findsNWidgets(2));
        expect(find.text('Reload'), findsOneWidget);
      });
    }
  });
}
