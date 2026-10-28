import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Widget _app(
  BotScreenViewerPhase phase, {
  TargetPlatform platform = TargetPlatform.android,
  BotScreenViewerPresentation presentation = BotScreenViewerPresentation.page,
  bool picture = true,
  EdgeInsets padding = EdgeInsets.zero,
  Size size = const Size(390, 844),
  VoidCallback? onClose,
}) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  home: MediaQuery(
    data: MediaQueryData(size: size, padding: padding),
    child: BotScreenViewerView(
      phase: phase,
      profile: 'research',
      presentation: presentation,
      picture: picture ? const ColoredBox(color: Colors.blue) : null,
      onClose: onClose,
    ),
  ),
);

void main() {
  final zoom = find.byType(InteractiveViewer);

  group('the picture', () {
    testWidgets('zooms out no further than the screen and up to 4 times', (
      tester,
    ) async {
      await tester.pumpWidget(_app(BotScreenViewerPhase.live));

      final viewer = tester.widget<InteractiveViewer>(zoom);
      expect(viewer.minScale, 1);
      expect(viewer.maxScale, 4);
    });

    testWidgets('keeps its zoom through a reconnect, a blank and back', (
      tester,
    ) async {
      await tester.pumpWidget(_app(BotScreenViewerPhase.live));
      final state = tester.state(zoom);

      for (final (phase, picture) in [
        (BotScreenViewerPhase.reconnecting, true),
        (BotScreenViewerPhase.live, true),
        (BotScreenViewerPhase.blanked, false),
        (BotScreenViewerPhase.live, true),
        (BotScreenViewerPhase.connecting, false),
      ]) {
        await tester.pumpWidget(_app(phase, picture: picture));

        expect(zoom, findsOneWidget, reason: '$phase');
        expect(tester.state(zoom), same(state), reason: '$phase');
      }
    });

    testWidgets('draws no picture while blanked', (tester) async {
      await tester.pumpWidget(
        _app(BotScreenViewerPhase.blanked, picture: false),
      );

      expect(find.byType(ColoredBox), findsWidgets);
      expect(find.text('Someone else is in control'), findsWidgets);
      expect(find.bySemanticsLabel("Hermes's screen"), findsNothing);
    });

    testWidgets('does not rebuild its theme with each frame', (tester) async {
      await tester.pumpWidget(_app(BotScreenViewerPhase.live));
      ThemeData themeOf() => tester
          .widget<Theme>(
            find
                .descendant(
                  of: find.byType(BotScreenViewerView),
                  matching: find.byType(Theme),
                )
                .first,
          )
          .data;
      final first = themeOf();

      await tester.pumpWidget(_app(BotScreenViewerPhase.reconnecting));

      expect(themeOf(), same(first));
    });
  });

  group('room for the system', () {
    testWidgets('keeps clear of a notch beside a landscape phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          BotScreenViewerPhase.live,
          size: const Size(844, 390),
          padding: const EdgeInsets.only(left: 47, right: 47, bottom: 21),
        ),
      );

      expect(
        tester.getTopLeft(find.byTooltip('Close')).dx,
        greaterThanOrEqualTo(47),
      );
      expect(tester.getBottomRight(zoom).dy, lessThanOrEqualTo(390 - 21));
    });

    testWidgets(
      'leaves the Mac traffic lights alone, as a page and as a layer',
      (tester) async {
        for (final presentation in BotScreenViewerPresentation.values) {
          await tester.pumpWidget(
            _app(
              BotScreenViewerPhase.live,
              platform: TargetPlatform.macOS,
              presentation: presentation,
            ),
          );

          expect(
            tester.getTopLeft(find.text('research')).dx,
            greaterThanOrEqualTo(kMacTrafficLightsWidth),
            reason: '$presentation',
          );
        }
      },
    );

    testWidgets('moves the Mac window by its header', (tester) async {
      await tester.pumpWidget(
        _app(BotScreenViewerPhase.live, platform: TargetPlatform.macOS),
      );
      expect(find.byType(MacWindowDragArea), findsOneWidget);

      await tester.pumpWidget(_app(BotScreenViewerPhase.live));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MacWindowDragArea), findsNothing);
    });

    testWidgets('Close is a button on every platform', (tester) async {
      var closed = 0;
      for (final platform in TargetPlatform.values) {
        await tester.pumpWidget(
          _app(
            BotScreenViewerPhase.live,
            platform: platform,
            onClose: () => closed++,
          ),
        );
        await tester.tap(find.byTooltip('Close'));
      }

      expect(closed, TargetPlatform.values.length);
    });
  });
}
