import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/state_message.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode changeInvalidationNode() => WidgetbookComponent(
  name: 'List refresh states',
  useCases: [
    ...onEachPlatform(
      'Loading',
      (_) => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
    ),
    ...onEachPlatform(
      'Messaging failure',
      (_) => Scaffold(
        body: StateMessage(
          icon: AppIcons.bot,
          title: 'Could not load messaging platforms',
          detail: 'Connect Hermes to Telegram, Discord, and other messaging platforms.',
          action: FilledButton(onPressed: () {}, child: const Text('Retry')),
        ),
      ),
    ),
    ...onEachPlatform(
      'Session list failure',
      (_) => Scaffold(
        body: StateMessage(
          icon: AppIcons.chat,
          title: 'Could not load chats',
          detail: 'Your existing draft and selected conversation are retained.',
          action: FilledButton(onPressed: () {}, child: const Text('Retry')),
        ),
      ),
    ),
  ],
);
