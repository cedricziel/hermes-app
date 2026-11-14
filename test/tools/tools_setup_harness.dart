import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:hermes_app/src/tools/toolset_installs.dart';
import 'package:hermes_app/src/tools/tools_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'tools_setup_world.dart';

/// A phone's width and a tall window, so a long page builds all of its rows.
const phone = Size(390, 3200);
const wide = Size(1200, 900);

/// Opens `ToolsScreen` for the profile `work` against [world], as the shell
/// does, and keeps the handles a test needs.
class SetupHarness {
  SetupHarness(this.tester, this.world);

  final WidgetTester tester;
  final SetupWorld world;
  final links = <Uri>[];

  /// Replaces the repository, for a test that watches the pipeline.
  HermesToolsRepository? repositoryOverride;

  HermesToolsRepository get repository =>
      repositoryOverride ??
      HermesToolsRepository(world.server.client().raw, profile: 'work');

  Future<void> pump({
    Size size = phone,
    TargetPlatform platform = TargetPlatform.android,
    AppLockController? lock,
    ToolsetInstalls? installs,
    ToolsBotScreenLink? botScreen,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    List<Provider<Object>> providers = const [],
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final theme = brightness == Brightness.dark
        ? buildHermesDarkTheme(platform: platform)
        : buildHermesLightTheme(platform: platform);
    final app = MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: const Scaffold(body: Text('home')),
    );
    await tester.pumpWidget(
      lock == null
          ? app
          : ChangeNotifierProvider<AppLockController>.value(
              value: lock,
              child: app,
            ),
    );
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ToolsScreen(
                repository: repository,
                installs: installs,
                botScreen: botScreen,
                launchLink: (uri) async {
                  links.add(uri);
                  return true;
                },
              ),
            ),
          ),
    );
    await tester.pumpAndSettle();
  }

  /// Takes the screen down, so nothing it follows keeps a timer.
  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
  }

  /// Opens a toolset's details: the page below the wide breakpoint, the pane
  /// beside the list above it, by tapping the sentence of its row.
  ///
  /// With [settle] false it does not wait for animations to end, for a page
  /// that shows a running install.
  Future<void> open(String sentence, {bool settle = true}) async {
    final finder = find.descendant(
      of: find.byKey(const Key('tools-list')),
      matching: find.text(sentence),
    );
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> openWeb() => open('Look things up on the web and read pages.');
  Future<void> openTerminal() =>
      open('Run commands on the machine where Hermes runs.');
  Future<void> openComputerUse({bool settle = true}) => open(
    "See a desktop's screen and move its mouse and keyboard.",
    settle: settle,
  );
  Future<void> openImages() => open('Make pictures from a description.');

  /// A provider's row in the first group that lists it.
  Finder provider(String name) => find.byKey(ValueKey('provider-$name'));

  Future<void> pick(String name, {int index = 0}) async {
    final finder = provider(name).at(index);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder get keyField => find.byType(TextField);

  Future<void> type(String value) async {
    await tester.ensureVisible(keyField.first);
    await tester.pump();
    await tester.enterText(keyField.first, value);
    await tester.pump();
  }

  Future<void> tapText(String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  /// Presses "Show key".
  Future<void> showKey() async {
    await tester.tap(find.byTooltip('Show key'));
    await tester.pump();
  }

  /// The text of the key field, for the tests that check it was kept or
  /// cleared. Never printed.
  String get fieldText =>
      tester.widget<TextField>(keyField.first).controller?.text ?? '';

  /// Whether the field hides what is typed.
  bool get fieldObscured =>
      tester.widget<TextField>(keyField.first).obscureText;
}
