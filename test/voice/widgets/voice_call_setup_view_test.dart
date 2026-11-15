import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_readiness.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_footer.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_setup_view.dart';

import 'voice_call_widgets_support.dart';

const _ready = CallReadiness([
  CallCheck(CallCheckId.microphone, CallCheckStatus.ready, 'Allowed.'),
  CallCheck(CallCheckId.input, CallCheckStatus.ready, 'Ready.'),
  CallCheck(CallCheckId.output, CallCheckStatus.ready, 'Configured.'),
  CallCheck(CallCheckId.voiceModel, CallCheckStatus.ready, 'Follows main.'),
  CallCheck(CallCheckId.connection, CallCheckStatus.ready, 'Reachable.'),
]);

Widget _view({
  CallReadiness readiness = _ready,
  bool consentMode = true,
  bool gptLive = false,
  VoiceCallFooter footer = VoiceCallFooter.none,
  VoidCallback? onStart,
  VoidCallback? onUseDictation,
  bool initial = false,
}) {
  var on = initial;
  return StatefulBuilder(
    builder: (context, setState) => VoiceCallSetupView(
      readiness: readiness,
      consented: on,
      onConsentChanged: consentMode ? (v) => setState(() => on = v) : null,
      gptLiveNote: gptLive,
      footer: footer,
      onUseDictation: onUseDictation,
      onClose: () {},
      onRetry: () {},
      onStart: onStart ?? () {},
    ),
  );
}

void main() {
  testWidgets('Start call stays disabled until the consent switch is on', (
    tester,
  ) async {
    var starts = 0;
    await pumpVoice(tester, _view(onStart: () => starts++));
    FilledButton start() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start call'),
    );
    expect(start().onPressed, isNull);
    expect(
      find.text(
        'Turn on the switch to start. Nothing is recorded until you do.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Start call'), warnIfMissed: false);
    expect(starts, 0);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(start().onPressed, isNotNull);
    expect(find.text('You can end the call at any moment.'), findsOneWidget);
    await tester.tap(find.text('Start call'));
    expect(starts, 1);
    // Turning it off again disables Start again.
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(start().onPressed, isNull);
  });

  testWidgets('without onConsentChanged there is no consent row and Start is '
      'enabled as before', (tester) async {
    var starts = 0;
    await pumpVoice(tester, _view(consentMode: false, onStart: () => starts++));
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.text('Start call'));
    expect(starts, 1);
  });

  testWidgets('not-ready screens have no consent row and no Start call', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      _view(
        readiness: const CallReadiness([
          CallCheck(
            CallCheckId.output,
            CallCheckStatus.needsSetup,
            'No provider.',
            action: CallSetupAction.hermes,
          ),
        ]),
      ),
    );
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Start call'), findsNothing);
    expect(find.text('Spoken replies'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('GPT-Live note, dictation action and footers', (tester) async {
    var dictation = 0;
    await pumpVoice(
      tester,
      _view(
        gptLive: true,
        onUseDictation: () => dictation++,
        footer: VoiceCallFooter.desktopHide,
      ),
    );
    expect(find.textContaining('This profile uses GPT-Live'), findsOneWidget);
    expect(
      find.text('The call ends if you hide or minimise Hermes.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Use dictation instead'));
    expect(dictation, 1);

    await pumpVoice(tester, _view(footer: VoiceCallFooter.androidLeave));
    expect(find.text('The call ends if you leave Hermes.'), findsOneWidget);
    expect(find.text('Use dictation instead'), findsNothing);
    await pumpVoice(tester, _view());
    expect(find.textContaining('The call ends if'), findsNothing);
  });

  testWidgets('at 2x text the body scrolls and consent and Start stay pinned', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      _view(gptLive: true, footer: VoiceCallFooter.androidLeave),
      scale: 2,
      size: const Size(390, 1000),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Hermes sends each thing you say'),
      findsOneWidget,
    );
    final scrollable = find.byType(Scrollable).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));

    Rect rect(String text) => tester.getRect(find.text(text));
    final switchBefore = tester.getRect(find.byType(Switch));
    final startBefore = rect('Start call');
    expect(startBefore.bottom, lessThanOrEqualTo(1000));
    expect(switchBefore.bottom, lessThanOrEqualTo(1000));

    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pump();
    expect(position.pixels, greaterThan(0));
    expect(rect('Start call'), startBefore);
    expect(tester.getRect(find.byType(Switch)), switchBefore);
    // The cancel action scrolled away with the body.
    expect(rect('Cancel').bottom, lessThan(0));
  });

  testWidgets('pinned part is capped and scrolls on a very short window', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      _view(footer: VoiceCallFooter.androidLeave, onUseDictation: () {}),
      scale: 2,
      size: const Size(360, 500),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('checking and busy states build without a bounded height', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      SingleChildScrollView(
        child: VoiceCallSetupView(
          readiness: CallReadiness.checking,
          onClose: () {},
          onRetry: () {},
          onStart: () {},
        ),
      ),
    );
    expect(find.text('Getting your call ready'), findsOneWidget);
    expect(find.text('Start call'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    for (final size in [const Size(390, 844), const Size(480, 700)]) {
      testWidgets(
        'builds at ${scale}x, ${size.width.toInt()} pt, both themes',
        (tester) async {
          for (final dark in [false, true]) {
            await pumpVoice(
              tester,
              _view(
                gptLive: true,
                footer: VoiceCallFooter.desktopHide,
                onUseDictation: () {},
              ),
              scale: scale,
              size: size,
              dark: dark,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  testWidgets('a voice model row says its own words, not the English detail', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      _view(
        readiness: const CallReadiness([
          CallCheck(CallCheckId.microphone, CallCheckStatus.ready, 'Allowed.'),
          CallCheck(CallCheckId.input, CallCheckStatus.ready, 'Ready.'),
          CallCheck(CallCheckId.output, CallCheckStatus.ready, 'Configured.'),
          CallCheck(
            CallCheckId.voiceModel,
            CallCheckStatus.warning,
            'English detail for the agent.',
            code: CallDetail.voiceModelUnresolved,
          ),
          CallCheck(
            CallCheckId.connection,
            CallCheckStatus.ready,
            'Reachable.',
          ),
        ]),
      ),
    );
    expect(find.text('English detail for the agent.'), findsNothing);
    expect(
      find.text(
        'Hermes has no model set for voice replies. The call can still start.',
      ),
      findsOneWidget,
    );
    expect(find.text('Start call'), findsOneWidget, reason: 'a warning allows');
  });
}
