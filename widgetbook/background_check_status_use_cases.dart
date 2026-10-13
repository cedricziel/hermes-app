import 'package:flutter/material.dart';
import 'package:hermes_app/src/background/background_check_status.dart';
import 'package:hermes_app/src/notifications/background_check_section.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode backgroundCheckStatusNode() => WidgetbookComponent(
  name: 'Background check status',
  useCases: [
    WidgetbookUseCase(
      name: 'First use',
      builder: (_) =>
          frame(const BackgroundCheckSection(platform: TargetPlatform.iOS)),
    ),
    WidgetbookUseCase(
      name: 'Recent completion',
      builder: (_) => frame(
        BackgroundCheckSection(
          platform: TargetPlatform.iOS,
          permission: true,
          capability: 'available',
          status: BackgroundCheckStatus(
            attemptedAt: DateTime(2026, 10, 13, 10),
            completedAt: DateTime(2026, 10, 13, 10, 1),
            outcome: BackgroundCheckOutcome.completed,
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Incomplete attempt',
      builder: (_) => frame(
        BackgroundCheckSection(
          platform: TargetPlatform.iOS,
          status: BackgroundCheckStatus(
            attemptedAt: DateTime(2026, 10, 13, 10),
            outcome: BackgroundCheckOutcome.incomplete,
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Permission denied',
      builder: (_) => frame(
        const BackgroundCheckSection(
          platform: TargetPlatform.iOS,
          permission: false,
          capability: 'available',
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'iOS refresh restricted',
      builder: (_) => frame(
        const BackgroundCheckSection(
          platform: TargetPlatform.iOS,
          permission: true,
          capability: 'restricted',
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Android registered',
      builder: (_) => frame(
        const BackgroundCheckSection(
          platform: TargetPlatform.android,
          permission: true,
          capability: 'registered',
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Unknown capability',
      builder: (_) =>
          frame(const BackgroundCheckSection(platform: TargetPlatform.android)),
    ),
  ],
);
