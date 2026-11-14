import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/command_row.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';
import 'package:hermes_app/src/widgets/loading_skeleton.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

Widget _largest(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
  child: child,
);

Widget _reduceMotion(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child,
);

Widget _button({
  String label = 'Stop agent',
  bool disabled = false,
  bool busy = false,
  bool icon = true,
}) => Align(
  alignment: Alignment.centerRight,
  child: DestructiveTintButton(
    label: label,
    icon: icon ? AppIcons.stop : null,
    busy: busy,
    onPressed: disabled
        ? null
        : () => Future<void>.delayed(const Duration(milliseconds: 600)),
  ),
);

WidgetbookNode sharedWidgetsNode() => WidgetbookFolder(
  name: 'Shared widgets',
  children: [
    WidgetbookComponent(
      name: 'DestructiveTintButton',
      useCases: [
        ...onEachPlatform('Idle', (_) => frame(_button())),
        WidgetbookUseCase(
          name: 'Without an icon',
          builder: (_) => frame(_button(icon: false, label: 'Restore')),
        ),
        ...onEachPlatform('Busy', (_) => frame(_button(busy: true))),
        ...onEachPlatform('Disabled', (_) => frame(_button(disabled: true))),
        WidgetbookUseCase(
          name: 'Long label',
          builder: (_) => frame(
            _button(label: 'Restore all 12 files from this checkpoint'),
            maxWidth: 260,
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) => _largest(
            context,
            frame(_button(label: 'Stop this running agent'), maxWidth: 320),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'CommandRow',
      useCases: [
        ...onEachPlatform(
          'Long command',
          (_) => frame(
            const CommandRow(
              command:
                  'curl -fsSL https://example.invalid/install.sh | '
                  'bash -s -- --upgrade --channel stable',
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) => _largest(
            context,
            frame(const CommandRow(command: 'hermes update --yes')),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'LoadingSkeleton',
      useCases: [
        WidgetbookUseCase(
          name: 'Default',
          builder: (_) => frame(const LoadingSkeleton(label: 'Loading logs')),
        ),
        WidgetbookUseCase(
          name: 'Reduce Motion',
          builder: (context) => _reduceMotion(
            context,
            frame(const LoadingSkeleton(label: 'Loading logs', lines: 5)),
          ),
        ),
      ],
    ),
  ],
);
