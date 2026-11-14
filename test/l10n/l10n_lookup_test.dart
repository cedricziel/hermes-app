import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';

void main() {
  group('l10nForPlatformLocale', () {
    test('gives English for a locale that is not released', () {
      final l10n = l10nForPlatformLocale(preferred: const [Locale('fr', 'FR')]);
      expect(l10n.localeName, 'en');
      expect(l10n.settingsTitle, 'Settings');
    });

    test('does not use German before it is released', () {
      final l10n = l10nForPlatformLocale(preferred: const [Locale('de', 'DE')]);
      expect(l10n.localeName, 'en');
    });

    test('picks the first preferred locale that is supported', () {
      final l10n = l10nForPlatformLocale(
        preferred: const [Locale('fr'), Locale('de', 'AT')],
        supported: AppLocalizations.supportedLocales,
      );
      expect(l10n.localeName, 'de');
      expect(l10n.settingsTitle, 'Einstellungen');
    });

    test('gives English for an empty preference list', () {
      expect(l10nForPlatformLocale(preferred: const []).localeName, 'en');
    });

    test('reads the platform locales without a binding', () {
      // The test platform reports en_US.
      expect(l10nForPlatformLocale().localeName, 'en');
    });
  });
}
