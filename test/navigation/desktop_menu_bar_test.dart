import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/navigation/desktop_menu_bar_host.dart';
import 'package:hermes_app/src/navigation/desktop_menu_bar_settings.dart';
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
}) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(platform: platform),
    builder: (context, child) => MacCommandScope.root(
      registry: registry,
      child: DesktopMenuBarHost(child: child!),
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
