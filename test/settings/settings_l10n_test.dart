import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/settings/about_dialog.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/settings/widgets/helper_model_list.dart';
import 'package:hermes_app/src/models/auxiliary_models.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Widget _german(Widget home) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('the About dialog speaks German under a German locale', (
    tester,
  ) async {
    await tester.pumpWidget(_german(const AppAboutDialog(version: '0.1.31')));

    expect(find.text('Über'), findsOneWidget);
    expect(find.text('Fehler melden'), findsOneWidget);
    expect(find.text('Report a bug'), findsNothing);
  });

  testWidgets('the settings dialog labels its rows and values in German', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (_) async {
          return null;
        });
    final theme = ThemeController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: theme,
        child: _german(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsDialog(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Erscheinungsbild'), findsOneWidget);
    expect(find.text('Wie das System'), findsOneWidget);
    expect(find.text('Server wechseln'), findsOneWidget);
  });

  testWidgets('the helper model footer fills its placeholder in German', (
    tester,
  ) async {
    await tester.pumpWidget(
      _german(
        Scaffold(
          body: HelperModelList(
            models: const AuxiliaryModels(
              slots: [AuxiliarySlot(task: 'vision')],
              main: ModelChoice('openai', 'gpt-5-pro'),
            ),
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Das Hauptmodell ist gpt-5-pro.'),
      findsOneWidget,
    );
    expect(find.text('Hauptmodell'), findsOneWidget);
  });

  testWidgets('without a delegate above it, context.l10n is English', (
    tester,
  ) async {
    late String title;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          title = context.l10n.settingsTitle;
          return const SizedBox();
        },
      ),
    );

    expect(title, 'Settings');
  });
}
