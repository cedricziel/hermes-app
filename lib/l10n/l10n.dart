import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// The app's strings for the locale of this context: `context.l10n.settingsTitle`.
extension AppLocalizationsContext on BuildContext {
  /// English where no [AppLocalizations.delegate] is above this context, as in
  /// a test or catalog entry that builds a bare `MaterialApp`, so a widget
  /// that reads its strings here never needs a null check.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? _english;
}

final AppLocalizations _english = lookupAppLocalizations(const Locale('en'));
