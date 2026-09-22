import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _zinc = {
  'zinc50': HermesColors.zinc50,
  'zinc100': HermesColors.zinc100,
  'zinc200': HermesColors.zinc200,
  'zinc300': HermesColors.zinc300,
  'zinc400': HermesColors.zinc400,
  'zinc500': HermesColors.zinc500,
  'zinc600': HermesColors.zinc600,
  'zinc700': HermesColors.zinc700,
  'zinc800': HermesColors.zinc800,
  'zinc900': HermesColors.zinc900,
  'zinc950': HermesColors.zinc950,
};

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, [this.onColor]);

  final String name;
  final Color color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      width: 96,
      height: 64,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outline),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 11, color: onColor ?? _readable(color)),
      ),
    );
  }

  static Color _readable(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: children),
    ],
  );
}

WidgetbookNode paletteNode() => WidgetbookComponent(
  name: 'Theme',
  useCases: [
    WidgetbookUseCase(
      name: 'Zinc palette',
      builder: (_) => frame(
        _Section('HermesColors', [
          for (final e in _zinc.entries) _Swatch(e.key, e.value),
        ]),
        maxWidth: 600,
      ),
    ),
    WidgetbookUseCase(
      name: 'Color scheme',
      builder: (context) {
        final s = Theme.of(context).colorScheme;
        return frame(
          _Section('Roles in the active theme', [
            _Swatch('primary', s.primary, s.onPrimary),
            _Swatch('secondary', s.secondary, s.onSecondary),
            _Swatch('surface', s.surface, s.onSurface),
            _Swatch('surface high', s.surfaceContainerHighest, s.onSurface),
            _Swatch('outline', s.outline),
            _Swatch('error', s.error, s.onError),
            _Swatch('success', context.hermesColors.success),
            _Swatch('warning', context.hermesColors.warning),
          ]),
          maxWidth: 600,
        );
      },
    ),
    WidgetbookUseCase(
      name: 'Text styles',
      builder: (context) {
        final t = Theme.of(context).textTheme;
        return frame(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title large', style: t.titleLarge),
              Text('Title medium', style: t.titleMedium),
              Text('Body large', style: t.bodyLarge),
              Text('Body medium', style: t.bodyMedium),
              Text('Body small', style: t.bodySmall),
              Text('Label large', style: t.labelLarge),
            ],
          ),
        );
      },
    ),
  ],
);
