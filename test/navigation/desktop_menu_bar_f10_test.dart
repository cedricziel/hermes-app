import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/navigation/desktop_command_shortcuts.dart';
import 'package:hermes_app/src/navigation/desktop_menu_bar_host.dart';
import 'package:hermes_app/src/navigation/desktop_menu_bar_settings.dart';
import 'package:hermes_app/src/macos/menu_layout.dart';
import 'package:hermes_app/src/navigation/keyboard_shortcuts.dart';
import 'package:hermes_app/src/navigation/modal_route_observer.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/test_localizations.dart';

final _ringFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

void main() {
  late MacCommandRegistry registry;
  late DesktopMenuBarSettings settings;
  late ModalRouteObserver modalRoutes;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    resetFocusRingInput();
    registry = MacCommandRegistry();
    settings = DesktopMenuBarSettings();
    modalRoutes = ModalRouteObserver();
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    modalRoutes.dispose();
    settings.dispose();
    registry.dispose();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required bool barOn,
    bool tickers = true,
    bool shortcutsPage = false,
  }) async {
    if (barOn) await settings.setEnabled(true);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: TargetPlatform.linux),
          navigatorObservers: [modalRoutes],
          builder: (context, child) => MacCommandScope.root(
            registry: registry,
            child: DesktopCommandShortcuts(
              child: TickerMode(
                enabled: tickers,
                child: DesktopMenuBarHost(
                  modalRoutes: modalRoutes,
                  child: child!,
                ),
              ),
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => MacCommandScope(
                commands: {
                  if (shortcutsPage)
                    MacCommand.keyboardShortcuts: MacCommandHandler(
                      () => unawaited(showKeyboardShortcuts(context)),
                    ),
                },
                child: const Center(child: TextField(autofocus: true)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool fieldFocused(WidgetTester tester) => tester
      .widget<EditableText>(find.byType(EditableText))
      .focusNode
      .hasPrimaryFocus;

  testWidgets('F10 puts the ring on File, and ArrowRight walks to View', (
    tester,
  ) async {
    await pumpApp(tester, barOn: true);
    expect(fieldFocused(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pumpAndSettle();

    expect(fieldFocused(tester), isFalse);
    expect(_ringFinder, findsOneWidget);
    final painter =
        (_ringFinder.evaluate().single.widget as CustomPaint).foregroundPainter!
            as FocusRingPainter;
    expect(painter.radius, 4);
    expect(painter.inset, 2);
    expect(
      tester.getRect(_ringFinder),
      tester.getRect(find.byType(SubmenuButton).first),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_ringFinder, findsOneWidget);
    expect(
      tester.getRect(_ringFinder),
      tester.getRect(find.byType(SubmenuButton).at(1)),
    );
  });

  Future<void> escapeRoundTrip(
    WidgetTester tester, {
    required bool enabledItem,
  }) async {
    final registration = enabledItem
        ? registry.register({MacCommand.newChat: MacCommandHandler(() {})})
        : null;
    addTearDown(() => registration?.dispose());
    await pumpApp(tester, barOn: true);

    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pumpAndSettle();
    expect(fieldFocused(tester), isFalse);
    // Also after moving along the bar and into a menu.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    if (enabledItem) {
      final focused = FocusManager.instance.primaryFocus!.context!;
      final item = focused.findAncestorWidgetOfExactType<MenuItemButton>();
      expect(item, isNotNull, reason: 'ArrowDown focuses an enabled item');
      expect(
        find.descendant(
          of: find.byWidget(item!),
          matching: find.text('New Chat'),
        ),
        findsOneWidget,
      );
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(fieldFocused(tester), isTrue);
    expect(_ringFinder, findsNothing);
  }

  testWidgets('Escape gives the focus back to the field it came from', (
    tester,
  ) async {
    await escapeRoundTrip(tester, enabledItem: false);
  });

  testWidgets('Escape from an enabled item gives the focus back too', (
    tester,
  ) async {
    await escapeRoundTrip(tester, enabledItem: true);
  });

  testWidgets('F10 is not taken under the App Lock cover', (tester) async {
    await pumpApp(tester, barOn: true, tickers: false);
    expect(fieldFocused(tester), isTrue);
    expect(registry.handlerFor(MacCommand.focusMenuBar), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pumpAndSettle();

    expect(fieldFocused(tester), isTrue);
    expect(_ringFinder, findsNothing);
  });

  testWidgets('switching the bar off leaves nothing behind for a dialog', (
    tester,
  ) async {
    await pumpApp(tester, barOn: true);
    await settings.setEnabled(false);
    await tester.pumpAndSettle();
    expect(find.byType(MenuBar), findsNothing);
    // ignore: invalid_use_of_protected_member
    expect(modalRoutes.hasListeners, isFalse);

    final context = tester.element(find.byType(Scaffold));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Sure?')),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Keyboard shortcuts page F1 opens lists Menu bar F10', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(900, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, barOn: true, shortcutsPage: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();

    expect(find.text('Menu bar'), findsOneWidget);
    expect(find.text('F10'), findsOneWidget);
  });

  testWidgets('with the bar off that page has no Menu bar row', (tester) async {
    tester.view
      ..physicalSize = const Size(900, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, barOn: false, shortcutsPage: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();

    expect(find.text('Keyboard shortcuts'), findsWidgets);
    expect(find.text('Menu bar'), findsNothing);
  });

  testWidgets('F10 does nothing behind an open dialog', (tester) async {
    await pumpApp(tester, barOn: true);
    final context = tester.element(find.byType(Scaffold));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: TextField(autofocus: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pumpAndSettle();

    expect(_ringFinder, findsNothing);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<AlertDialog>(),
      isNotNull,
      reason: 'the focus stays in the dialog',
    );
  });

  testWidgets('F10 does nothing while the bar is off', (tester) async {
    await pumpApp(tester, barOn: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pumpAndSettle();

    expect(fieldFocused(tester), isTrue);
    expect(_ringFinder, findsNothing);
    expect(registry.handlerFor(MacCommand.focusMenuBar), isNull);
  });

  test('the Keyboard shortcuts page lists F10 only while the bar is shown', () {
    final en = lookupAppLocalizations(const Locale('en'));
    List<String> rows({required bool shown}) => [
      for (final section in keyboardShortcutSections(
        en,
        MenuPlatform.desktop,
        menuBarShown: shown,
      ))
        for (final row in section.rows)
          '${row.label} ${row.chords.map((c) => c.text).join(' ')}',
    ];

    expect(rows(shown: true), contains('Menu bar F10'));
    expect(rows(shown: false).where((r) => r.startsWith('Menu bar')), isEmpty);
  });
}
