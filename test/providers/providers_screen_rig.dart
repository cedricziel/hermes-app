import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';
import 'package:hermes_app/src/providers/providers_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'fake_provider_backend.dart';

/// A [ProvidersScreen] on a stateful fake Hermes, in a themed app at [size].
class ProvidersRig {
  ProvidersRig({FakeProviderBackend? backend})
    : backend = backend ?? FakeProviderBackend();

  final FakeProviderBackend backend;
  final launched = <Uri>[];
  var changed = 0;

  ProvidersRepository get repository => ProvidersRepository(
    backend.server.client().raw,
    checkBudget: const Duration(milliseconds: 300),
    recommendBudget: const Duration(milliseconds: 300),
  );

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.iOS,
    Brightness brightness = Brightness.light,
    String? profile = 'work',
    ProvidersEntry entry = ProvidersEntry.sidebar,
    List<SingleChildWidget> providers = const [],
    bool pushed = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final screen = ProvidersScreen(
      repository: repository,
      profile: profile,
      entry: entry,
      platform: platform,
      onChanged: () => changed++,
      launchLink: (uri) async {
        launched.add(uri);
        return true;
      },
    );
    final home = providers.isEmpty
        ? screen
        : MultiProvider(providers: providers, child: screen);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: brightness == Brightness.dark
            ? buildHermesDarkTheme(platform: platform)
            : buildHermesLightTheme(platform: platform),
        home: pushed
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => home)),
                    child: const Text('open providers'),
                  ),
                ),
              )
            : home,
      ),
    );
    if (pushed) {
      await tester.tap(find.text('open providers'));
    }
    await settle(tester);
  }

  /// Lets the fake server answer and the frames play out.
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
}
