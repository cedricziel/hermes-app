import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
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
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            ...kMaterialUiLocalizationsDelegates,
          ],
          initialLocale: const Locale('en'),
        ),
        BuilderAddon(
          name: 'App theme scopes',
          builder: (context, child) => AppThemeScopes(child: child),
        ),
        TextScaleAddon(min: 1, max: 3),
        ViewportAddon([phone, desktop]),
      ],
    );
  }
}
