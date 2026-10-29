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
  BotScreenControl control = BotScreenControl.watching,
  bool canForce = false,
  String lostText = 'Someone else took control.',
  String profile = 'research',
  VoidCallback? onTakeOver,
  VoidCallback? onHandBack,
  VoidCallback? onForceHandBack,
  VoidCallback? onDismissLost,
}) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  home: MediaQuery(
    data: MediaQueryData(size: size, padding: padding),
    child: BotScreenViewerView(
      phase: phase,
      profile: profile,
      presentation: presentation,
      picture: picture ? const ColoredBox(color: Colors.blue) : null,
      onClose: onClose,
      control: control,
      canForce: canForce,
      lostText: lostText,
      onTakeOver: onTakeOver,
      onHandBack: onHandBack,
      onForceHandBack: onForceHandBack,
      onDismissLost: onDismissLost,
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
        // The theme animates to the new platform.
        await tester.pump(const Duration(seconds: 1));
        // The Mac names its Escape shortcut, even on a page.
        final tooltip = platform == TargetPlatform.macOS
            ? 'Close (Esc)'
            : 'Close';
        await tester.tap(find.byTooltip(tooltip));
      }

      expect(closed, TargetPlatform.values.length);
    });
  });

  group('control', () {
    testWidgets('watching a live picture says Hermes is in control and offers '
        'Take over', (tester) async {
      var tookOver = 0;
      await tester.pumpWidget(
        _app(BotScreenViewerPhase.live, onTakeOver: () => tookOver++),
      );

      expect(find.text('Hermes is in control'), findsOne);
      await tester.tap(find.text('Take over'));

      expect(tookOver, 1);
      expect(find.text('Hand Back'), findsNothing);
    });

    testWidgets('offers no Take over without a handler or without a live '
        'picture', (tester) async {
      await tester.pumpWidget(_app(BotScreenViewerPhase.live));
      expect(find.text('Take over'), findsNothing);

      for (final phase in [
        BotScreenViewerPhase.connecting,
        BotScreenViewerPhase.reconnecting,
        BotScreenViewerPhase.blanked,
        BotScreenViewerPhase.off,
        BotScreenViewerPhase.failed,
      ]) {
        await tester.pumpWidget(_app(phase, onTakeOver: () {}));
        expect(find.text('Take over'), findsNothing, reason: '$phase');
      }
    });

    testWidgets('acquiring shows Taking over and no second press', (
      tester,
    ) async {
      var tookOver = 0;
      await tester.pumpWidget(
        _app(
          BotScreenViewerPhase.live,
          control: BotScreenControl.acquiring,
          onTakeOver: () => tookOver++,
        ),
      );

      expect(find.text('Taking over…'), findsOne);
      expect(find.text('Take over'), findsNothing);
      expect(tookOver, 0);
    });

    testWidgets('in control says so, keeps the picture and offers Hand Back', (
      tester,
    ) async {
      var handedBack = 0;
      await tester.pumpWidget(
        _app(
          BotScreenViewerPhase.live,
          control: BotScreenControl.inControl,
          onTakeOver: () {},
          onHandBack: () => handedBack++,
        ),
      );

      expect(find.text("You're in control"), findsOne);
      expect(find.text('Hermes is in control'), findsNothing);
      expect(find.text('Take over'), findsNothing);
      expect(find.byType(InteractiveViewer), findsOne);
      await tester.tap(find.text('Hand Back'));

      expect(handedBack, 1);
    });

    testWidgets('losing control says so, with a way to dismiss it and to '
        'take over again', (tester) async {
      var dismissed = 0;
      var tookOver = 0;
      await tester.pumpWidget(
        _app(
          BotScreenViewerPhase.live,
          control: BotScreenControl.lost,
          onTakeOver: () => tookOver++,
          onDismissLost: () => dismissed++,
        ),
      );

      expect(find.text('Someone else took control.'), findsOne);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.tap(find.text('Take over'));

      expect((dismissed, tookOver), (1, 1));
    });

    testWidgets('the lost notice is worded from who has the screen, also '
        'while the picture is blanked', (tester) async {
      await tester.pumpWidget(
        _app(
          BotScreenViewerPhase.blanked,
          picture: false,
          control: BotScreenControl.lost,
          lostText: 'Hermes took control back.',
        ),
      );

      expect(find.text('Hermes took control back.'), findsOne);
      expect(find.text('Someone else took control.'), findsNothing);
    });

    testWidgets('a hand back on its way shows Handing back, disabled, and '
        'still says this device is in control', (tester) async {
      await tester.pumpWidget(
        _app(
          BotScreenViewerPhase.live,
          control: BotScreenControl.releasing,
          onHandBack: () => fail('pressed'),
        ),
      );

      expect(find.text("You're in control"), findsOne);
      expect(find.text('Hand Back'), findsNothing);
      await tester.tap(find.text('Handing back…'));
    });

    testWidgets('someone else in control offers Hand back to Hermes only '
        'when it can be forced', (tester) async {
      var forced = 0;
      await tester.pumpWidget(
        _app(
          BotScreenViewerPhase.blanked,
          picture: false,
          canForce: true,
          onForceHandBack: () => forced++,
        ),
      );

      expect(find.text('Someone else is in control'), findsWidgets);
      await tester.tap(find.text('Hand back to Hermes'));
      expect(forced, 1);

      await tester.pumpWidget(
        _app(
          BotScreenViewerPhase.blanked,
          picture: false,
          onForceHandBack: () {},
        ),
      );
      expect(find.text('Hand back to Hermes'), findsNothing);

      await tester.pumpWidget(
        _app(BotScreenViewerPhase.blanked, picture: false, canForce: true),
      );
      expect(find.text('Hand back to Hermes'), findsNothing);
    });

    testWidgets('the header fits a narrow phone with a long profile name on '
        'every platform', (tester) async {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.macOS,
      ]) {
        for (final control in [
          BotScreenControl.watching,
          BotScreenControl.acquiring,
          BotScreenControl.inControl,
        ]) {
          await tester.pumpWidget(
            _app(
              BotScreenViewerPhase.live,
              platform: platform,
              size: const Size(320, 640),
              control: control,
              profile: 'a-very-long-profile-name-for-the-research-bot',
              onTakeOver: () {},
              onHandBack: () {},
              onClose: () {},
            ),
          );
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull, reason: '$platform $control');
        }
      }
    });
  });
}
