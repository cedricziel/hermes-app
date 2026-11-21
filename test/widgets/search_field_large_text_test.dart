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
        // The bar's bottom holds the field.
        final bar = tester.getRect(find.byType(PreferredSize).first);
        expect(fieldBox.bottom, lessThanOrEqualTo(bar.bottom));
        expect(fieldBox.top, greaterThanOrEqualTo(bar.top));
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
}
