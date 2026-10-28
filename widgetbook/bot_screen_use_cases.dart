import 'package:flutter/material.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_preview_model.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/chat/chat_models.dart'
    show ToolCall, ToolCallStatus;
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
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
        ToolCallCard(call: _computerUse, preview: preview),
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
