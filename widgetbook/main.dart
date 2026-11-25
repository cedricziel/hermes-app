import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:widgetbook/widgetbook.dart';

import 'directories.dart';
import 'environment.dart';

void main() => runApp(const HermesWidgetbook());

/// What the catalog shows while no use case is open, and for a link that
/// names none.
const catalogHomeText = 'Pick a component in the list.';

/// The app's own delegates and the `material_ui` and `cupertino_ui` ones its
/// widgets look up, as `HermesApp` lists them.
const List<LocalizationsDelegate<dynamic>> _delegates = [
  ...AppLocalizations.localizationsDelegates,
  ...kMaterialUiLocalizationsDelegates,
];

// Widgetbook's own MaterialThemeAddon takes Flutter's ThemeData; the use cases
// read material_ui's.
final _themeAddon = ThemeAddon<ThemeData>(
  themes: [
    for (final e in themes.entries) WidgetbookTheme(name: e.key, data: e.value),
  ],
  // The Scaffold is here, not in [_appBuilder]: Widgetbook paints its own
  // background between the app builder and the addons, which would cover the
  // page colour and every ink splash.
  themeBuilder: (context, theme, child) => Theme(
    data: theme,
    child: Scaffold(body: child),
  ),
);

final _localeAddon = LocalizationAddon(
  locales: AppLocalizations.supportedLocales,
  localizationsDelegates: _delegates,
  initialLocale: const Locale('en'),
);

/// What [addon] is set to in the addons panel.
T _picked<T>(WidgetbookState state, WidgetbookAddon<T> addon) =>
    addon.valueFromQueryGroup(
      FieldCodec.decodeQueryGroup(state.queryParams[addon.groupName]),
    );

/// The app every use case is built in. `Widgetbook.material`'s default builds
/// Flutter's `MaterialApp` and `Material`, which `material_ui` widgets do not
/// see: a `ListTile` or `TextField` then throws "No Material widget found",
/// and a snack bar finds no `ScaffoldMessenger`.
Widget _appBuilder(BuildContext context, Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: _picked(WidgetbookState.of(context), _themeAddon).data,
  localizationsDelegates: _delegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Tells [HermesWidgetbook], which is above Widgetbook's state, the theme
/// and the locale that are picked.
class _Picked extends WidgetbookIntegration {
  _Picked(this.onPicked);

  final void Function(ThemeData theme, Locale locale) onPicked;

  @override
  void onInit(WidgetbookState state) => onChange(state);

  @override
  void onChange(WidgetbookState state) =>
      onPicked(_picked(state, _themeAddon).data, _picked(state, _localeAddon));
}

class HermesWidgetbook extends StatefulWidget {
  const HermesWidgetbook({super.key, this.initialRoute = '/'});

  /// Where the catalog opens. `test/widgetbook_test.dart` passes a use case's
  /// link, so it builds each one inside this very widget.
  final String initialRoute;

  @override
  State<HermesWidgetbook> createState() => _HermesWidgetbookState();
}

class _HermesWidgetbookState extends State<HermesWidgetbook> {
  late final _integration = _Picked(_onPicked);
  var _theme = themes.values.first;
  var _locale = const Locale('en');
  final _heroes = MaterialApp.createMaterialHeroController();

  @override
  void dispose() {
    _heroes.dispose();
    super.dispose();
  }

  // Widgetbook reports from inside its own build, so the change waits for
  // the frame to end.
  void _onPicked(ThemeData theme, Locale locale) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (identical(theme, _theme) && locale == _locale)) return;
      setState(() {
        _theme = theme;
        _locale = locale;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = Widgetbook.material(
      initialRoute: widget.initialRoute,
      home: const Center(child: Text(catalogHomeText)),
      directories: directories,
      appBuilder: _appBuilder,
      integrations: [_integration],
      addons: [
        _themeAddon,
        _localeAddon,
        BuilderAddon(
          name: 'App theme scopes',
          builder: (context, child) => AppThemeScopes(child: child),
        ),
        TextScaleAddon(min: 1, max: 3),
        ViewportAddon([phone, desktop]),
      ],
    );
    // A dialog or sheet that asks for the root navigator leaves the workbench
    // and its [_appBuilder] app. Widgetbook's own app is Flutter's
    // `MaterialApp`, where a `material_ui` or `cupertino_ui` dialog finds no
    // localizations, so the root navigator is this one, with what such a
    // route needs around it. Such a route covers the whole window.
    //
    // A bare `Navigator`, not a second app: an app's navigator reports its
    // routes to the browser and takes the address bar's, which are
    // Widgetbook's to handle. Around it, in `MaterialApp`'s order, is what
    // `MaterialApp` gives its navigator.
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior(),
      child: HeroControllerScope(
        controller: _heroes,
        child: Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: DefaultTextEditingShortcuts(
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: TapRegionSurface(
                child: Localizations(
                  locale: _locale,
                  delegates: _delegates,
                  child: ScaffoldMessenger(
                    child: Theme(
                      data: _theme,
                      child: AppThemeScopes(
                        child: Navigator(
                          onGenerateRoute: (_) => PageRouteBuilder<void>(
                            pageBuilder: (_, _, _) => catalog,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
