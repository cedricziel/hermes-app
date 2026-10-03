import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookNode appIconsNode() => WidgetbookComponent(
  name: 'App icons',
  useCases: [
    WidgetbookUseCase(
      name: 'Material and Apple glyphs',
      builder: (_) => const _IconGrid(),
    ),
  ],
);

class _IconGrid extends StatelessWidget {
  const _IconGrid();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in AppIcons.all.entries)
              SizedBox(
                width: 132,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 12,
                      children: [
                        Icon(entry.value.material, size: 24),
                        Icon(entry.value.apple, size: 24),
                      ],
                    ),
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
