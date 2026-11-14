import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// The locales the app offers its users, a subset of
/// [AppLocalizations.supportedLocales] (every ARB file). A translation joins
/// this list only once chat, auth and setup, settings and the shell are
/// extracted, so nobody gets a half-translated app: German (`de`) is
/// translated but not released yet. See docs/architecture/localization.md.
const kReleasedLocales = <Locale>[Locale('en')];

/// The app's strings for the locale of this context: `context.l10n.settingsTitle`.
extension AppLocalizationsContext on BuildContext {
  /// English where no [AppLocalizations.delegate] is above this context, as in
  /// a test or catalog entry that builds a bare `MaterialApp`, so a widget
  /// that reads its strings here never needs a null check. A debug build
  /// outside tests says so once, since in the app it means a missing
  /// delegate.
  AppLocalizations get l10n {
    final found = Localizations.of<AppLocalizations>(this, AppLocalizations);
    if (found != null) return found;
    if (kDebugMode && !_reportedFallback && !_inTest) {
      _reportedFallback = true;
      debugPrint(
        'context.l10n: no AppLocalizations delegate above ${widget.runtimeType}; '
        'showing English. Add AppLocalizations.localizationsDelegates to '
        'its MaterialApp.',
      );
    }
    return _english;
  }
}

/// The app's strings where there is no widget tree (a notification, a
/// background run, a native surface), in the platform's preferred locale
/// resolved against [supported]. [preferred] defaults to the platform's
/// locales, read on each call.
AppLocalizations l10nForPlatformLocale({
  List<Locale>? preferred,
  List<Locale> supported = kReleasedLocales,
}) => lookupAppLocalizations(
  basicLocaleListResolution(
    preferred ?? PlatformDispatcher.instance.locales,
    supported,
  ),
);

final AppLocalizations _english = lookupAppLocalizations(const Locale('en'));

bool _reportedFallback = false;

final bool _inTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
