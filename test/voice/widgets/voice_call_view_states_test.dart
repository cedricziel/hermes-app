import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/widgets/named_icon_button.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_footer.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_notice.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';
import 'package:hermes_app/src/voice/widgets/voice_orb.dart';

import 'voice_call_widgets_support.dart';

VoiceCallView _view({
  CallPhase phase = CallPhase.listening,
  bool muted = false,
  bool sending = false,
  bool showSpeaker = true,
  VoiceSpeakingHint hint = VoiceSpeakingHint.tapOrTalk,
  Widget? notice,
  bool endedByUser = false,
  bool capturePaused = false,
  bool stoppedWord = false,
  VoidCallback? onStartNew,
  VoidCallback? onInterrupt,
  VoidCallback? onEnd,
  VoiceCallFooter footer = VoiceCallFooter.none,
  String? error,
  VoidCallback? onAskHermes,
}) => VoiceCallView(
  phase: phase,
  elapsed: const Duration(seconds: 75),
  muted: muted,
  speaker: false,
  route: 'iPhone',
  sending: sending,
  showSpeaker: showSpeaker,
  speakingHint: hint,
  notice: notice,
  endedByUser: endedByUser,
  capturePaused: capturePaused,
  stoppedWord: stoppedWord,
  onStartNew: onStartNew,
  onInterrupt: onInterrupt,
  footer: footer,
  error: error,
  onAskHermes: onAskHermes,
  onMute: () {},
  onSpeaker: () {},
  onEnd: onEnd ?? () {},
  onShowChat: () {},
);

VoiceOrbState _orb(WidgetTester tester) =>
    tester.widget<VoiceOrb>(find.byType(VoiceOrb)).state;

void main() {
  testWidgets('each phase shows its word, orb state and hint', (tester) async {
    final cases = <(CallPhase, bool, bool, VoiceOrbState, String, String?)>[
      (
        CallPhase.connecting,
        false,
        false,
        VoiceOrbState.connecting,
        'Connecting…',
        null,
      ),
      (
        CallPhase.listening,
        false,
        false,
        VoiceOrbState.listening,
        'Listening',
        'Speak, then pause. Hermes sends what you said.',
      ),
      (
        CallPhase.listening,
        true,
        false,
        VoiceOrbState.muted,
        'Muted',
        'Nothing is captured or sent. Unmute to talk.',
      ),
      (
        CallPhase.sending,
        false,
        false,
        VoiceOrbState.sending,
        'Sending',
        'Hermes is getting your words ready. End or mute now to cancel.',
      ),
      (
        CallPhase.thinking,
        false,
        false,
        VoiceOrbState.thinking,
        'Thinking',
        'Hermes is working on your request.',
      ),
      (
        CallPhase.speaking,
        false,
        false,
        VoiceOrbState.speaking,
        'Speaking',
        'Just talk to interrupt.',
      ),
      (
        CallPhase.attention,
        false,
        false,
        VoiceOrbState.waiting,
        'Waiting for you',
        'Hermes needs your input in chat.',
      ),
    ];
    for (final (phase, muted, sending, orb, word, hint) in cases) {
      await pumpVoice(
        tester,
        _view(phase: phase, muted: muted, sending: sending),
      );
      expect(_orb(tester), orb, reason: '$phase muted=$muted');
      expect(find.text(word), findsOneWidget, reason: '$phase');
      if (hint != null) expect(find.text(hint), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the state word is a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpVoice(tester, _view());
      final node = tester.getSemantics(find.text('Listening'));
      expect(node.flagsCollection.isLiveRegion, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('speaking hints follow the platform', (tester) async {
    for (final (hint, text) in [
      (VoiceSpeakingHint.tapOnly, 'Tap the orb to interrupt.'),
      (
        VoiceSpeakingHint.micPaused,
        'Microphone paused while Hermes speaks. Tap the orb to interrupt.',
      ),
    ]) {
      await pumpVoice(tester, _view(phase: CallPhase.speaking, hint: hint));
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('the orb interrupts only while speaking', (tester) async {
    var taps = 0;
    await pumpVoice(
      tester,
      _view(phase: CallPhase.speaking, onInterrupt: () => taps++),
    );
    await tester.tap(find.byType(VoiceOrb));
    expect(taps, 1);
    await pumpVoice(
      tester,
      _view(phase: CallPhase.thinking, onInterrupt: () => taps++),
    );
    await tester.tap(find.byType(VoiceOrb), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('controls are 56 pt circles, End is neutral, never error', (
    tester,
  ) async {
    await pumpVoice(tester, _view(), platform: TargetPlatform.iOS);
    final theme = Theme.of(tester.element(find.byType(VoiceCallView)));
    final buttons = find.byType(NamedIconButton);
    expect(buttons, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      expect(tester.getSize(buttons.at(i)), const Size(56, 56));
    }
    final endBackground = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.byIcon(AppIcons.endCall.apple),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => (d.decoration as BoxDecoration).color)
        .whereType<Color>()
        .first;
    expect(endBackground, theme.colorScheme.inverseSurface);
    expect(endBackground, isNot(theme.colorScheme.error));
    // The labels are shown under the circles.
    for (final label in ['Mute', 'Speaker', 'End call']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('showSpeaker false drops the Speaker control', (tester) async {
    await pumpVoice(tester, _view(showSpeaker: false));
    expect(find.text('Speaker'), findsNothing);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('End call'), findsOneWidget);
  });

  testWidgets('End and Mute fire; Mute is off while connecting', (
    tester,
  ) async {
    var ended = 0;
    await pumpVoice(
      tester,
      _view(phase: CallPhase.connecting, onEnd: () => ended++),
    );
    await tester.tap(find.byIcon(AppIcons.endCall.material));
    expect(ended, 1);
    final mute = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(AppIcons.mic.material),
        matching: find.byType(IconButton),
      ),
    );
    expect(mute.onPressed, isNull);
  });

  testWidgets('a notice slot and the footer show above the controls', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      _view(
        notice: const VoiceCallNotice(
          tone: VoiceCallNoticeTone.warning,
          title: 'Audio route changed. Please repeat if needed.',
        ),
        footer: VoiceCallFooter.androidLeave,
      ),
    );
    expect(find.textContaining('Audio route changed'), findsOneWidget);
    expect(find.text('The call ends if you leave Hermes.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('Audio route')).dy,
      lessThan(tester.getTopLeft(find.text('Mute')).dy),
    );
  });

  testWidgets('stopped: stop square, "Stopped", filled Back to chat', (
    tester,
  ) async {
    var back = 0, again = 0;
    await pumpVoice(
      tester,
      VoiceCallView(
        phase: CallPhase.failed,
        elapsed: Duration.zero,
        muted: false,
        speaker: false,
        route: 'iPhone',
        notice: const VoiceCallNotice(title: 'The microphone is closed.'),
        onStartNew: () => again++,
        onMute: () {},
        onSpeaker: () {},
        onEnd: () {},
        onShowChat: () => back++,
      ),
    );
    expect(_orb(tester), VoiceOrbState.stopped);
    expect(find.byIcon(AppIcons.stopRecording.material), findsOneWidget);
    expect(find.text('Call interrupted'), findsOneWidget);
    expect(find.text('The microphone is closed.'), findsOneWidget);
    expect(find.text('Mute'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Back to chat'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Start a new call'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to chat'));
    await tester.tap(find.text('Start a new call'));
    expect([back, again], [1, 1]);
  });

  testWidgets('the paused-capture hint needs the flag', (tester) async {
    await pumpVoice(
      tester,
      _view(phase: CallPhase.attention, capturePaused: true),
    );
    expect(find.textContaining('Capture is paused'), findsOneWidget);
    await pumpVoice(tester, _view(phase: CallPhase.attention));
    expect(find.textContaining('Capture is paused'), findsNothing);
    expect(find.text('Hermes needs your input in chat.'), findsOneWidget);
  });

  testWidgets('the tap hint needs an interrupt callback', (tester) async {
    await pumpVoice(
      tester,
      _view(phase: CallPhase.speaking, onInterrupt: () {}),
    );
    expect(
      find.text('Tap the orb, or just talk, to interrupt.'),
      findsOneWidget,
    );
  });

  testWidgets('stopped words: ended, interrupted, or Stopped when asked', (
    tester,
  ) async {
    await pumpVoice(tester, _view(phase: CallPhase.ended));
    expect(find.text('Call ended'), findsOneWidget);
    expect(find.byIcon(AppIcons.check.material), findsNothing);
    await pumpVoice(tester, _view(phase: CallPhase.failed));
    expect(find.text('Call interrupted'), findsOneWidget);
    expect(find.byIcon(AppIcons.stopRecording.material), findsOneWidget);
    await pumpVoice(tester, _view(phase: CallPhase.failed, stoppedWord: true));
    expect(find.text('Stopped'), findsOneWidget);
  });

  testWidgets('a selected Mute is ringed and End is the only filled circle', (
    tester,
  ) async {
    await pumpVoice(tester, _view(muted: true));
    final circles = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle)
        .toList();
    final theme = Theme.of(tester.element(find.byType(VoiceCallView)));
    expect(
      circles.where((d) => d.color == theme.colorScheme.inverseSurface),
      hasLength(1),
    );
    expect(circles.where((d) => d.border != null), isNotEmpty);
  });

  testWidgets('the Sending caption is italic', (tester) async {
    await pumpVoice(
      tester,
      VoiceCallView(
        phase: CallPhase.sending,
        caption: 'What is on today?',
        elapsed: Duration.zero,
        muted: false,
        speaker: false,
        route: 'iPhone',
        onMute: () {},
        onSpeaker: () {},
        onEnd: () {},
        onShowChat: () {},
      ),
    );
    expect(
      tester.widget<Text>(find.text('What is on today?')).style?.fontStyle,
      FontStyle.italic,
    );
  });

  testWidgets('ended by the user shows a check and "Call ended"', (
    tester,
  ) async {
    await pumpVoice(tester, _view(phase: CallPhase.ended, endedByUser: true));
    expect(find.byIcon(AppIcons.check.material), findsOneWidget);
    expect(find.text('Call ended'), findsOneWidget);
    expect(find.text('Start a new call'), findsNothing);
  });

  testWidgets('a failed call still offers Ask Hermes for help', (tester) async {
    var asks = 0;
    await pumpVoice(
      tester,
      _view(
        phase: CallPhase.failed,
        error: 'The connection was interrupted.',
        onAskHermes: () => asks++,
      ),
    );
    expect(find.text('The connection was interrupted.'), findsOneWidget);
    await tester.tap(find.text('Ask Hermes for help'));
    expect(asks, 1);
  });

  for (final scale in [1.0, 2.0]) {
    for (final size in [const Size(390, 844), const Size(480, 760)]) {
      testWidgets('every state builds at ${scale}x, ${size.width.toInt()} pt '
          'without overflow', (tester) async {
        for (final dark in [false, true]) {
          for (final (phase, muted, sending) in [
            (CallPhase.connecting, false, false),
            (CallPhase.listening, false, false),
            (CallPhase.listening, true, false),
            (CallPhase.sending, false, false),
            (CallPhase.thinking, false, false),
            (CallPhase.speaking, false, false),
            (CallPhase.attention, false, false),
            (CallPhase.ended, false, false),
            (CallPhase.failed, false, false),
          ]) {
            await pumpVoice(
              tester,
              _view(
                phase: phase,
                muted: muted,
                sending: sending,
                hint: VoiceSpeakingHint.micPaused,
                footer: VoiceCallFooter.desktopHide,
                notice: const VoiceCallNotice(
                  tone: VoiceCallNoticeTone.warning,
                  title: 'The call was interrupted.',
                  detail:
                      'Another call or app took the audio. The microphone is '
                      'closed. Your earlier turns are in the chat.',
                ),
                onStartNew: () {},
              ),
              scale: scale,
              size: size,
              dark: dark,
            );
            expect(tester.takeException(), isNull, reason: '$phase');
          }
        }
      });
    }
  }
}
