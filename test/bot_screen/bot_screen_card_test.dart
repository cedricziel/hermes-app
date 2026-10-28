import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

// A 1x1 PNG, which Image.memory decodes like any picture.
final _picture = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg==',
  ),
);

Future<void> pumpCard(
  WidgetTester tester,
  BotScreenCardModel model, {
  VoidCallback? onStart,
  VoidCallback? onCopyCommand,
  VoidCallback? onRetry,
  VoidCallback? onEnlarge,
  Breadcrumbs breadcrumbs = Breadcrumbs.none,
  BotScreenShown? shown,
  TargetPlatform platform = TargetPlatform.android,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(platform: platform),
    home: Scaffold(
      body: SingleChildScrollView(
        child: BotScreenCard(
          model: model,
          onStart: onStart,
          onCopyCommand: onCopyCommand,
          onRetry: onRetry,
          onEnlarge: onEnlarge,
          breadcrumbs: breadcrumbs,
          shown: shown,
        ),
      ),
    ),
  ),
);

void main() {
  group('states', () {
    testWidgets('not offered says Hermes uses the server\'s own display and '
        'offers no action', (tester) async {
      await pumpCard(tester, const BotScreenNotOffered());

      expect(find.text("Hermes uses this server's own display."), findsOne);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('not installed shows the command and copies it', (
      tester,
    ) async {
      var copied = 0;
      await pumpCard(
        tester,
        const BotScreenNotInstalled(command: 'hermes computer-use install'),
        onCopyCommand: () => copied++,
      );

      expect(find.text('hermes computer-use install'), findsOne);
      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(copied, 1);
      expect(find.text('Copied'), findsOne);
    });

    testWidgets('not installed in a sandbox names the image and shows no '
        'command or Copy', (tester) async {
      await pumpCard(
        tester,
        const BotScreenNotInstalled(sandbox: true),
        onCopyCommand: () {},
      );

      expect(find.textContaining('sandbox image'), findsOne);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('blocked shows the server\'s text and the free memory', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const BotScreenBlocked(text: 'Not enough memory', memoryMb: 312),
      );

      expect(find.text('Not enough memory'), findsOne);
      expect(find.text('312 MB of memory available'), findsOne);
    });

    testWidgets('blocked without a figure shows no memory line', (
      tester,
    ) async {
      await pumpCard(tester, const BotScreenBlocked(text: 'Not enough memory'));

      expect(find.textContaining('MB'), findsNothing);
    });

    testWidgets('starting shows progress and no Start Screen', (tester) async {
      await pumpCard(tester, const BotScreenStarting(), onStart: () {});

      expect(find.text('Starting the screen…'), findsOne);
      expect(find.text('Start Screen'), findsNothing);
    });

    testWidgets('starting draws the activity indicator of Apple platforms', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const BotScreenStarting(),
        platform: TargetPlatform.iOS,
      );

      expect(find.byType(CupertinoActivityIndicator), findsOne);
    });

    testWidgets('starting draws the Material ring elsewhere', (tester) async {
      await pumpCard(tester, const BotScreenStarting());

      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOne);
    });

    testWidgets('Copied goes back to Copy after two seconds', (tester) async {
      await pumpCard(
        tester,
        const BotScreenNotInstalled(command: 'hermes computer-use install'),
        onCopyCommand: () {},
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(find.text('Copied'), findsOne);
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Copy'), findsOne);
      expect(find.text('Copied'), findsNothing);
    });

    testWidgets('the Copy button is named for what it copies', (tester) async {
      await pumpCard(
        tester,
        const BotScreenNotInstalled(command: 'hermes computer-use install'),
        onCopyCommand: () {},
      );

      expect(find.bySemanticsLabel('Copy install command'), findsOne);
    });

    testWidgets('off explains and starts', (tester) async {
      var started = 0;
      await pumpCard(tester, const BotScreenOff(), onStart: () => started++);

      expect(
        find.text(
          'The screen is off. It starts by itself when Hermes needs it.',
        ),
        findsOne,
      );
      await tester.tap(find.text('Start Screen'));

      expect(started, 1);
    });

    testWidgets('off after a failed start says why', (tester) async {
      await pumpCard(
        tester,
        const BotScreenOff(startFailure: BotScreenFailure.timeout),
        onStart: () {},
      );

      expect(find.text("Couldn't start the screen."), findsOne);
      expect(find.text('Hermes did not answer in time.'), findsOne);
    });

    testWidgets('error offers Try Again', (tester) async {
      var retried = 0;
      await pumpCard(
        tester,
        const BotScreenReadFailed(),
        onRetry: () => retried++,
      );

      expect(find.text("Couldn't read the screen"), findsOne);
      await tester.tap(find.text('Try Again'));

      expect(retried, 1);
    });

    testWidgets('running draws the frame and says Hermes is in control', (
      tester,
    ) async {
      await pumpCard(tester, BotScreenShowing(bytes: _picture, aspectRatio: 2));

      expect(find.byType(Image), findsOne);
      expect(find.text('Hermes is in control'), findsOne);
      final box = tester.getSize(find.byType(AspectRatio));
      expect(box.width / box.height, closeTo(2, 0.01));
    });

    testWidgets('running without a frame yet draws no picture', (tester) async {
      await pumpCard(tester, const BotScreenShowing());

      expect(find.byType(Image), findsNothing);
      expect(find.text('Hermes is in control'), findsOne);
    });

    testWidgets('someone else in control draws no picture', (tester) async {
      await pumpCard(tester, const BotScreenControlled());

      expect(find.byType(Image), findsNothing);
      expect(find.text('Someone else is in control'), findsOne);
    });

    testWidgets('you in control draws no picture and says so', (tester) async {
      await pumpCard(tester, const BotScreenControlled(byYou: true));

      expect(find.byType(Image), findsNothing);
      expect(find.text("You're in control"), findsOne);
    });

    testWidgets('a picture that cannot be decoded does not throw', (
      tester,
    ) async {
      await pumpCard(
        tester,
        BotScreenShowing(bytes: Uint8List.fromList([1, 2, 3])),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('every action is labelled and has a big enough target', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final model in <BotScreenCardModel>[
          const BotScreenNotInstalled(command: 'hermes computer-use install'),
          const BotScreenOff(),
          const BotScreenReadFailed(),
          BotScreenShowing(bytes: _picture),
        ]) {
          await pumpCard(
            tester,
            model,
            platform: platform,
            onStart: () {},
            onCopyCommand: () {},
            onRetry: () {},
            onEnlarge: () {},
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
      }
      handle.dispose();
    });

    testWidgets('the picture is an image named for the screen', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, BotScreenShowing(bytes: _picture));

      final node = tester.getSemantics(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Hermes's screen",
        ),
      );

      expect(node.label, contains("Hermes's screen"));
      expect(node.getSemanticsData().flagsCollection.isImage, isTrue);
      handle.dispose();
    });
  });

  group('Enlarge', () {
    testWidgets('is hidden without a viewer to open', (tester) async {
      await pumpCard(tester, BotScreenShowing(bytes: _picture));

      expect(find.bySemanticsLabel('Enlarge screen'), findsNothing);
    });

    testWidgets('shows and opens the viewer when there is one', (tester) async {
      var enlarged = 0;
      await pumpCard(
        tester,
        BotScreenShowing(bytes: _picture),
        onEnlarge: () => enlarged++,
      );

      await tester.tap(find.byTooltip('Enlarge screen'));

      expect(enlarged, 1);
    });

    testWidgets('is not offered when a person is in control', (tester) async {
      await pumpCard(tester, const BotScreenControlled(), onEnlarge: () {});

      expect(find.byTooltip('Enlarge screen'), findsNothing);
    });
  });

  group('breadcrumbs', () {
    List<String> crumbs(BreadcrumbTrail trail) => [
      for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}',
    ];

    testWidgets('record each state once, not each refreshed frame', (
      tester,
    ) async {
      final trail = BreadcrumbTrail();
      final breadcrumbs = Breadcrumbs.of(trail);
      await pumpCard(
        tester,
        BotScreenShowing(bytes: _picture),
        breadcrumbs: breadcrumbs,
      );
      await pumpCard(
        tester,
        BotScreenShowing(bytes: Uint8List.fromList(_picture)),
        breadcrumbs: breadcrumbs,
      );
      await pumpCard(
        tester,
        const BotScreenControlled(),
        breadcrumbs: breadcrumbs,
      );
      await pumpCard(
        tester,
        BotScreenShowing(bytes: _picture),
        breadcrumbs: breadcrumbs,
      );

      expect(crumbs(trail), [
        'bot_screen.card.shown {state: frame}',
        'bot_screen.card.shown {state: controlled}',
        'bot_screen.card.shown {state: frame}',
      ]);
    });

    testWidgets('are not repeated by a new card showing the same state', (
      tester,
    ) async {
      final trail = BreadcrumbTrail();
      final breadcrumbs = Breadcrumbs.of(trail);
      final shown = BotScreenShown();

      for (var i = 0; i < 3; i++) {
        await pumpCard(
          tester,
          const BotScreenOff(),
          breadcrumbs: breadcrumbs,
          shown: shown,
        );
        await tester.pumpWidget(const SizedBox());
      }
      await pumpCard(
        tester,
        const BotScreenReadFailed(),
        breadcrumbs: breadcrumbs,
        shown: shown,
      );

      expect(crumbs(trail), [
        'bot_screen.card.shown {state: off}',
        'bot_screen.card.shown {state: error}',
      ]);
    });

    testWidgets('use a fixed word for every state', (tester) async {
      final trail = BreadcrumbTrail();
      final breadcrumbs = Breadcrumbs.of(trail);
      for (final model in <BotScreenCardModel>[
        const BotScreenNotOffered(),
        const BotScreenNotInstalled(command: 'secret command'),
        const BotScreenBlocked(text: 'secret blocker'),
        const BotScreenStarting(),
        const BotScreenOff(),
        const BotScreenReadFailed(),
      ]) {
        await pumpCard(tester, model, breadcrumbs: breadcrumbs);
      }

      expect(crumbs(trail), [
        'bot_screen.card.shown {state: not_offered}',
        'bot_screen.card.shown {state: not_installed}',
        'bot_screen.card.shown {state: blocked}',
        'bot_screen.card.shown {state: starting}',
        'bot_screen.card.shown {state: off}',
        'bot_screen.card.shown {state: error}',
      ]);
    });

    testWidgets('Start Screen records a crumb with no attributes', (
      tester,
    ) async {
      final trail = BreadcrumbTrail();
      await pumpCard(
        tester,
        const BotScreenOff(),
        onStart: () {},
        breadcrumbs: Breadcrumbs.of(trail),
      );

      await tester.tap(find.text('Start Screen'));

      expect(crumbs(trail), [
        'bot_screen.card.shown {state: off}',
        'bot_screen.start.pressed {}',
      ]);
    });
  });

  group('on each platform', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      testWidgets('builds every state on $platform', (tester) async {
        for (final model in <BotScreenCardModel>[
          const BotScreenNotOffered(),
          const BotScreenNotInstalled(command: 'hermes computer-use install'),
          const BotScreenBlocked(text: 'No memory', memoryMb: 100),
          const BotScreenStarting(),
          const BotScreenOff(startFailure: BotScreenFailure.display),
          const BotScreenReadFailed(),
          BotScreenShowing(bytes: _picture),
          const BotScreenControlled(),
        ]) {
          await pumpCard(
            tester,
            model,
            platform: platform,
            onStart: () {},
            onCopyCommand: () {},
            onRetry: () {},
            onEnlarge: () {},
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
