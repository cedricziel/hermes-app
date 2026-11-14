import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:widgetbook/widgetbook.dart';

import 'directories.dart';
import 'environment.dart';

void main() => runApp(const HermesWidgetbook());

class HermesWidgetbook extends StatelessWidget {
  const HermesWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      home: const Center(child: Text('Pick a component in the list.')),
      directories: directories,
      addons: [
        MaterialThemeAddon(
          themes: [
            for (final e in themes.entries)
              WidgetbookTheme(name: e.key, data: e.value),
          ],
        ),
        LocalizationAddon(
          locales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialLocale: const Locale('en'),
        ),
        TextScaleAddon(min: 1, max: 3),
        ViewportAddon([phone, desktop]),
      ],
    );
  }
}
