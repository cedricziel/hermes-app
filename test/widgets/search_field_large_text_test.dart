import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:hermes_app/src/widgets/settings_search_field.dart';

import '../support/screenshot_recorder.dart';

const _hint = 'Search the skills hub';

Widget _app(TargetPlatform platform, double scale, Widget home) => MaterialApp(
  theme: withScreenshotFont(buildHermesLightTheme(platform: platform)),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

/// The height the hint needs on one line, as the field lays it out.
double _hintHeight(WidgetTester tester, Finder within) {
  final hint = find.descendant(of: within, matching: find.text(_hint));
  final paragraph = tester.renderObject<RenderParagraph>(hint);
  return paragraph.getMinIntrinsicHeight(double.infinity);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final ios = platform == TargetPlatform.iOS;
    for (final scale in [1.0, 2.0, 3.1]) {
      testWidgets('$platform at ${scale}x keeps the hint inside the field and '
          'the field inside the bar', (tester) async {
        await tester.runAsync(loadTestFonts);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            platform,
            scale,
            SettingsScaffold(
              title: 'Skills',
              search: SettingsSearch(query: '', hint: _hint, onChanged: (_) {}),
              body: const SizedBox(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final field = find.byType(SettingsSearchField);
        final fieldBox = tester.getRect(field);
        final hintHeight = _hintHeight(tester, field);
        expect(
          fieldBox.height,
          greaterThanOrEqualTo(hintHeight),
          reason: 'the hint needs $hintHeight in a ${fieldBox.height} field',
        );
        if (scale == 1.0) {
          expect(fieldBox.height, ios ? 36 : 44);
        }
        // The bar keeps its whole toolbar and grows by the field and its gap.
        final bar = tester.widget<AppBar>(find.byType(AppBar));
        expect(
          tester.getSize(find.byType(AppBar)).height,
          bar.toolbarHeight! +
              SettingsSearchField.heightFor(
                ios: ios,
                textScaler: TextScaler.linear(scale),
              ) +
              8,
        );
        expect(
          tester.getRect(find.byType(AppBar)).bottom,
          greaterThanOrEqualTo(fieldBox.bottom),
        );
      });
    }
  }

  testWidgets('the Mac toolbar search field stays 26 points at 3.1x', (
    tester,
  ) async {
    await tester.runAsync(loadTestFonts);
    await tester.pumpWidget(
      _app(
        TargetPlatform.macOS,
        3.1,
        Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: MacToolbarSearchField(
              query: '',
              active: false,
              hint: _hint,
              onChanged: (_) {},
              onEnd: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final field = find.byType(MacToolbarSearchField);
    expect(tester.getSize(field).height, 26);
    // 26 points less the 1 point border on each side.
    expect(_hintHeight(tester, field), lessThanOrEqualTo(24));
  });

  testWidgets('the Mac field keeps its normal caret height at 1.0x', (
    tester,
  ) async {
    await tester.runAsync(loadTestFonts);
    await tester.pumpWidget(
      _app(
        TargetPlatform.macOS,
        1,
        Scaffold(
          body: MacToolbarSearchField(
            query: '',
            active: false,
            onChanged: (_) {},
            onEnd: () {},
          ),
        ),
      ),
    );
    RenderEditable? editable;
    void visit(RenderObject object) {
      if (object is RenderEditable) editable = object;
      object.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(TextField)));
    expect(editable!.preferredLineHeight, equals(20));
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final ios = platform == TargetPlatform.iOS;
    for (final scale in [2.0, 3.1]) {
      testWidgets('$platform at ${scale}x keeps the filter button its size and '
          'the hint on one line', (tester) async {
        await tester.runAsync(loadTestFonts);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            platform,
            scale,
            SettingsScaffold(
              title: 'Skills',
              search: SettingsSearch(
                query: '',
                hint: _hint,
                onChanged: (_) {},
                filters: [
                  SettingsFilter(
                    label: 'All',
                    selected: true,
                    onSelected: () {},
                  ),
                  SettingsFilter(
                    label: 'Enabled',
                    selected: false,
                    onSelected: () {},
                  ),
                ],
              ),
              body: const SizedBox(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final field = tester.getRect(find.byType(SettingsSearchField));
        final button = tester.getRect(
          find.byKey(const Key('settings-search-filter')),
        );
        // The button keeps its platform size and stays centred in the field.
        expect(button.size, Size.square(ios ? 36 : 44));
        expect(button.center.dy, closeTo(field.center.dy, 0.5));

        final hint = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(SettingsSearchField),
            matching: find.text(_hint),
          ),
        );
        expect(hint.size.width, greaterThan(0));
        expect(
          hint.size.height,
          closeTo(hint.getMinIntrinsicHeight(double.infinity), 0.5),
          reason: 'one line',
        );
      });
    }
  }
}
