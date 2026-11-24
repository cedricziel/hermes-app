import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_header.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../../support/screenshot_recorder.dart';

Widget _header(
  TargetPlatform platform,
  double scale, {
  BotScreenViewerPresentation presentation = BotScreenViewerPresentation.page,
  String profile = 'research',
  BotScreenHeaderAction? action = const BotScreenHeaderAction(
    label: 'Take over',
    onPressed: _noop,
  ),
}) => MaterialApp(
  theme: withScreenshotFont(buildHermesDarkTheme(platform: platform)),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 300),
      textScaler: TextScaler.linear(scale),
    ),
    child: Material(
      color: Colors.black,
      child: Align(
        alignment: Alignment.topLeft,
        child: BotScreenViewerHeader(
          profile: profile,
          control: 'Hermes is in control',
          inControl: false,
          action: action,
          presentation: presentation,
          onClose: () {},
        ),
      ),
    ),
  ),
);

void _noop() {}

void main() {
  // The Mac button asks for 28 but the compact density of that platform draws
  // it 20 high today; the test holds it at that, so large text never shrinks it.
  const platforms = {
    TargetPlatform.iOS: (bar: 44.0, action: 44.0, close: 44.0),
    TargetPlatform.macOS: (bar: 52.0, action: 20.0, close: 28.0),
    TargetPlatform.android: (bar: 56.0, action: 48.0, close: 48.0),
  };
  for (final MapEntry(key: platform, value: min) in platforms.entries) {
    for (final scale in const [1.0, 1.3, 2.0, 3.0]) {
      for (final presentation in BotScreenViewerPresentation.values) {
        testWidgets(
          '${platform.name}, ${presentation.name}, text ${scale}x: fits its '
          'bar, shows the profile whole and keeps its tap targets',
          (tester) async {
            await tester.runAsync(loadTestFonts);
            await tester.pumpWidget(
              _header(platform, scale, presentation: presentation),
            );
            // A RenderFlex overflow is reported as an exception.
            expect(tester.takeException(), isNull);
            final header = tester.getSize(find.byType(BotScreenViewerHeader));
            expect(header.height, min.bar);
            final title = tester.renderObject<RenderParagraph>(
              find.text('research'),
            );
            expect(title.didExceedMaxLines, isFalse);
            expect(
              tester.getSize(find.byType(FilledButton)).height,
              greaterThanOrEqualTo(min.action),
            );
            expect(
              tester.getSize(find.byType(IconButton)).height,
              greaterThanOrEqualTo(min.close),
            );
            expect(
              tester.getSize(find.byType(IconButton)).width,
              greaterThanOrEqualTo(min.close),
            );
          },
        );
      }
    }
  }
}
