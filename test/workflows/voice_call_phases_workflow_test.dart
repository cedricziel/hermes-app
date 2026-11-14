import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_footer.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_notice.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';

import '../support/screenshot_recorder.dart';

typedef _Step = ({
  String name,
  CallPhase phase,
  bool muted,
  bool sending,
  String caption,
  String? error,
  bool endedByUser,
  bool notice,
});

_Step _step(
  String name,
  CallPhase phase, {
  bool muted = false,
  bool sending = false,
  String caption = '',
  String? error,
  bool endedByUser = false,
  bool notice = false,
}) => (
  name: name,
  phase: phase,
  muted: muted,
  sending: sending,
  caption: caption,
  error: error,
  endedByUser: endedByUser,
  notice: notice,
);

final _steps = <_Step>[
  _step('connecting', CallPhase.connecting),
  _step('listening', CallPhase.listening),
  _step(
    'listening-caption',
    CallPhase.listening,
    caption: 'Could you check the third paragraph of the report for me?',
  ),
  _step('muted', CallPhase.listening, muted: true),
  _step(
    'sending',
    CallPhase.transcribing,
    sending: true,
    caption: 'Could you check the third paragraph of the report for me?',
  ),
  _step('thinking', CallPhase.thinking),
  _step(
    'speaking',
    CallPhase.speaking,
    caption: 'The numbers add up once the correction is applied.',
  ),
  _step('waiting', CallPhase.attention),
  _step('notice-while-listening', CallPhase.listening, notice: true),
  _step('ended', CallPhase.ended, endedByUser: true),
  _step(
    'failed',
    CallPhase.failed,
    error: 'The call was interrupted.',
    notice: true,
  ),
];

void main() {
  const extra = <(String, Size)>[
    ('short-phone', Size(390, 667)),
    ('landscape', Size(844, 390)),
  ];
  for (final (name, size) in extra) {
    testWidgets('call screen in every phase, $name', (tester) async {
      final shots = ScreenshotRecorder('voice-call-$name-light');
      await shots.start(tester, size);
      final theme = withScreenshotFont(
        buildHermesLightTheme(platform: TargetPlatform.iOS),
      );
      Offset? end;
      for (final s in _steps) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: shots.frame(
              Scaffold(
                body: VoiceCallView(
                  phase: s.phase,
                  elapsed: const Duration(seconds: 75),
                  muted: s.muted,
                  speaker: false,
                  route: 'iPhone',
                  caption: s.caption,
                  error: s.error,
                  sending: s.sending,
                  endedByUser: s.endedByUser,
                  onInterrupt: s.phase == CallPhase.speaking ? () {} : null,
                  onStartNew: s.phase == CallPhase.ended ? () {} : null,
                  notice: s.notice
                      ? const VoiceCallNotice(
                          tone: VoiceCallNoticeTone.warning,
                          title: "Couldn't send. Nothing was sent.",
                          detail: 'Your words are not in the chat.',
                        )
                      : null,
                  onMute: () {},
                  onSpeaker: () {},
                  onEnd: () {},
                  onShowChat: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: s.name);
        await shots.capture(tester, s.name);
        final ended = s.phase == CallPhase.ended || s.phase == CallPhase.failed;
        if (!ended && s.phase != CallPhase.connecting) {
          final at = tester.getTopLeft(find.bySemanticsLabel('End call'));
          end ??= at;
          expect(at, end, reason: 'End moved in ${s.name}');
        }
      }
    });
  }
  for (final desktop in [false, true]) {
    for (final dark in [false, true]) {
      final label =
          '${desktop ? 'desktop' : 'phone'}-${dark ? 'dark' : 'light'}';
      testWidgets('call screen in every phase, $label', (tester) async {
        final platform = desktop ? TargetPlatform.macOS : TargetPlatform.iOS;
        final shots = ScreenshotRecorder('voice-call-$label');
        await shots.start(tester, desktop ? desktopSize : phoneSize);
        final theme = withScreenshotFont(
          dark
              ? buildHermesDarkTheme(platform: platform)
              : buildHermesLightTheme(platform: platform),
        );
        Offset? end;
        for (final s in _steps) {
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: shots.frame(
                Scaffold(
                  body: VoiceCallView(
                    phase: s.phase,
                    elapsed: const Duration(seconds: 75),
                    muted: s.muted,
                    speaker: false,
                    route: desktop ? 'MacBook Pro Microphone' : 'iPhone',
                    caption: s.caption,
                    error: s.error,
                    sending: s.sending,
                    showSpeaker: !desktop,
                    endedByUser: s.endedByUser,
                    stoppedWord: false,
                    onInterrupt: s.phase == CallPhase.speaking ? () {} : null,
                    onStartNew: s.phase == CallPhase.ended ? () {} : null,
                    onAskHermes: s.error != null ? () {} : null,
                    footer: desktop
                        ? VoiceCallFooter.desktopHide
                        : VoiceCallFooter.none,
                    notice: s.notice
                        ? const VoiceCallNotice(
                            tone: VoiceCallNoticeTone.warning,
                            title: "Couldn't send. Nothing was sent.",
                            detail: 'Your words are not in the chat.',
                          )
                        : null,
                    onMute: () {},
                    onSpeaker: () {},
                    onEnd: () {},
                    onShowChat: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: s.name);
          await shots.capture(tester, s.name);
          final ended =
              s.phase == CallPhase.ended || s.phase == CallPhase.failed;
          if (!ended && s.phase != CallPhase.connecting) {
            final at = tester.getTopLeft(find.bySemanticsLabel('End call'));
            end ??= at;
            expect(at, end, reason: 'End moved in ${s.name}');
          }
        }
      });
    }
  }
}
