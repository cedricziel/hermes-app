import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/macos/mac_menu_bar.dart';
import 'package:hermes_app/src/macos/menu_layout.dart';
import 'package:hermes_app/src/navigation/desktop_command_shortcuts.dart';
import 'package:hermes_app/src/navigation/modal_route_observer.dart';

import '../support/test_localizations.dart';

/// Every Windows and Linux chord of the menus except F10, which the menu bar
/// host registers only while no dialog is open (`desktop_menu_bar_f10_test`).
final _chords = <(MacCommand, SingleActivator)>[
  for (final section in menuLayout)
    for (final group in section.groupsOn(MenuPlatform.desktop))
      for (final entry in group)
        if (entry.command != MacCommand.focusMenuBar)
          for (final chord in entry.shortcutsOn(MenuPlatform.desktop))
            (entry.command, chord),
];

Future<void> _press(WidgetTester tester, SingleActivator chord) async {
  final modifiers = [
    if (chord.control) LogicalKeyboardKey.controlLeft,
    if (chord.alt) LogicalKeyboardKey.altLeft,
    if (chord.shift) LogicalKeyboardKey.shiftLeft,
  ];
  for (final modifier in modifiers) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyEvent(chord.trigger);
  for (final modifier in modifiers.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pump();
}

String _label(SingleActivator c) =>
    '${c.control ? 'Ctrl+' : ''}${c.alt ? 'Alt+' : ''}'
    '${c.shift ? 'Shift+' : ''}${c.trigger.debugName}';

SingleActivator _chordOf(MacCommand command) =>
    _chords.firstWhere((c) => c.$1 == command).$2;

const _fieldKey = ValueKey('field');

void main() {
  late MacCommandRegistry registry;
  late MacCommandRegistration registration;
  late ModalRouteObserver modalRoutes;
  late List<MacCommand> fired;
  var confirmed = 0;

  setUp(() {
    registry = MacCommandRegistry();
    fired = [];
    confirmed = 0;
    registration = registry.register({
      for (final command in MacCommand.values)
        command: MacCommandHandler(() => fired.add(command)),
    });
    modalRoutes = ModalRouteObserver();
  });

  tearDown(() {
    registration.dispose();
    registry.dispose();
    modalRoutes.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(platform: TargetPlatform.linux),
      navigatorObservers: [modalRoutes],
      builder: (context, child) => MacCommandScope.root(
        registry: registry,
        child: DesktopCommandShortcuts(modalRoutes: modalRoutes, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Focus(
            autofocus: true,
            child: TextButton(
              onPressed: () => unawaited(
                showDialog<void>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    content: const TextField(key: _fieldKey, maxLines: null),
                    actions: [
                      TextButton(
                        autofocus: true,
                        onPressed: () {
                          confirmed++;
                          Navigator.of(dialog).pop();
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  EditableTextState editable(WidgetTester tester) => tester.state(
    find.descendant(
      of: find.byKey(_fieldKey),
      matching: find.byType(EditableText),
    ),
  );

  group('behind an open dialog', () {
    // One test per chord, so each class (navigation, stacking, state change,
    // view, reload) is named in the report.
    for (final (command, chord) in _chords) {
      testWidgets('${_label(chord)} for $command is not taken', (tester) async {
        await pumpApp(tester);
        await openDialog(tester);
        await _press(tester, chord);
        expect(fired, isEmpty);
      });
    }

    testWidgets('the same chord runs again once the dialog closes', (
      tester,
    ) async {
      await pumpApp(tester);
      await openDialog(tester);
      await _press(tester, _chordOf(MacCommand.newChat));
      expect(fired, isEmpty);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await _press(tester, _chordOf(MacCommand.newChat));
      expect(fired, [MacCommand.newChat]);
    });

    testWidgets('Escape still closes the dialog', (tester) async {
      await pumpApp(tester);
      await openDialog(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fired, isEmpty);
    });

    testWidgets('Enter activates the focused button', (tester) async {
      await pumpApp(tester);
      await openDialog(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Tab moves focus inside the dialog', (tester) async {
      await pumpApp(tester);
      await openDialog(tester);
      final before = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final after = FocusManager.instance.primaryFocus;
      expect(after, isNot(before));
      expect(
        after!.context!.findAncestorWidgetOfExactType<AlertDialog>(),
        isNotNull,
      );
    });

    testWidgets('a field in the dialog still moves its caret with Alt+Left', (
      tester,
    ) async {
      await pumpApp(tester);
      await openDialog(tester);
      await tester.enterText(find.byKey(_fieldKey), 'one\ntwo');
      await tester.pump();
      final before = editable(tester).textEditingValue.selection.baseOffset;
      await _press(tester, _chordOf(MacCommand.back));
      expect(fired, isEmpty);
      expect(
        editable(tester).textEditingValue.selection.baseOffset,
        lessThan(before),
      );
    });

    testWidgets('a field in the dialog gets Ctrl+F, which nothing runs', (
      tester,
    ) async {
      await pumpApp(tester);
      await openDialog(tester);
      await tester.enterText(find.byKey(_fieldKey), 'text');
      await tester.pump();
      await _press(tester, _chordOf(MacCommand.find));
      expect(fired, isEmpty);
      expect(editable(tester).textEditingValue.text, 'text');
    });
  });

  testWidgets('MacMenuBar hands the observer on, as the app does', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final behind = FocusNode();
    addTearDown(behind.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.linux),
        navigatorObservers: [modalRoutes],
        builder: (context, child) => MacMenuBar(
          navigatorKey: navigatorKey,
          modalRoutes: modalRoutes,
          child: child!,
        ),
        home: Builder(
          builder: (context) => MacCommandScope(
            commands: {
              MacCommand.newChat: MacCommandHandler(
                () => fired.add(MacCommand.newChat),
              ),
            },
            child: Focus(
              focusNode: behind,
              autofocus: true,
              child: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final chord = _chordOf(MacCommand.newChat);
    await _press(tester, chord);
    expect(fired, [MacCommand.newChat]);

    unawaited(
      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();
    // The focus back on the screen behind the dialog (a click there), where
    // the route of the focus says nothing and only the observer does.
    behind.requestFocus();
    await tester.pump();
    await _press(tester, chord);
    expect(fired, [MacCommand.newChat]);
  });

  group('behind a modal route on a nested navigator', () {
    // The root observer never hears of these: both open on the nested
    // Navigator (`useRootNavigator: false`), like the narrow chat layout and
    // the activity panel do.
    Future<void> pumpNested(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.linux),
        navigatorObservers: [modalRoutes],
        builder: (context, child) => MacCommandScope.root(
          registry: registry,
          child: DesktopCommandShortcuts(
            modalRoutes: modalRoutes,
            child: child!,
          ),
        ),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Builder(
                builder: (context) => Focus(
                  autofocus: true,
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () => unawaited(
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => TextButton(
                              autofocus: true,
                              onPressed: () {},
                              child: const Text('in the sheet'),
                            ),
                          ),
                        ),
                        child: const Text('sheet'),
                      ),
                      TextButton(
                        onPressed: () => unawaited(
                          showMenu<void>(
                            context: context,
                            position: const RelativeRect.fromLTRB(0, 0, 0, 0),
                            items: const [
                              PopupMenuItem<void>(child: Text('in the menu')),
                            ],
                          ),
                        ),
                        child: const Text('menu'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    for (final (opener, inside) in [
      ('sheet', 'in the sheet'),
      ('menu', 'in the menu'),
    ]) {
      testWidgets('a $opener takes no chord, and the chord runs after it', (
        tester,
      ) async {
        await pumpNested(tester);
        await tester.tap(find.text(opener));
        await tester.pumpAndSettle();
        expect(find.text(inside), findsOneWidget);
        expect(
          modalRoutes.modalOpen,
          isFalse,
          reason: 'root observer is blind',
        );

        for (final command in [MacCommand.newChat, MacCommand.back]) {
          await _press(tester, _chordOf(command));
        }
        expect(fired, isEmpty);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text(inside), findsNothing);

        await _press(tester, _chordOf(MacCommand.newChat));
        expect(fired, [MacCommand.newChat]);
      });
    }
  });
}
