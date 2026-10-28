import 'package:flutter/material.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/install/install_state.dart';
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
    onInstall: () {},
    onEnlarge: enlarge ? () {} : null,
  ),
  maxWidth: 380,
);

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
  return WidgetbookComponent(
    name: 'Bot screen card',
    useCases: [
      for (final (name, model, :enlarge) in states)
        ...onEachPlatform(name, (_) => _card(model, enlarge: enlarge)),
    ],
  );
}
