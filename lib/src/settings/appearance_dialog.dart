import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
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

/// What [mode] is called in the settings.
String themeModeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l10n.settingsThemeSystem,
  ThemeMode.light => l10n.settingsThemeLight,
  ThemeMode.dark => l10n.settingsThemeDark,
};

class _AppearanceDialog extends StatelessWidget {
  const _AppearanceDialog();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final l10n = context.l10n;
    return GroupedDialog(
      title: l10n.settingsAppearanceTitle,
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
                  title: themeModeLabel(l10n, mode),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
