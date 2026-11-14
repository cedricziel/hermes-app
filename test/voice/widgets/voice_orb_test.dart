import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/voice/widgets/voice_orb.dart';

import 'voice_call_widgets_support.dart';

void main() {
  const icons = {
    VoiceOrbState.listening: AppIcons.mic,
    VoiceOrbState.muted: AppIcons.micOff,
    VoiceOrbState.sending: AppIcons.sendArrow,
    VoiceOrbState.thinking: AppIcons.more,
    VoiceOrbState.speaking: AppIcons.speaker,
    VoiceOrbState.waiting: AppIcons.chat,
    VoiceOrbState.stopped: AppIcons.stopRecording,
  };

  for (final MapEntry(key: state, value: icon) in icons.entries) {
    testWidgets('${state.name} shows its own icon at 48 pt', (tester) async {
      await pumpVoice(tester, Center(child: VoiceOrb(state: state)));
      final shown = tester.widget<Icon>(find.byIcon(icon.material));
      expect(shown.size, 48);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('connecting shows a spinner and the orb is 112 pt', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      const Center(child: VoiceOrb(state: VoiceOrbState.connecting)),
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    final disc = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 112 && w.height == 112,
    );
    expect(disc, findsOneWidget);
  });

  testWidgets('a stopped orb after End shows a check, not the stop square', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      const Center(
        child: VoiceOrb(state: VoiceOrbState.stopped, stoppedCheck: true),
      ),
    );
    expect(find.byIcon(AppIcons.check.material), findsOneWidget);
    expect(find.byIcon(AppIcons.stopRecording.material), findsNothing);
  });

  testWidgets('only speaking with onTap is a button, named for interrupting', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var taps = 0;
      for (final state in VoiceOrbState.values) {
        await pumpVoice(
          tester,
          Center(
            child: VoiceOrb(state: state, onTap: () => taps++),
          ),
        );
        final named = find.bySemanticsLabel('Interrupt the assistant');
        if (state == VoiceOrbState.speaking) {
          expect(named, findsOneWidget);
          expect(tester.getSemantics(named).flagsCollection.isButton, isTrue);
          await tester.tap(find.byType(VoiceOrb));
          expect(taps, 1);
        } else {
          expect(named, findsNothing);
          final before = taps;
          await tester.tap(find.byType(VoiceOrb), warnIfMissed: false);
          expect(taps, before, reason: '${state.name} must not be a target');
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('speaking without onTap is inert', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpVoice(
        tester,
        const Center(child: VoiceOrb(state: VoiceOrbState.speaking)),
      );
      expect(find.bySemanticsLabel('Interrupt the assistant'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('without an amplitude no rings are drawn', (tester) async {
    for (final state in [VoiceOrbState.listening, VoiceOrbState.speaking]) {
      await pumpVoice(tester, Center(child: VoiceOrb(state: state)));
      expect(find.byType(AnimatedContainer), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && (w.width ?? 0) > 112 && w.width! < 168,
        ),
        findsNothing,
        reason: state.name,
      );
    }
    await pumpVoice(
      tester,
      const Center(
        child: VoiceOrb(state: VoiceOrbState.listening, amplitude: 0),
      ),
    );
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
  });

  testWidgets('the level rings follow the amplitude', (tester) async {
    Future<double> outer(double level) async {
      await pumpVoice(
        tester,
        Center(
          child: VoiceOrb(state: VoiceOrbState.listening, amplitude: level),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      return tester.getSize(find.byType(AnimatedContainer).first).width;
    }

    final quiet = await outer(0);
    final loud = await outer(1);
    expect(loud, greaterThan(quiet));
    expect(quiet, greaterThan(112));
  });

  for (final system in [false, true]) {
    testWidgets(
      'reduce motion (${system ? 'system' : 'flag'}) keeps rings and spinner '
      'still',
      (tester) async {
        await pumpVoice(
          tester,
          Center(
            child: VoiceOrb(
              state: VoiceOrbState.listening,
              amplitude: 1,
              reduceMotion: !system,
            ),
          ),
          disableAnimations: system,
        );
        expect(find.byType(AnimatedContainer), findsNothing);
        final ring = tester.getSize(
          find
              .byWidgetPredicate(
                (w) => w is SizedBox && (w.width ?? 0) > 112 && w.width! < 168,
              )
              .first,
        );
        // Full level changes nothing under reduce motion.
        await pumpVoice(
          tester,
          Center(
            child: VoiceOrb(
              state: VoiceOrbState.listening,
              amplitude: 0,
              reduceMotion: !system,
            ),
          ),
          disableAnimations: system,
        );
        expect(
          tester.getSize(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is SizedBox && (w.width ?? 0) > 112 && w.width! < 168,
                )
                .first,
          ),
          ring,
        );
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  }

  testWidgets('a still spinner runs no animation', (tester) async {
    await pumpVoice(
      tester,
      const Center(
        child: VoiceOrb(state: VoiceOrbState.connecting, reduceMotion: true),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('every state builds at text ${scale}x without overflow', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        for (final state in VoiceOrbState.values) {
          await pumpVoice(
            tester,
            Center(child: VoiceOrb(state: state, amplitude: 0.7)),
            scale: scale,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          // The orb does not grow with the text.
          expect(tester.getSize(find.byType(VoiceOrb)), const Size(168, 168));
        }
      }
    });
  }
}
