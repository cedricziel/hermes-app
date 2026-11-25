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

/// The theme picked in the addons panel.
ThemeData _pickedTheme(WidgetbookState state) => _themeAddon
    .valueFromQueryGroup(
      FieldCodec.decodeQueryGroup(state.queryParams[_themeAddon.groupName]),
    )
    .data;

/// The app every use case is built in. `Widgetbook.material`'s default builds
/// Flutter's `MaterialApp` and `Material`, which `material_ui` widgets do not
/// see: a `ListTile` or `TextField` then throws "No Material widget found".
Widget _appBuilder(BuildContext context, Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: _pickedTheme(WidgetbookState.of(context)),
  localizationsDelegates: _delegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Tells [HermesWidgetbook], which is above Widgetbook's state, the theme
/// that is picked.
class _PickedTheme extends WidgetbookIntegration {
  _PickedTheme(this.onPicked);

  final ValueChanged<ThemeData> onPicked;

  @override
  void onInit(WidgetbookState state) => onPicked(_pickedTheme(state));

  @override
  void onChange(WidgetbookState state) => onPicked(_pickedTheme(state));
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
  late final _picked = _PickedTheme(_onPicked);
  var _theme = themes.values.first;

  // Widgetbook reports from inside its own build, so the change waits for
  // the frame to end.
  void _onPicked(ThemeData theme) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !identical(theme, _theme)) setState(() => _theme = theme);
    });
  }

  @override
  Widget build(BuildContext context) {
    // A dialog or sheet that asks for the root navigator leaves the workbench
    // and its [_appBuilder] app. Widgetbook's own app is Flutter's
    // `MaterialApp`, where a `material_ui` or `cupertino_ui` dialog finds no
    // localizations, so this app is around it and the root navigator is this
    // one's. Such a route covers the whole window and is in the system
    // language, not the Locale addon's.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppThemeScopes(child: child!),
      home: Widgetbook.material(
        initialRoute: widget.initialRoute,
        home: const Center(child: Text(catalogHomeText)),
        directories: directories,
        appBuilder: _appBuilder,
        integrations: [_picked],
        addons: [
          _themeAddon,
          LocalizationAddon(
            locales: AppLocalizations.supportedLocales,
            localizationsDelegates: _delegates,
            initialLocale: const Locale('en'),
          ),
          BuilderAddon(
            name: 'App theme scopes',
            builder: (context, child) => AppThemeScopes(child: child),
          ),
          TextScaleAddon(min: 1, max: 3),
          ViewportAddon([phone, desktop]),
        ],
      ),
    );
  }
}
