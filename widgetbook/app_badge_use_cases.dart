import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/app_badge.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookUseCase _case(String name, Widget Function(BuildContext) build) =>
    WidgetbookUseCase(name: name, builder: (context) => frame(build(context)));

WidgetbookFolder appBadgeNode() => WidgetbookFolder(
  name: 'AppBadge',
  children: [
    WidgetbookComponent(
      name: 'AppBadge',
      useCases: [
        _case('Tinted, every colour', (context) {
          final colors = context.hermesColors;
          final scheme = Theme.of(context).colorScheme;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppBadge.tinted(label: 'Add', color: colors.success),
              AppBadge.tinted(label: 'Replace', color: colors.warning),
              AppBadge.tinted(label: 'Remove', color: scheme.error),
              AppBadge.tinted(label: 'Skill', color: scheme.primary),
              AppBadge.tinted(label: 'Change', color: colors.subtleText),
            ],
          );
        }),
        _case(
          'Tinted with icon',
          (context) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppBadge.tinted(
                label: 'Ready',
                color: context.hermesColors.success,
                icon: AppIcons.check,
              ),
              AppBadge.tinted(
                label: 'Needs a key',
                color: context.hermesColors.warning,
                icon: AppIcons.key,
              ),
              AppBadge.tinted(
                label: "Can't be used",
                color: context.hermesColors.subtleText,
                icon: AppIcons.blocked,
              ),
            ],
          ),
        ),
        _case(
          'Tinted, minimum width',
          (context) => UnconstrainedBox(
            child: AppBadge.tinted(
              label: 'Add',
              color: context.hermesColors.success,
              minWidth: 64,
              verticalPadding: 2,
            ),
          ),
        ),
        _case('Filled, scheme role pairs', (context) {
          final scheme = Theme.of(context).colorScheme;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppBadge.filled(
                label: 'Primary',
                fill: scheme.primary,
                labelColor: scheme.onPrimary,
              ),
              AppBadge.filled(
                label: 'Surface',
                fill: scheme.surfaceContainerHighest,
                labelColor: scheme.onSurface,
              ),
            ],
          );
        }),
        WidgetbookUseCase(
          name: 'Largest text, long label wraps',
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: frame(
              SizedBox(
                width: 200,
                child: AppBadge.tinted(
                  label: 'Needs a sign-in on the server',
                  color: context.hermesColors.warning,
                  icon: AppIcons.signIn,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ],
);
