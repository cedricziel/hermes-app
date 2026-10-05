import 'package:flutter/material.dart';
import 'package:hermes_app/src/handoff/handoff_dialog.dart';
import 'package:widgetbook/widgetbook.dart';

import 'host.dart';

WidgetbookNode handoffNode() => WidgetbookComponent(
  name: 'Handoff',
  useCases: [
    for (final name in [
      'Unconfigured device',
      'Another dashboard',
      'Long URL',
      'Cancel',
    ])
      WidgetbookUseCase(
        name: name,
        builder: (_) => openOnShow(
          (context) => showDialog<void>(
            context: context,
            builder: (context) => HandoffDialog(
              serverUrl: name == 'Long URL'
                  ? 'https://dashboard.example.test/a/long/dashboard/base/path'
                  : 'https://dashboard.example.test',
              onCancel: () => Navigator.pop(context),
              onContinue: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    for (final entry in [
      ('Unavailable chat', 'This chat is unavailable.', false),
      ('Connection failure', 'Could not reach the dashboard. Try again.', true),
      (
        'Development override',
        'This build uses a fixed development dashboard.',
        false,
      ),
    ])
      WidgetbookUseCase(
        name: entry.$1,
        builder: (_) => openOnShow(
          (context) => showDialog<void>(
            context: context,
            builder: (context) => HandoffDialog(
              error: entry.$2,
              onCancel: () => Navigator.pop(context),
              onContinue: entry.$3 ? () => Navigator.pop(context) : null,
            ),
          ),
        ),
      ),
  ],
);
