import 'package:flutter/material.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
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
  return WidgetbookComponent(
    name: 'Bot screen card',
    useCases: [
      for (final (name, model, :enlarge) in states)
        ...onEachPlatform(name, (_) => _card(model, enlarge: enlarge)),
    ],
  );
}
