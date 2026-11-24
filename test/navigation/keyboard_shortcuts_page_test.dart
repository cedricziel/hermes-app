import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/menu_layout.dart';
import 'package:hermes_app/src/navigation/keyboard_shortcuts.dart';
import 'package:hermes_app/src/navigation/widgets/keyboard_shortcuts_view.dart';

import '../support/test_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  for (final width in [360.0, 480.0]) {
    for (final platform in [TargetPlatform.linux, TargetPlatform.macOS]) {
      testWidgets('the page fits ${width.toInt()} px at 3x text on $platform', (
        tester,
      ) async {
        // Tall enough that the whole list is built, so every row is laid out.
        tester.view
          ..physicalSize = Size(width, 9000)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: KeyboardShortcutsPage(
              sections: keyboardShortcutSections(
                en,
                platform == TargetPlatform.macOS
                    ? MenuPlatform.mac
                    : MenuPlatform.desktop,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Reload's two combinations are both there, laid out.
        if (platform == TargetPlatform.linux) {
          expect(find.text('F5'), findsOneWidget);
        }
      });
    }
  }
}
