import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/grouped_choice_row.dart';
import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_list.dart';
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

/// What each theme mode is called in the settings.
const themeModeLabels = {
  ThemeMode.system: 'Follow system',
  ThemeMode.light: 'Light',
  ThemeMode.dark: 'Dark',
};

class _AppearanceDialog extends StatelessWidget {
  const _AppearanceDialog();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return GroupedDialog(
      title: 'Appearance',
      children: [
        RadioGroup<ThemeMode>(
          groupValue: theme.mode,
          onChanged: (mode) {
            if (mode != null) theme.setMode(mode);
          },
          child: GroupedSection(
            dividerIndent: GroupedChoiceRow.dividerIndent(context),
            children: [
              for (final mode in ThemeMode.values)
                GroupedChoiceRow<ThemeMode>(
                  value: mode,
                  title: themeModeLabels[mode]!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
