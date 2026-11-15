import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/voice/calls/call_readiness.dart';
import 'package:hermes_app/src/voice/widgets/hands_free_strip.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_footer.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_notice.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_setup_view.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';
import 'package:hermes_app/src/voice/widgets/voice_consent_row.dart';
import 'package:hermes_app/src/voice/widgets/voice_orb.dart';
import 'package:hermes_app/src/voice/widgets/voice_turn_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode voiceCallNode() => WidgetbookFolder(
  name: 'Voice call',
  children: [
    _setupNode(),
    _viewNode(),
    _turnListNode(),
    _orbNode(),
    _stripNode(),
    _noticeNode(),
    _consentNode(),
  ],
);

const _micReady = CallCheck(
  CallCheckId.microphone,
  CallCheckStatus.ready,
  'Microphone access is allowed.',
);
const _inputReady = CallCheck(
  CallCheckId.input,
  CallCheckStatus.ready,
  'Apple on-device recognition is ready.',
);
const _outputReady = CallCheck(
  CallCheckId.output,
  CallCheckStatus.ready,
  'Hermes speech output is configured.',
);
const _modelReady = CallCheck(
  CallCheckId.voiceModel,
  CallCheckStatus.ready,
  'Voice replies follow your main model.',
);
const _connectionReady = CallCheck(
  CallCheckId.connection,
  CallCheckStatus.ready,
  'The voice service is reachable.',
);
const _allReady = CallReadiness([
  _micReady,
  _inputReady,
  _outputReady,
  _modelReady,
  _connectionReady,
], useDeviceSpeech: true);

Widget _setup(
  CallReadiness readiness, {
  bool consented = false,
  bool consentRow = true,
  bool gptLive = false,
  VoiceCallFooter footer = VoiceCallFooter.none,
  bool microphoneDenied = false,
  double? width,
}) {
  var on = consented;
  return StatefulBuilder(
    builder: (context, setState) => fill(
      VoiceCallSetupView(
        readiness: readiness,
        consented: on,
        onConsentChanged: consentRow ? (v) => setState(() => on = v) : null,
        gptLiveNote: gptLive,
        footer: footer,
        microphoneDenied: microphoneDenied,
        onUseDictation: () {},
        onClose: () {},
        onRetry: () {},
        onStart: () {},
        onMicrophone: () {},
        onDictation: () {},
        onAskHermes: () {},
      ),
      width: width,
    ),
  );
}

WidgetbookComponent _setupNode() => WidgetbookComponent(
  name: 'VoiceCallSetupView',
  useCases: [
    WidgetbookUseCase(
      name: 'Consent off (Start disabled)',
      builder: (_) => _setup(_allReady),
    ),
    WidgetbookUseCase(
      name: 'Consent on',
      builder: (_) => _setup(_allReady, consented: true),
    ),
    WidgetbookUseCase(
      name: 'GPT-Live note',
      builder: (_) => _setup(_allReady, consented: true, gptLive: true),
    ),
    WidgetbookUseCase(
      name: 'Voice model warning (can still start)',
      builder: (_) => _setup(
        const CallReadiness([
          _micReady,
          _inputReady,
          _outputReady,
          CallCheck(
            CallCheckId.voiceModel,
            CallCheckStatus.warning,
            'Hermes has no model set for voice replies. The call can still start.',
          ),
          _connectionReady,
        ], useDeviceSpeech: true),
      ),
    ),
    WidgetbookUseCase(
      name: 'Speech not set up',
      builder: (_) => _setup(
        const CallReadiness([
          _micReady,
          _inputReady,
          CallCheck(
            CallCheckId.output,
            CallCheckStatus.needsSetup,
            'Your server has no text-to-speech provider with credentials.',
            action: CallSetupAction.hermes,
          ),
          _modelReady,
          _connectionReady,
        ], useDeviceSpeech: true),
      ),
    ),
    WidgetbookUseCase(
      name: 'Android footer',
      builder: (_) => _setup(
        _allReady,
        consented: true,
        footer: VoiceCallFooter.androidLeave,
      ),
    ),
    WidgetbookUseCase(
      name: 'Desktop footer (480 pt dialog)',
      builder: (_) =>
          _setup(_allReady, footer: VoiceCallFooter.desktopHide, width: 480),
    ),
    for (final entry in <String, CallReadiness>{
      'Checking prerequisites': CallReadiness.checking,
      'Ready to call': const CallReadiness([
        CallCheck(
          CallCheckId.microphone,
          CallCheckStatus.ready,
          'Microphone access is allowed.',
        ),
        CallCheck(
          CallCheckId.input,
          CallCheckStatus.ready,
          'Apple on-device recognition is ready.',
        ),
        CallCheck(
          CallCheckId.output,
          CallCheckStatus.ready,
          'Hermes speech output is configured.',
        ),
        CallCheck(
          CallCheckId.voiceModel,
          CallCheckStatus.ready,
          'Voice replies follow your main model.',
        ),
        CallCheck(
          CallCheckId.connection,
          CallCheckStatus.ready,
          'The voice service is reachable.',
        ),
      ], useDeviceSpeech: true),
      'Server setup needed': const CallReadiness([
        CallCheck(
          CallCheckId.microphone,
          CallCheckStatus.ready,
          'Microphone access is allowed.',
        ),
        CallCheck(
          CallCheckId.input,
          CallCheckStatus.ready,
          'Apple on-device recognition is ready.',
        ),
        CallCheck(
          CallCheckId.output,
          CallCheckStatus.needsSetup,
          'Configure a speech provider on Hermes.',
          action: CallSetupAction.hermes,
        ),
        CallCheck(
          CallCheckId.voiceModel,
          CallCheckStatus.warning,
          "Couldn't check the voice model. The call can still start.",
        ),
        CallCheck(
          CallCheckId.connection,
          CallCheckStatus.unavailable,
          'The voice service could not be reached. Check your connection or update Hermes.',
          action: CallSetupAction.hermes,
        ),
      ], useDeviceSpeech: true),
      'Device setup needed': const CallReadiness([
        CallCheck(
          CallCheckId.microphone,
          CallCheckStatus.needsSetup,
          'Allow Hermes to use your microphone.',
          action: CallSetupAction.microphone,
        ),
        CallCheck(
          CallCheckId.input,
          CallCheckStatus.needsSetup,
          'Install your speech language in Dictation settings.',
          action: CallSetupAction.dictation,
        ),
        CallCheck(
          CallCheckId.output,
          CallCheckStatus.ready,
          'Hermes speech output is configured.',
        ),
        CallCheck(
          CallCheckId.voiceModel,
          CallCheckStatus.ready,
          'Voice replies follow your main model.',
        ),
        CallCheck(
          CallCheckId.connection,
          CallCheckStatus.ready,
          'The voice service is reachable.',
        ),
      ], useDeviceSpeech: true),
    }.entries)
      WidgetbookUseCase(
        name: entry.key,
        builder: (_) => frame(
          VoiceCallSetupView(
            readiness: entry.value,
            onClose: () {},
            onRetry: () {},
            onStart: () {},
            onMicrophone: () {},
            onDictation: () {},
            onAskHermes: () {},
          ),
        ),
      ),
    for (final sending in [false, true])
      WidgetbookUseCase(
        name: sending ? 'Sending setup request' : 'Setup request failed',
        builder: (_) => frame(
          VoiceCallSetupView(
            readiness: const CallReadiness([
              CallCheck(
                CallCheckId.output,
                CallCheckStatus.needsSetup,
                'Configure a speech provider on Hermes.',
                action: CallSetupAction.hermes,
              ),
            ]),
            busy: sending,
            error: sending
                ? null
                : 'The setup request could not be sent. Try again.',
            onClose: () {},
            onRetry: () {},
            onStart: () {},
            onAskHermes: () {},
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'Microphone denied',
      builder: (_) => frame(
        VoiceCallSetupView(
          readiness: const CallReadiness([
            CallCheck(
              CallCheckId.microphone,
              CallCheckStatus.needsSetup,
              'Allow Hermes to use your microphone.',
              action: CallSetupAction.microphone,
            ),
          ]),
          microphoneDenied: true,
          onClose: () {},
          onRetry: () {},
          onStart: () {},
          onMicrophone: () {},
        ),
      ),
    ),
  ],
);

Widget _call(
  BuildContext context, {
  CallPhase phase = CallPhase.listening,
  bool muted = false,
  bool sending = false,
  double? amplitude,
  bool showSpeaker = true,
  VoiceSpeakingHint hint = VoiceSpeakingHint.tapOrTalk,
  String caption = '',
  String? error,
  Widget? notice,
  bool endedByUser = false,
  bool stoppedWord = false,
  bool capturePaused = false,
  bool startNew = false,
  VoiceCallFooter footer = VoiceCallFooter.none,
  String route = 'iPhone',
  double maxWidth = 480,
  String turnYou = '',
  String turnHermes = '',
  bool replyInChat = false,
  bool speakReplies = true,
}) => StatefulBuilder(
  builder: (context, setState) => frame(
    VoiceCallView(
      phase: phase,
      elapsed: const Duration(minutes: 2, seconds: 14),
      muted: muted,
      speaker: false,
      route: route,
      sending: sending,
      amplitude: amplitude,
      showSpeaker: showSpeaker,
      speakingHint: hint,
      caption: caption,
      error: error,
      notice: notice,
      endedByUser: endedByUser,
      stoppedWord: stoppedWord,
      capturePaused: capturePaused,
      footer: footer,
      onStartNew: startNew ? () {} : null,
      onInterrupt: () {},
      onMute: () {},
      onSpeaker: () {},
      onEnd: () {},
      onShowChat: () {},
      onAskHermes: error != null ? () {} : null,
      turnYou: turnYou,
      turnHermes: turnHermes,
      replyInChat: replyInChat,
      speakReplies: speakReplies,
      onSpeakRepliesChanged: (value) => setState(() => speakReplies = value),
    ),
    maxWidth: maxWidth,
  ),
);

const _question = 'What does my afternoon look like?';
const _answer =
    'You have two meetings: the design review at 14:00 and a call with Sam at 16:30. The hour between them is free.';
const _longAnswer =
    'You have two meetings. The design review runs from 14:00 to 15:00 in the large room, and the call with Sam at 16:30 is moved to video. Between them you have an hour, which is enough for the report you wanted to finish. After 17:00 nothing is planned, so the evening is free for the trip you mentioned last week.';

WidgetbookComponent _viewNode() => WidgetbookComponent(
  name: 'VoiceCallView',
  useCases: [
    WidgetbookUseCase(
      name: 'Connecting',
      builder: (c) => _call(c, phase: CallPhase.connecting),
    ),
    WidgetbookUseCase(
      name: 'Listening',
      builder: (c) => _call(c, amplitude: 0.5),
    ),
    WidgetbookUseCase(
      name: 'Listening, no level (shipped)',
      builder: (c) => _call(c),
    ),
    WidgetbookUseCase(
      name: 'Speaking, no level (shipped)',
      builder: (c) => _call(c, phase: CallPhase.speaking),
    ),
    WidgetbookUseCase(name: 'Muted', builder: (c) => _call(c, muted: true)),
    WidgetbookUseCase(
      name: 'Listening, last turn',
      builder: (c) =>
          _call(c, turnYou: _question, turnHermes: _answer, amplitude: 0.4),
    ),
    WidgetbookUseCase(
      name: 'Listening, last turn, long words',
      builder: (c) => _call(
        c,
        turnYou: '$_question $_question $_question',
        turnHermes: _longAnswer,
      ),
    ),
    WidgetbookUseCase(
      name: 'Speaking, reply on its way (last turn)',
      builder: (c) => _call(
        c,
        phase: CallPhase.speaking,
        amplitude: 0.6,
        turnYou: _question,
        turnHermes: 'You have two meetings: the design review at',
      ),
    ),
    WidgetbookUseCase(
      name: 'Sending: the caption replaces the last turn',
      builder: (c) => _call(
        c,
        phase: CallPhase.sending,
        caption: 'And what about tomorrow?',
        turnYou: _question,
        turnHermes: _answer,
      ),
    ),
    WidgetbookUseCase(
      name: 'Speak replies off',
      builder: (c) => _call(c, speakReplies: false),
    ),
    WidgetbookUseCase(
      name: 'Speak replies off, reply is in the chat',
      builder: (c) =>
          _call(c, speakReplies: false, turnYou: _question, replyInChat: true),
    ),
    WidgetbookUseCase(
      name: 'Speak replies off, thinking',
      builder: (c) => _call(
        c,
        phase: CallPhase.thinking,
        speakReplies: false,
        caption: _question,
      ),
    ),
    WidgetbookUseCase(
      name: 'Sending',
      builder: (c) => _call(c, phase: CallPhase.sending, caption: _question),
    ),
    WidgetbookUseCase(
      name: 'Thinking',
      builder: (c) => _call(c, phase: CallPhase.thinking, caption: _question),
    ),
    WidgetbookUseCase(
      name: 'Speaking',
      builder: (c) => _call(c, phase: CallPhase.speaking, amplitude: 0.6),
    ),
    WidgetbookUseCase(
      name: 'Speaking, Android (tap only)',
      builder: (c) => _call(
        c,
        phase: CallPhase.speaking,
        amplitude: 0.6,
        hint: VoiceSpeakingHint.tapOnly,
        footer: VoiceCallFooter.androidLeave,
        route: 'Phone speaker',
      ),
    ),
    WidgetbookUseCase(
      name: 'Speaking, desktop (microphone paused)',
      builder: (c) => _call(
        c,
        phase: CallPhase.speaking,
        amplitude: 0.6,
        showSpeaker: false,
        hint: VoiceSpeakingHint.micPaused,
        footer: VoiceCallFooter.desktopHide,
        route: 'MacBook Pro Speakers',
      ),
    ),
    WidgetbookUseCase(
      name: 'Listening, desktop (no speaker)',
      builder: (c) => _call(
        c,
        showSpeaker: false,
        footer: VoiceCallFooter.desktopHide,
        route: 'MacBook Pro Microphone',
      ),
    ),
    WidgetbookUseCase(
      name: 'Waiting for you',
      builder: (c) => _call(c, phase: CallPhase.attention, capturePaused: true),
    ),
    WidgetbookUseCase(
      name: 'Transcription failed',
      builder: (c) => _call(
        c,
        notice: VoiceCallNotice(
          tone: VoiceCallNoticeTone.warning,
          title: c.l10n.voiceNoticeTranscriptionTitle,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Route changed',
      builder: (c) => _call(
        c,
        route: 'Car audio',
        notice: VoiceCallNotice(
          tone: VoiceCallNoticeTone.warning,
          title: c.l10n.voiceNoticeRouteTitle,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Stopped: interrupted',
      builder: (c) => _call(
        c,
        phase: CallPhase.failed,
        stoppedWord: true,
        startNew: true,
        notice: VoiceCallNotice(
          tone: VoiceCallNoticeTone.warning,
          title: c.l10n.voiceNoticeInterruptedTitle,
          detail: c.l10n.voiceNoticeInterruptedDetail,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Stopped: left the app',
      builder: (c) => _call(
        c,
        phase: CallPhase.ended,
        stoppedWord: true,
        startNew: true,
        notice: VoiceCallNotice(
          title: c.l10n.voiceNoticeLeftTitle,
          detail: c.l10n.voiceNoticeLeftDetail,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Stopped: idle',
      builder: (c) => _call(
        c,
        phase: CallPhase.ended,
        stoppedWord: true,
        startNew: true,
        notice: VoiceCallNotice(
          title: c.l10n.voiceNoticeIdleTitle,
          detail: c.l10n.voiceNoticeIdleDetail,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Call ended by you',
      builder: (c) => _call(
        c,
        phase: CallPhase.ended,
        endedByUser: true,
        startNew: true,
        notice: VoiceCallNotice(
          title: c.l10n.voiceNoticeEndedTitle,
          detail: c.l10n.voiceNoticeEndedDetail,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Stopped: speech failed',
      builder: (c) => _call(
        c,
        phase: CallPhase.failed,
        stoppedWord: true,
        startNew: true,
        notice: VoiceCallNotice(
          tone: VoiceCallNoticeTone.warning,
          title: c.l10n.voiceNoticeSpeechFailedTitle,
          detail: c.l10n.voiceNoticeSpeechFailedDetail,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Failed with help',
      builder: (c) => _call(
        c,
        phase: CallPhase.failed,
        error: 'The connection was interrupted. Your messages are saved in the chat.',
      ),
    ),
    WidgetbookUseCase(
      name: 'Muted on car audio',
      builder: (c) => _call(c, muted: true, route: 'Car audio'),
    ),
  ],
);

WidgetbookComponent _turnListNode() => WidgetbookComponent(
  name: 'VoiceTurnList',
  useCases: [
    WidgetbookUseCase(
      name: 'Empty (draws nothing)',
      builder: (_) => frame(const VoiceTurnList()),
    ),
    WidgetbookUseCase(
      name: 'You only (reply not started)',
      builder: (_) => frame(const VoiceTurnList(you: _question)),
    ),
    WidgetbookUseCase(
      name: 'Both lines',
      builder: (_) =>
          frame(const VoiceTurnList(you: _question, hermes: _answer)),
    ),
    WidgetbookUseCase(
      name: 'Long words (ellipsis)',
      builder: (_) => frame(
        const VoiceTurnList(
          you: '$_question $_question $_question',
          hermes: _longAnswer,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Reply is in the chat',
      builder: (_) =>
          frame(const VoiceTurnList(you: _question, replyInChat: true)),
    ),
    WidgetbookUseCase(
      name: 'Phone width (320 pt)',
      builder: (_) => frame(
        const VoiceTurnList(you: _question, hermes: _answer),
        maxWidth: 320,
      ),
    ),
  ],
);

WidgetbookComponent _orbNode() => WidgetbookComponent(
  name: 'VoiceOrb',
  useCases: [
    for (final s in VoiceOrbState.values)
      WidgetbookUseCase(
        name: s.name,
        builder: (_) => frame(
          Center(
            child: VoiceOrb(
              state: s,
              amplitude: 0.5,
              onTap: s == VoiceOrbState.speaking ? () {} : null,
            ),
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'stopped after End (check)',
      builder: (_) => frame(
        const Center(
          child: VoiceOrb(state: VoiceOrbState.stopped, stoppedCheck: true),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'levels',
      builder: (_) => frame(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in [0.0, 0.5, 1.0])
              VoiceOrb(state: VoiceOrbState.listening, amplitude: level),
            for (final level in [0.0, 0.5, 1.0])
              VoiceOrb(
                state: VoiceOrbState.speaking,
                amplitude: level,
                onTap: () {},
              ),
          ],
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'reduce motion (static rings)',
      builder: (_) => frame(
        const Wrap(
          spacing: 8,
          children: [
            VoiceOrb(
              state: VoiceOrbState.listening,
              amplitude: 1,
              reduceMotion: true,
            ),
            VoiceOrb(state: VoiceOrbState.connecting, reduceMotion: true),
          ],
        ),
      ),
    ),
  ],
);

WidgetbookComponent _stripNode() => WidgetbookComponent(
  name: 'HandsFreeStrip',
  useCases: [
    for (final m in HandsFreeMicrophone.values)
      WidgetbookUseCase(
        name: m.name,
        builder: (_) => frame(
          Align(
            alignment: Alignment.centerLeft,
            child: HandsFreeStrip(microphone: m, onEnd: () {}),
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'without End (call page)',
      builder: (_) => frame(
        const Align(
          alignment: Alignment.centerLeft,
          child: HandsFreeStrip(microphone: HandsFreeMicrophone.open),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'all variants',
      builder: (_) => frame(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            for (final m in HandsFreeMicrophone.values)
              HandsFreeStrip(microphone: m, onEnd: () {}),
          ],
        ),
      ),
    ),
  ],
);

WidgetbookComponent _noticeNode() => WidgetbookComponent(
  name: 'VoiceCallNotice',
  useCases: [
    WidgetbookUseCase(
      name: 'Info with detail',
      builder: (c) => frame(
        VoiceCallNotice(
          title: c.l10n.voiceNoticeIdleTitle,
          detail: c.l10n.voiceNoticeIdleDetail,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Warning with detail',
      builder: (c) => frame(
        VoiceCallNotice(
          tone: VoiceCallNoticeTone.warning,
          title: c.l10n.voiceNoticeSpeechFailedTitle,
          detail: c.l10n.voiceNoticeSpeechFailedDetail,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Warning, one line',
      builder: (c) => frame(
        VoiceCallNotice(
          tone: VoiceCallNoticeTone.warning,
          title: c.l10n.voiceNoticeTranscriptionTitle,
        ),
      ),
    ),
  ],
);

WidgetbookComponent _consentNode() => WidgetbookComponent(
  name: 'VoiceConsentRow',
  useCases: [
    for (final initial in [false, true])
      WidgetbookUseCase(
        name: initial ? 'On' : 'Off',
        builder: (_) {
          var on = initial;
          return StatefulBuilder(
            builder: (context, setState) => frame(
              VoiceConsentRow(
                value: on,
                onChanged: (v) => setState(() => on = v),
              ),
            ),
          );
        },
      ),
  ],
);
