import 'package:flutter/widgets.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';

/// The localization delegates every test `MaterialApp` takes: the app's own
/// (`AppLocalizations` plus Flutter's Material, Cupertino and Widgets ones)
/// and the `material_ui` and `cupertino_ui` ones its widgets look up. Without
/// the second group a `material_ui` widget fails in a non-English locale with
/// "No MaterialLocalizations found". Use this instead of
/// `AppLocalizations.localizationsDelegates` (`test.localization-delegates`).
const List<LocalizationsDelegate<dynamic>> kTestLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      ...AppLocalizations.localizationsDelegates,
      ...kMaterialUiLocalizationsDelegates,
    ];
