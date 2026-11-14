import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;

/// Localizations that `material_ui` and `cupertino_ui` widgets look up. Those
/// packages declare their own `MaterialLocalizations` and
/// `CupertinoLocalizations` types, so the delegates from Flutter's
/// `flutter_localizations` do not satisfy them. `upgrader` 14 builds its
/// update dialog from them. Add these to the app's delegates.
const List<LocalizationsDelegate<dynamic>> kMaterialUiLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      mui.DefaultMaterialLocalizations.delegate,
      cui.DefaultCupertinoLocalizations.delegate,
    ];

/// A `material_ui` theme seeded from the app's [scheme].
mui.ThemeData buildMaterialUiTheme(ColorScheme scheme) {
  return mui.ThemeData(
    colorScheme:
        mui.ColorScheme.fromSeed(
          seedColor: scheme.primary,
          brightness: scheme.brightness,
        ).copyWith(
          primary: scheme.primary,
          surface: scheme.surface,
          onSurface: scheme.onSurface,
        ),
  );
}

/// Provides the `material_ui` theme to everything below it. Put it above the
/// `Navigator` (a `MaterialApp.builder`) so dialogs pushed as routes see it.
class MaterialUiThemeScope extends StatelessWidget {
  const MaterialUiThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return mui.Theme(
      data: buildMaterialUiTheme(Theme.of(context).colorScheme),
      child: child,
    );
  }
}
