import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('stays one line at 1.5x text on a phone', (tester) async {
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
    expect(tester.getSize(find.byType(HandsFreeStrip)).height, lessThan(60));
  });
}
