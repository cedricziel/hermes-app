import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/state_message.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode stateMessageNode() => WidgetbookComponent(
  name: 'StateMessage',
  useCases: [
    WidgetbookUseCase(
      name: 'Empty',
      builder: (_) => fill(
        const StateMessage(
          icon: AppIconSet(Icons.inbox_outlined, CupertinoIcons.tray),
          title: 'No scheduled tasks',
          detail: 'Tasks you schedule for the agent show up here.',
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Error with retry',
      builder: (_) => fill(
        StateMessage(
          icon: AppIcons.error,
          title: 'Could not load the board',
          detail: 'The server did not answer.',
          action: FilledButton(onPressed: () {}, child: const Text('Retry')),
        ),
      ),
    ),
  ],
);
