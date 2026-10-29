import 'package:flutter/material.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_preview_model.dart';

import 'package:hermes_app/src/bot_screen/install/install_state.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/bot_screen/widgets/force_hand_back.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/chat/chat_models.dart'
    show ToolCall, ToolCallStatus;
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:widgetbook/widgetbook.dart';

import 'bot_screen_fixture.dart';
import 'frame.dart';

/// [model] as the Activity panel lists it, in a column as wide as the
/// inspector.
Widget _card(BotScreenCardModel model, {bool enlarge = false}) => frame(
  BotScreenCard(
    model: model,
    onStart: () {},
    onCopyCommand: () {},
    onRetry: () {},
    onInstall: () {},
    onForceHandBack: () {},
    onEnlarge: enlarge ? () {} : null,
  ),
  maxWidth: 380,
);

const _computerUse = ToolCall(
  id: 'computer-use-1',
  name: 'computer_use',
  summary: '{"action":"click","coordinate":[640,400]}',
  status: ToolCallStatus.running,
);

const _computerUseRun = [
  ToolCall(
    id: 'computer-use-0',
    name: 'computer_use',
    summary: '{"action":"screenshot"}',
  ),
  _computerUse,
];

Widget _preview(BotScreenPreviewModel model) =>
    frame(BotScreenPreview(model: model, onTap: () {}), maxWidth: 480);

/// The tool call widgets as the transcript builds them, with the preview in
/// their slot.
List<WidgetbookUseCase> _inToolCalls(
  BotScreenPreviewModel model,
  String state,
) {
  final preview = BotScreenPreview(model: model, onTap: () {});
  return [
    ...onEachPlatform(
      '$state, single call',
      (_) => frame(
        ToolCallGroup(calls: const [_computerUse], preview: preview),
        maxWidth: 480,
      ),
    ),
    ...onEachPlatform(
      '$state, folded group',
      (_) => frame(
        ToolCallGroup(calls: _computerUseRun, preview: preview),
        maxWidth: 480,
      ),
    ),
  ];
}

const _manualCommand = 'apt-get install -y tigervnc-standalone-server xfce4';
const _installCommand = 'sudo $_manualCommand';

const _installLines = [
  'Reading package lists...',
  'Building dependency tree...',
  'The following NEW packages will be installed:',
  'Get:1 http://deb.example.org/debian bookworm/main xfce4 [1,106 B]',
  'Unpacking tigervnc-standalone-server (1.12.0+dfsg-9) ...',
  'Setting up xfce4-session (4.18.1-1) ...',
];

WidgetbookNode botScreenNode() {
  final picture = botScreenFixturePng();
  final states = <(String, BotScreenCardModel, {bool enlarge})>[
    ('Hermes in control', BotScreenShowing(bytes: picture), enlarge: false),
    (
      'Hermes in control, Enlarge shown',
      BotScreenShowing(bytes: picture),
      enlarge: true,
    ),
    (
      'Hermes in control, portrait screen',
      BotScreenShowing(bytes: picture, aspectRatio: 3 / 4),
      enlarge: false,
    ),
    ('Waiting for the first picture', const BotScreenShowing(), enlarge: false),
    ('Someone else in control', const BotScreenControlled(), enlarge: false),
    (
      'Someone in control, Hand back to Hermes',
      const BotScreenControlled(canForce: true),
      enlarge: false,
    ),
    ('You in control', const BotScreenControlled(byYou: true), enlarge: false),
    ('Off', const BotScreenOff(), enlarge: false),
    (
      'Off after a failed start',
      const BotScreenOff(startFailure: BotScreenFailure.timeout),
      enlarge: false,
    ),
    ('Starting', const BotScreenStarting(), enlarge: false),
    ('Error', const BotScreenReadFailed(), enlarge: false),
    (
      'Not installed, with a command',
      const BotScreenNotInstalled(command: 'hermes computer-use install --yes'),
      enlarge: false,
    ),
    (
      'Not installed, Install on Server',
      const BotScreenNotInstalled(command: _installCommand, canInstall: true),
      enlarge: false,
    ),
    ('Installing, no output yet', const BotScreenInstalling(), enlarge: false),
    (
      'Installing, with output',
      const BotScreenInstalling(lines: _installLines),
      enlarge: false,
    ),
    (
      "Install couldn't start",
      const BotScreenNotInstalled(
        command: _installCommand,
        canInstall: true,
        result: InstallRefused(
          message: 'an install is already running for this profile',
        ),
      ),
      enlarge: false,
    ),
    (
      "Install couldn't start, no answer",
      const BotScreenNotInstalled(
        command: _installCommand,
        canInstall: true,
        result: InstallUnreachable(BotScreenFailure.timeout),
      ),
      enlarge: false,
    ),
    (
      'Install cancelled',
      const BotScreenNotInstalled(
        command: _installCommand,
        canInstall: true,
        result: InstallCancelled(),
      ),
      enlarge: false,
    ),
    (
      'Install: no sudo on the server',
      const BotScreenNotInstalled(
        command: _manualCommand,
        result: InstallNoSudo(command: _installCommand),
      ),
      enlarge: false,
    ),
    (
      'Install failed',
      const BotScreenNotInstalled(
        command: _installCommand,
        canInstall: true,
        result: InstallFailed(
          lines: [
            'E: Unable to locate package tigervnc-standalone-server',
            'E: Package xfce4 has no installation candidate',
          ],
        ),
      ),
      enlarge: false,
    ),
    (
      'Install may still be running',
      const BotScreenNotInstalled(
        command: _installCommand,
        canInstall: true,
        result: InstallMayStillRun(),
      ),
      enlarge: false,
    ),
    (
      'Not installed, with no command',
      const BotScreenNotInstalled(),
      enlarge: false,
    ),
    (
      'Not installed, in a sandbox',
      const BotScreenNotInstalled(sandbox: true),
      enlarge: false,
    ),
    (
      'Blocked, with memory',
      const BotScreenBlocked(
        text: 'Not enough free memory to start a desktop.',
        memoryMb: 312,
      ),
      enlarge: false,
    ),
    (
      'Blocked, without memory',
      const BotScreenBlocked(
        text: 'Not enough free memory to start a desktop.',
      ),
      enlarge: false,
    ),
    ('Not offered', const BotScreenNotOffered(), enlarge: false),
  ];
  final previews = <(String, BotScreenPreviewModel)>[
    ('Hermes in control', BotScreenPreviewFrame(bytes: picture)),
    (
      'Portrait screen',
      BotScreenPreviewFrame(bytes: picture, aspectRatio: 3 / 4),
    ),
    ('Waiting for the first picture', const BotScreenPreviewFrame()),
    ('Someone else in control', const BotScreenPreviewSuppressed()),
    ('You in control', const BotScreenPreviewSuppressed(byYou: true)),
  ];
  return WidgetbookFolder(
    name: 'Bot screen',
    children: [
      WidgetbookComponent(
        name: 'Bot screen card',
        useCases: [
          for (final (name, model, :enlarge) in states)
            ...onEachPlatform(name, (_) => _card(model, enlarge: enlarge)),
        ],
      ),
      WidgetbookComponent(
        name: 'Hand back confirmation',
        useCases: onEachPlatform(
          'Hand control back to Hermes',
          (_) => fill(
            Center(
              child: ForceHandBackDialog(onCancel: () {}, onConfirm: () {}),
            ),
          ),
        ),
      ),
      WidgetbookComponent(
        name: 'Bot screen preview',
        useCases: [
          for (final (name, model) in previews)
            ...onEachPlatform(name, (_) => _preview(model)),
          ...onEachPlatform(
            'Not tappable',
            (_) => frame(
              BotScreenPreview(model: BotScreenPreviewFrame(bytes: picture)),
              maxWidth: 480,
            ),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Bot screen preview in a tool call',
        useCases: [
          for (final (name, model) in previews)
            if (!name.startsWith('Portrait') && !name.startsWith('You'))
              ..._inToolCalls(model, name),
        ],
      ),
    ],
  );
}

/// The desktop the viewer draws, in place of the framebuffer.
Widget _desktop() => Image.memory(
  botScreenFixturePng(width: 320, height: 200),
  fit: BoxFit.fill,
  filterQuality: FilterQuality.none,
  gaplessPlayback: true,
);

Widget _viewer(
  BotScreenViewerPhase phase, {
  BotScreenViewerPresentation presentation = BotScreenViewerPresentation.page,
  bool picture = false,
  double aspectRatio = 16 / 10,
  BotScreenControl control = BotScreenControl.watching,
  bool canForce = false,
  bool actions = false,
  String lostText = 'Someone else took control.',
}) => fill(
  BotScreenViewerView(
    phase: phase,
    profile: 'research',
    picture: picture ? _desktop() : null,
    aspectRatio: aspectRatio,
    presentation: presentation,
    control: control,
    lostText: lostText,
    canForce: canForce,
    onClose: () {},
    onRetry: () {},
    onStart: () {},
    onTakeOver: actions ? () {} : null,
    onHandBack: actions ? () {} : null,
    onForceHandBack: actions ? () {} : null,
    onDismissLost: actions ? () {} : null,
  ),
);

WidgetbookNode botScreenViewerNode() {
  final states = <(String, BotScreenViewerPhase, {bool picture, double ratio})>[
    ('Connecting', BotScreenViewerPhase.connecting, picture: false, ratio: 1.6),
    ('Live', BotScreenViewerPhase.live, picture: true, ratio: 1.6),
    (
      'Live, portrait screen',
      BotScreenViewerPhase.live,
      picture: true,
      ratio: 0.75,
    ),
    (
      'Reconnecting over the last picture',
      BotScreenViewerPhase.reconnecting,
      picture: true,
      ratio: 1.6,
    ),
    (
      'Reconnecting without a picture',
      BotScreenViewerPhase.reconnecting,
      picture: false,
      ratio: 1.6,
    ),
    (
      'Someone else in control',
      BotScreenViewerPhase.blanked,
      picture: false,
      ratio: 1.6,
    ),
    ('Off', BotScreenViewerPhase.off, picture: false, ratio: 1.6),
    (
      'Viewing not allowed',
      BotScreenViewerPhase.notAllowed,
      picture: false,
      ratio: 1.6,
    ),
    (
      "Can't reach the screen",
      BotScreenViewerPhase.unreachable,
      picture: false,
      ratio: 1.6,
    ),
    ('Stream failed', BotScreenViewerPhase.failed, picture: false, ratio: 1.6),
  ];
  return WidgetbookComponent(
    name: 'Bot screen viewer',
    useCases: [
      for (final (name, phase, :picture, :ratio) in states)
        ...onEachPlatform(
          name,
          (_) => _viewer(phase, picture: picture, aspectRatio: ratio),
        ),
      // Who is in control: Take over, in control, control lost, and the lease
      // someone else holds.
      for (final (name, phase, control, canForce, picture) in [
        (
          'Watching, Take over',
          BotScreenViewerPhase.live,
          BotScreenControl.watching,
          false,
          true,
        ),
        (
          'Taking over',
          BotScreenViewerPhase.live,
          BotScreenControl.acquiring,
          false,
          true,
        ),
        (
          'In control',
          BotScreenViewerPhase.live,
          BotScreenControl.inControl,
          false,
          true,
        ),
        (
          'Handing back',
          BotScreenViewerPhase.live,
          BotScreenControl.releasing,
          false,
          true,
        ),
        (
          'In control, reconnecting',
          BotScreenViewerPhase.reconnecting,
          BotScreenControl.inControl,
          false,
          true,
        ),
        (
          'Lost control, Hermes has the screen',
          BotScreenViewerPhase.live,
          BotScreenControl.lost,
          false,
          true,
        ),
        (
          'Lost control, someone else has the screen',
          BotScreenViewerPhase.blanked,
          BotScreenControl.lost,
          true,
          false,
        ),
        (
          'Someone in control, Hand back to Hermes',
          BotScreenViewerPhase.blanked,
          BotScreenControl.watching,
          true,
          false,
        ),
      ])
        ...onEachPlatform(
          name,
          (_) => _viewer(
            phase,
            control: control,
            canForce: canForce,
            picture: picture,
            actions: true,
          ),
        ),
      ...onEachPlatform(
        'Lost control, Hermes took it back',
        (_) => _viewer(
          BotScreenViewerPhase.live,
          control: BotScreenControl.lost,
          picture: true,
          actions: true,
          lostText: 'Hermes took control back.',
        ),
      ),
      ...onEachPlatform(
        'In control, over the window',
        (_) => _viewer(
          BotScreenViewerPhase.live,
          presentation: BotScreenViewerPresentation.overlay,
          control: BotScreenControl.inControl,
          picture: true,
          actions: true,
        ),
      ),
      ...onEachPlatform(
        'Watching, Take over, over the window',
        (_) => _viewer(
          BotScreenViewerPhase.live,
          presentation: BotScreenViewerPresentation.overlay,
          picture: true,
          actions: true,
        ),
      ),
      // The layer over a whole window, from 760 points.
      for (final (name, phase, picture) in [
        ('Live', BotScreenViewerPhase.live, true),
        ('Someone else in control', BotScreenViewerPhase.blanked, false),
        ('Off', BotScreenViewerPhase.off, false),
      ])
        ...onEachPlatform(
          '$name, over the window',
          (_) => _viewer(
            phase,
            presentation: BotScreenViewerPresentation.overlay,
            picture: picture,
          ),
        ),
    ],
  );
}
