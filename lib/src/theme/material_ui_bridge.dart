import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:material_ui/material_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;

/// Localizations that `material_ui` and `cupertino_ui` widgets look up. Those
/// packages declare their own `MaterialLocalizations` and
/// `CupertinoLocalizations` types, so the delegates from Flutter's
/// `flutter_localizations` do not satisfy them. `upgrader` 14 builds its
/// update dialog from them. Add these to the app's delegates.
const List<LocalizationsDelegate<dynamic>> kMaterialUiLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      mui.GlobalMaterialLocalizations.delegate,
      cui.GlobalCupertinoLocalizations.delegate,
      _EnglishFallbackDelegate<mui.MaterialLocalizations>(
        mui.DefaultMaterialLocalizations.delegate,
      ),
      _EnglishFallbackDelegate<cui.CupertinoLocalizations>(
        cui.DefaultCupertinoLocalizations.delegate,
      ),
    ];

/// The `Default*Localizations` delegates support English only and refuse any
/// other locale. Listed after the packages' `Global*` delegates, this one
/// supports every locale and loads the English defaults for those the
/// `Global*` delegates lack, so the dialog never ends up without localizations.
class _EnglishFallbackDelegate<T> extends LocalizationsDelegate<T> {
  const _EnglishFallbackDelegate(this._english);

  final LocalizationsDelegate<T> _english;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => _english.load(const Locale('en'));

  @override
  bool shouldReload(_EnglishFallbackDelegate<T> old) => false;
}

/// Adds nothing since the app moved to `material_ui`: its `MaterialApp`
/// already provides the theme that `gpt_markdown` and the other
/// `material_ui` readers see. Kept, with [AppThemeScopes], until the
/// scope guard in `test/app_theme_scopes_test.dart` goes with them.
class MaterialUiThemeScope extends StatelessWidget {
  const MaterialUiThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// The theme scopes the app puts above its home route. `HermesApp`, the
/// workflow tests' `pumpScreen` and the Widgetbook catalog all mount this one
/// widget, so a scope added here reaches all three. It holds none today; see
/// [MaterialUiThemeScope].
///
/// Put it above the `Navigator` (a `MaterialApp.builder`) so routes see it.
class AppThemeScopes extends StatelessWidget {
  const AppThemeScopes({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialUiThemeScope(child: child);
  }
}
