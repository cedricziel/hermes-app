import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';

Widget _app(TargetPlatform platform) {
  return MaterialApp(
    theme: ThemeData(platform: platform),
    home: DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Plugins'),
          bottom: const AdaptiveTabBar(
            labels: ['Installed', 'Catalog', 'Providers'],
          ),
        ),
        body: const TabBarView(
          children: [Text('one'), Text('two'), Text('three')],
        ),
      ),
    ),
  );
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('$platform shows a segmented control that switches views', (
      tester,
    ) async {
      await tester.pumpWidget(_app(platform));
      expect(find.byType(TabBar), findsNothing);
      expect(
        find.byType(CupertinoSlidingSegmentedControl<int>),
        findsOneWidget,
      );
      expect(find.text('one'), findsOneWidget);
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
      expect(find.text('one'), findsNothing);
    });
  }

  testWidgets('Android keeps the tab bar', (tester) async {
    await tester.pumpWidget(_app(TargetPlatform.android));
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsNothing);
    await tester.tap(find.text('Providers'));
    await tester.pumpAndSettle();
    expect(find.text('three'), findsOneWidget);
  });
}
