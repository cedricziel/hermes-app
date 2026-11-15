import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';

import 'support/screenshot_recorder.dart';

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

  testWidgets('Android shows a pill segmented control that switches views', (
    tester,
  ) async {
    await tester.pumpWidget(_app(TargetPlatform.android));
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsNothing);
    expect(find.byType(PillSegmentedControl<int>), findsOneWidget);
    await tester.tap(find.text('Providers'));
    await tester.pumpAndSettle();
    expect(find.text('three'), findsOneWidget);
  });

  testWidgets('the pill says which segment is selected', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(TargetPlatform.android));
    expect(
      tester.getSemantics(find.text('Installed')),
      isSemantics(label: 'Installed', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Catalog')),
      isSemantics(label: 'Catalog', isButton: true, isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('Mac toolbar tabs switch views', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const MacToolbarTabs(labels: ['Installed', 'Catalog']),
            ),
            body: const TabBarView(children: [Text('one'), Text('two')]),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('each pill segment fills the track, even with a long label', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: PillSegmentedControl<int>(
            value: 0,
            segments: const {
              0: 'Installed plugins',
              1: 'Catalog',
              2: 'Providers',
            },
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final track = tester.getSize(find.byType(PillSegmentedControl<int>));
    for (final ink in tester.widgetList(find.byType(InkWell))) {
      expect(tester.getSize(find.byWidget(ink)).height, track.height - 6);
    }
  });

  // The test font draws every glyph a full em wide; the screenshot harness
  // loads a real one, so a label is judged at its true width.
  for (final (name, labels) in [
    ('Plugins', ['Installed', 'Catalog', 'Providers']),
    ('server logs in German', ['Fehler', 'Agent', 'Gateway']),
    ('long German labels', ['Installiert', 'Verzeichnis', 'Anbieter']),
  ]) {
    testWidgets('iOS 320 pt, text 2.0, $name: every label is shown whole', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('adaptive_tab_bar');
      await shots.start(tester, const Size(320, 200), textScale: 2.0);
      await tester.pumpWidget(
        shots.frame(
          MaterialApp(
            theme: withScreenshotFont(ThemeData(platform: TargetPlatform.iOS)),
            home: DefaultTabController(
              length: labels.length,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Plugins'),
                  bottom: AdaptiveTabBar(labels: labels),
                ),
                body: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await shots.capture(tester, name.replaceAll(' ', '-'));
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(
        find.byType(CupertinoSlidingSegmentedControl<int>),
      );
      expect(bar.right, lessThanOrEqualTo(320));
      for (final label in labels) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
          reason: '$label is cut',
        );
      }
    });
  }
}
