import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/navigation/desktop_menu_bar_host.dart';
import 'package:hermes_app/src/navigation/desktop_menu_bar_settings.dart';
import 'package:hermes_app/src/navigation/desktop_menu_models.dart';
import 'package:hermes_app/src/navigation/modal_route_observer.dart';
import 'package:hermes_app/src/navigation/widgets/desktop_menu_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/test_localizations.dart';

Widget _app(
  TargetPlatform platform,
  MacCommandRegistry registry,
  DesktopMenuBarSettings settings, {
  Locale locale = const Locale('en'),
  ModalRouteObserver? modalRoutes,
}) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(
    locale: locale,
    navigatorObservers: [?modalRoutes],
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(platform: platform),
    builder: (context, child) => MacCommandScope.root(
      registry: registry,
      child: DesktopMenuBarHost(modalRoutes: modalRoutes, child: child!),
    ),
    home: const Scaffold(body: Center(child: Text('Chat'))),
  ),
);

Finder _item(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton));

void main() {
  late MacCommandRegistry registry;
  late DesktopMenuBarSettings settings;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    registry = MacCommandRegistry();
    settings = DesktopMenuBarSettings();
  });

  tearDown(() {
    settings.dispose();
    registry.dispose();
  });

  group('whether the bar shows', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      testWidgets('${platform.name}: absent by default, present once on', (
        tester,
      ) async {
        await tester.pumpWidget(_app(platform, registry, settings));
        expect(find.byType(DesktopMenuBar), findsNothing);
        expect(find.text('Chat'), findsOneWidget);

        await settings.setEnabled(true);
        await tester.pump();

        expect(find.byType(DesktopMenuBar), findsOneWidget);
        expect(find.text('File'), findsOneWidget);
        expect(find.text('View'), findsOneWidget);
        expect(find.text('Help'), findsOneWidget);
        expect(
          tester.getSize(find.byType(DesktopMenuBar)).height,
          DesktopMenuBar.height,
        );
        expect(
          tester.getSize(find.byType(DesktopMenuBar)).width,
          tester.view.physicalSize.width / tester.view.devicePixelRatio,
        );
        expect(find.text('Chat'), findsWidgets);

        await settings.setEnabled(false);
        await tester.pump();
        expect(find.byType(DesktopMenuBar), findsNothing);
      });
    }

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.iOS,
      TargetPlatform.android,
    ]) {
      testWidgets('${platform.name}: absent even with the switch on', (
        tester,
      ) async {
        await settings.setEnabled(true);
        await tester.pumpWidget(_app(platform, registry, settings));
        await tester.pump();

        expect(find.byType(DesktopMenuBar), findsNothing);
        expect(find.byType(MenuBar), findsNothing);
      });
    }

    testWidgets('the choice is saved and read back, off without one', (
      tester,
    ) async {
      final prefs = SharedPreferencesAsync();
      expect(await prefs.getBool('desktopMenuBar.enabled'), isNull);
      await settings.load();
      expect(settings.enabled, isFalse);

      await settings.setEnabled(true);
      expect(await prefs.getBool('desktopMenuBar.enabled'), isTrue);

      final later = DesktopMenuBarSettings();
      addTearDown(later.dispose);
      await later.load();
      expect(later.enabled, isTrue);
    });
  });

  group('the items', () {
    testWidgets('an item runs its command through the registry', (
      tester,
    ) async {
      var newChats = 0;
      final registration = registry.register({
        MacCommand.newChat: MacCommandHandler(() => newChats++),
      });
      addTearDown(registration.dispose);
      await settings.setEnabled(true);
      await tester.pumpWidget(_app(TargetPlatform.linux, registry, settings));
      await tester.pump();

      await tester.tap(find.text('File'));
      await tester.pump();
      await tester.tap(find.text('New Chat'));
      await tester.pump();

      expect(newChats, 1);
    });

    testWidgets('an item whose command no screen offers is disabled', (
      tester,
    ) async {
      final registration = registry.register({
        MacCommand.newChat: MacCommandHandler(() {}),
      });
      addTearDown(registration.dispose);
      await settings.setEnabled(true);
      await tester.pumpWidget(_app(TargetPlatform.windows, registry, settings));
      await tester.pump();

      await tester.tap(find.text('File'));
      await tester.pump();

      final offered = tester.widget<MenuItemButton>(_item('New Chat'));
      final withoutHandler = tester.widget<MenuItemButton>(_item('Settings…'));
      expect(offered.onPressed, isNotNull);
      expect(withoutHandler.onPressed, isNull);
    });

    testWidgets('an item follows the registry when a screen registers', (
      tester,
    ) async {
      await settings.setEnabled(true);
      await tester.pumpWidget(_app(TargetPlatform.windows, registry, settings));
      await tester.pump();
      await tester.tap(find.text('File'));
      await tester.pump();
      expect(
        tester.widget<MenuItemButton>(_item('New Chat')).onPressed,
        isNull,
      );

      final registration = registry.register({
        MacCommand.newChat: MacCommandHandler(() {}),
      });
      addTearDown(registration.dispose);
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<MenuItemButton>(_item('New Chat')).onPressed,
        isNotNull,
      );
    });

    testWidgets('the chord is written by the desktop formatter', (
      tester,
    ) async {
      final registration = registry.register({
        MacCommand.newChat: MacCommandHandler(() {}),
      });
      addTearDown(registration.dispose);
      await settings.setEnabled(true);
      await tester.pumpWidget(
        _app(
          TargetPlatform.linux,
          registry,
          settings,
          locale: const Locale('de'),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Ablage'));
      await tester.pump();

      // "Strg" is the German key name, so a hard-coded "Ctrl" would fail.
      final item = _item('Neuer Chat');
      expect(
        find.descendant(of: item, matching: find.text('Strg+N')),
        findsOneWidget,
      );
      expect(find.text('Ctrl+N'), findsNothing);
    });

    testWidgets('the bar binds no key of its own', (tester) async {
      await settings.setEnabled(true);
      await tester.pumpWidget(_app(TargetPlatform.linux, registry, settings));
      await tester.pump();

      expect(
        tester
            .widgetList<MenuItemButton>(find.byType(MenuItemButton))
            .where((item) => item.shortcut != null),
        isEmpty,
      );
    });
  });

  group('the order of the menus', () {
    final en = lookupAppLocalizations(const Locale('en'));

    test('File ends with a divider and Sign Out, Help ends with About', () {
      final menus = desktopMenus(registry, en);
      final labels = [for (final menu in menus) menu.label];
      expect(labels, ['File', 'View', 'Chat', 'Help']);

      final file = menus.first;
      expect([for (final item in file.groups.last) item.label], ['Sign Out…']);
      expect(file.groups.length, greaterThan(1));
      expect([
        for (final group in file.groups) ...group.map((i) => i.label),
      ], containsAllInOrder(['New Chat', 'Settings…', 'Connection Details']));

      final help = menus.last;
      expect(
        [for (final item in help.groups.last) item.label],
        ['About Hermes'],
      );
      expect(help.groups.length, greaterThan(1));
    });
  });

  group('behind a modal route', () {
    testWidgets('an item does not run under a dialog and runs again after', (
      tester,
    ) async {
      var newChats = 0;
      final registration = registry.register({
        MacCommand.newChat: MacCommandHandler(() => newChats++),
      });
      addTearDown(registration.dispose);
      final modalRoutes = ModalRouteObserver();
      addTearDown(modalRoutes.dispose);
      await settings.setEnabled(true);
      await tester.pumpWidget(
        _app(
          TargetPlatform.linux,
          registry,
          settings,
          modalRoutes: modalRoutes,
        ),
      );
      await tester.pump();

      Future<void> chooseNewChat() async {
        await tester.tap(find.text('File'));
        await tester.pump();
        final button = tester.widget<MenuItemButton>(_item('New Chat'));
        button.onPressed?.call();
        await tester.pump();
        // Close a menu a disabled item left open.
        if (find.text('New Chat').evaluate().isNotEmpty) {
          await tester.tapAt(const Offset(700, 500));
          await tester.pump();
        }
      }

      await chooseNewChat();
      expect(newChats, 1);

      final context = tester.element(find.byType(Scaffold));
      final dialog = showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Sure?')),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.text('Sure?'), findsOneWidget);

      await tester.tap(find.text('File'));
      await tester.pump();
      expect(
        tester.widget<MenuItemButton>(_item('New Chat')).onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(newChats, 1);

      Navigator.of(context).pop();
      await dialog;
      await tester.pumpAndSettle();
      await tester.pump();

      await chooseNewChat();
      expect(newChats, 2);
    });
  });

  group('behind a modal route on a nested navigator', () {
    testWidgets('an item does not run under a nested sheet, and does after', (
      tester,
    ) async {
      var newChats = 0;
      final registration = registry.register({
        MacCommand.newChat: MacCommandHandler(() => newChats++),
      });
      addTearDown(registration.dispose);
      final modalRoutes = ModalRouteObserver();
      addTearDown(modalRoutes.dispose);
      await settings.setEnabled(true);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(platform: TargetPlatform.linux),
            navigatorObservers: [modalRoutes],
            builder: (context, child) => MacCommandScope.root(
              registry: registry,
              child: DesktopMenuBarHost(
                modalRoutes: modalRoutes,
                child: child!,
              ),
            ),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      autofocus: true,
                      onPressed: () => unawaited(
                        showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => TextButton(
                            autofocus: true,
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close sheet'),
                          ),
                        ),
                      ),
                      child: const Text('Open sheet'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Close sheet'), findsOneWidget);
      expect(modalRoutes.modalOpen, isFalse);

      await tester.tap(find.text('File'));
      await tester.pump();
      expect(
        tester.widget<MenuItemButton>(_item('New Chat')).onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(newChats, 0);

      await tester.tap(find.text('Close sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Close sheet'), findsNothing);

      await tester.tap(find.text('File'));
      await tester.pump();
      expect(
        tester.widget<MenuItemButton>(_item('New Chat')).onPressed,
        isNotNull,
      );
    });
  });

  testWidgets('switching the bar on keeps the screen it sits above', (
    tester,
  ) async {
    final key = GlobalKey<_CounterState>();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: TargetPlatform.linux),
          builder: (context, child) => MacCommandScope.root(
            registry: registry,
            child: DesktopMenuBarHost(child: child!),
          ),
          home: Scaffold(body: _Counter(key: key)),
        ),
      ),
    );
    key.currentState!.bump();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await settings.setEnabled(true);
    await tester.pump();

    expect(find.byType(DesktopMenuBar), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _count = 0;

  void bump() => setState(() => _count++);

  @override
  Widget build(BuildContext context) => Text('$_count');
}
