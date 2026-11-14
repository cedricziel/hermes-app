import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/voice/widgets/hands_free_strip.dart';

import 'voice_call_widgets_support.dart';

void main() {
  const words = {
    HandsFreeMicrophone.open: 'Hands-free on · microphone open',
    HandsFreeMicrophone.paused: 'Hands-free on · microphone paused',
    HandsFreeMicrophone.muted: 'Hands-free on · microphone muted',
    HandsFreeMicrophone.opening: 'Hands-free on · microphone opening',
  };

  for (final MapEntry(key: mic, value: text) in words.entries) {
    testWidgets('${mic.name} says so in words', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpVoice(tester, HandsFreeStrip(microphone: mic, onEnd: () {}));
        expect(find.text(text, findRichText: true), findsOneWidget);
        expect(
          find.bySemanticsLabel(text.replaceFirst(' · ', ', ')),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('End is a 44 pt target named "End call" and fires', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var ended = 0;
      await pumpVoice(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: HandsFreeStrip(
            microphone: HandsFreeMicrophone.open,
            onEnd: () => ended++,
          ),
        ),
      );
      final end = find.byType(TextButton);
      final size = tester.getSize(end);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('End call'), findsOneWidget);
      await tester.tap(end);
      expect(ended, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('no End action without onEnd', (tester) async {
    await pumpVoice(
      tester,
      const HandsFreeStrip(microphone: HandsFreeMicrophone.open),
    );
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('End'), findsNothing);
  });

  testWidgets('at 2x text it drops the second half but keeps the dot and End', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpVoice(
        tester,
        HandsFreeStrip(microphone: HandsFreeMicrophone.muted, onEnd: () {}),
        scale: 2,
      );
      expect(find.text('Hands-free on', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('microphone', findRichText: true),
        findsNothing,
      );
      expect(find.byType(TextButton), findsOneWidget);
      // A screen reader still hears the microphone state.
      expect(
        find.bySemanticsLabel('Hands-free on, microphone muted'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('wraps at most to a few lines at 1.5x text on a phone', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: HandsFreeStrip(
          microphone: HandsFreeMicrophone.opening,
          onEnd: () {},
        ),
      ),
      scale: 1.5,
      size: const Size(360, 700),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(HandsFreeStrip)).height, lessThan(140));
  });

  testWidgets('each state has its own glyph, also without the second half', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      const HandsFreeStrip(microphone: HandsFreeMicrophone.muted),
      scale: 2,
    );
    expect(find.byIcon(AppIcons.micOff.material), findsOneWidget);
    await pumpVoice(
      tester,
      const HandsFreeStrip(microphone: HandsFreeMicrophone.paused),
      scale: 2,
    );
    expect(find.byIcon(AppIcons.pause.material), findsOneWidget);
  });

  testWidgets('German states wrap instead of cutting words at 390 pt', (
    tester,
  ) async {
    for (final mic in HandsFreeMicrophone.values) {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: HandsFreeStrip(microphone: mic, onEnd: () {}),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(HandsFreeStrip),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      final render = tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byType(HandsFreeStrip),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(render.didExceedMaxLines, isFalse);
      expect(
        find.textContaining('Freihändig an', findRichText: true),
        findsOneWidget,
      );
    }
  });
}
