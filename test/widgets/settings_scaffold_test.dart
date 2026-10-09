import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_toolbar.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:hermes_app/src/widgets/settings_search_field.dart';

import '../support/accessibility.dart';

/// Pushes [page] over a first route, so the page has somewhere to go back to.
Widget _pushed(TargetPlatform platform, Widget page) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => page)),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, TargetPlatform platform, Widget page) =>
    tester.pumpWidget(_pushed(platform, page)).then((_) async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    });

Widget _page({
  List<SettingsBarAction> actions = const [],
  List<String>? tabs,
  SettingsSearch? search,
}) => DefaultTabController(
  length: tabs?.length ?? 1,
  child: SettingsScaffold(
    title: 'Plugins',
    subtitle: 'work · 4 installed',
    actions: actions,
    tabs: tabs,
    search: search,
    body: tabs == null
        ? const Text('body')
        : TabBarView(children: [for (final t in tabs) Text('$t view')]),
  ),
);

void main() {
  testWidgets('iOS centers the title over the subtitle in a 44 point bar', (
    tester,
  ) async {
    await _open(tester, TargetPlatform.iOS, _page());
    final bar = tester.widget<AppBar>(find.byType(AppBar).last);
    expect(bar.toolbarHeight, 44);
    expect(bar.centerTitle, isTrue);
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('work · 4 installed'), findsOneWidget);
    expect(find.byType(MacToolbar), findsNothing);
  });

  testWidgets('Material starts the title in a 56 point bar with a back arrow', (
    tester,
  ) async {
    await _open(tester, TargetPlatform.android, _page());
    final bar = tester.widget<AppBar>(find.byType(AppBar).last);
    expect(bar.toolbarHeight, 56);
    expect(bar.centerTitle, isFalse);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a top-level page opens the shell menu instead of going back', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.android),
        home: ShellMenu(onOpen: () => opened = true, child: _page()),
      ),
    );
    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.byKey(const Key('shell-menu')));
    expect(opened, isTrue);
  });

  testWidgets('macOS puts the title, tabs and search in the toolbar', (
    tester,
  ) async {
    await _open(
      tester,
      TargetPlatform.macOS,
      _page(
        tabs: ['Installed', 'Catalog'],
        search: SettingsSearch(query: '', onChanged: (_) {}),
      ),
    );
    expect(find.byType(AppBar), findsNothing);
    final toolbar = find.byType(MacToolbar);
    expect(toolbar, findsOneWidget);
    for (final type in [MacToolbarTabs, MacToolbarSearchField]) {
      expect(
        find.descendant(of: toolbar, matching: find.byType(type)),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog view'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-back')));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform shows tabs and search under the bar', (
      tester,
    ) async {
      String? query;
      await _open(
        tester,
        platform,
        _page(
          tabs: ['Installed', 'Catalog'],
          search: SettingsSearch(
            query: '',
            hint: 'Search plugins',
            onChanged: (q) => query = q,
          ),
        ),
      );
      expect(find.byType(AdaptiveTabBar), findsOneWidget);
      expect(find.text('Search plugins'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('settings-search-field')),
        'kan',
      );
      expect(query, 'kan');
    });
  }

  for (final platform in TargetPlatform.values) {
    testWidgets('an add action is a named bar button on $platform', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var added = 0;
      await _open(
        tester,
        platform,
        _page(
          actions: [
            SettingsBarAction(
              label: 'New Skill',
              icon: AppIcons.add,
              onPressed: () => added++,
            ),
          ],
        ),
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('New Skill')),
        namedButton('New Skill'),
      );
      await tester.tap(find.bySemanticsLabel('New Skill'));
      expect(added, 1);
      semantics.dispose();
    });
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    testWidgets('a menu action runs the picked item on $platform', (
      tester,
    ) async {
      var picked = '';
      await _open(
        tester,
        platform,
        _page(
          actions: [
            SettingsBarAction.menu(
              key: const Key('add-menu'),
              label: 'Add',
              icon: AppIcons.add,
              menu: (_) => [
                AdaptiveMenuItem<void>(
                  onTap: () => picked = 'catalog',
                  child: const Text('Browse the catalog'),
                ),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.byKey(const Key('add-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse the catalog'));
      await tester.pumpAndSettle();
      expect(picked, 'catalog');
    });
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    testWidgets('the search filter menu picks a filter on $platform', (
      tester,
    ) async {
      var filter = 'all';
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: platform),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SettingsSearchField(
                  search: SettingsSearch(
                    query: 'x',
                    onChanged: (_) {},
                    filters: [
                      SettingsFilter(
                        label: 'All',
                        selected: false,
                        onSelected: () => filter = 'all',
                      ),
                      SettingsFilter(
                        label: 'Enabled',
                        selected: true,
                        onSelected: () => filter = 'enabled',
                      ),
                      SettingsFilter(
                        label: 'Disabled',
                        selected: false,
                        onSelected: () => filter = 'disabled',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('settings-search-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();
      expect(filter, 'disabled');
    });
  }

  testWidgets('the clear button empties the search', (tester) async {
    String? query;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: SettingsSearchField(
            search: SettingsSearch(query: 'kan', onChanged: (q) => query = q),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-search-clear')));
    expect(query, '');
  });
}
