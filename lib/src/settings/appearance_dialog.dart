import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme_controller.dart';

Future<void> showAppearanceDialog(BuildContext context) {
  final theme = context.read<ThemeController>();
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: theme,
      child: const _AppearanceDialog(),
    ),
  );
}

const _labels = {
  ThemeMode.system: 'Follow system',
  ThemeMode.light: 'Light',
  ThemeMode.dark: 'Dark',
};

class _AppearanceDialog extends StatelessWidget {
  const _AppearanceDialog();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return SimpleDialog(
      title: const Text('Appearance'),
      children: [
        RadioGroup<ThemeMode>(
          groupValue: theme.mode,
          onChanged: (mode) {
            if (mode != null) theme.setMode(mode);
          },
          child: Column(
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  value: mode,
                  title: Text(_labels[mode]!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
