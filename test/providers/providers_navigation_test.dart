import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/providers/provider_detail_pane.dart';
import 'package:hermes_app/src/providers/providers_screen.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profiles_view.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import 'fake_provider_backend.dart';

/// "Model providers" in the chat drawer, the sidebar and the Mac Profiles
/// page, each opening the screen for the right profile.
void main() {
  late FakeProviderBackend backend;
  late BreadcrumbTrail trail;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail();
    backend = FakeProviderBackend();
    backend.server
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]));
  });

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required TargetPlatform platform,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    addTearDown(lock.dispose);
    await tester.runAsync(lock.load);
    final auth = CatalogAuth(server: backend.server, gated: true);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      withAppProviders(
        auth,
        lock: lock,
        Provider<Breadcrumbs>.value(
          value: Breadcrumbs.of(trail),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesLightTheme(platform: platform),
            home: const AppShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Map<String, Object?>> opened() => [
    for (final c in trail.recent)
      if (c.name == 'providers.opened') Map<String, Object?>.from(c.attributes),
  ];

  Future<void> openMore(WidgetTester tester) async {
    final more = find.text('More');
    if (more.evaluate().isNotEmpty) {
      await tester.tap(more);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the phone drawer lists it before Helper models', (tester) async {
    await pump(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    await tester.tap(findAppIcon(AppIcons.menu).first);
    await tester.pumpAndSettle();

    final providers = find.text('Model providers');
    expect(providers, findsOneWidget);
    expect(
      tester.getTopLeft(providers).dy,
      lessThan(tester.getTopLeft(find.text('Helper models')).dy),
    );

    await tester.tap(providers);
    await tester.pumpAndSettle();

    expect(find.byType(ProvidersScreen), findsOneWidget);
    expect(
      backend.server
          .requestsTo('GET', '/api/model/options')
          .any(
            (r) =>
                r.queryParameters['include_unconfigured'] == true &&
                r.queryParameters['profile'] == 'work',
          ),
      isTrue,
    );
    expect(opened(), [
      {'source': 'drawer'},
    ]);
  });

  testWidgets('the sidebar of a wide window opens it too', (tester) async {
    await pump(
      tester,
      size: const Size(1200, 800),
      platform: TargetPlatform.windows,
    );
    await openMore(tester);
    await tester.tap(find.text('Model providers'));
    await tester.pumpAndSettle();

    expect(find.byType(ProvidersScreen), findsOneWidget);
    expect(opened(), [
      {'source': 'sidebar'},
    ]);
  });

  testWidgets('a server without model options has no entry', (tester) async {
    backend.server.on('GET', '/api/model/options', {
      'detail': 'Not Found',
    }, status: 404);
    await pump(
      tester,
      size: const Size(1200, 800),
      platform: TargetPlatform.windows,
    );
    await openMore(tester);

    expect(find.text('Model providers'), findsNothing);
    expect(find.text('Helper models'), findsOneWidget);
  });

  testWidgets('the chat reads its model options again after a change', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(1200, 800),
      platform: TargetPlatform.windows,
    );
    int chatReads() => backend.server
        .requestsTo('GET', '/api/model/options')
        .where((r) => r.queryParameters['include_unconfigured'] != true)
        .length;
    final before = chatReads();
    await openMore(tester);
    await tester.tap(find.text('Model providers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sk-or-v1-test-aaaa-4f2a');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(chatReads(), greaterThan(before));

    final afterSave = chatReads();
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    // Back in the chat: read once more as the screen closes.
    expect(chatReads(), greaterThan(afterSave));
  });

  group('the Mac Profiles page', () {
    Future<void> openProfiles(WidgetTester tester) async {
      await pump(
        tester,
        size: const Size(1200, 800),
        platform: TargetPlatform.macOS,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(Scaffold).first,
          matching: find.text('Profiles'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-row-work')));
      await tester.pumpAndSettle();
    }

    testWidgets('lists it before Helper models with its count', (tester) async {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(
          'sk-or-v1-test-aaaa-4f2a',
        )
        ..signedIn.add('nous');
      await openProfiles(tester);

      final names = [for (final s in ProfileSection.values) s.name];
      expect(names.indexOf('providers'), names.indexOf('helperModels') - 1);
      final row = find.byKey(const ValueKey('profile-section-providers'));
      expect(
        find.descendant(of: row, matching: find.text('2 connected')),
        findsOneWidget,
      );
    });

    testWidgets('opens the screen for the selected profile', (tester) async {
      await openProfiles(tester);
      await tester.tap(find.byKey(const ValueKey('profile-section-providers')));
      await tester.pumpAndSettle();

      expect(find.byType(ProvidersScreen), findsOneWidget);
      expect(find.text('work'), findsWidgets);
      expect(
        backend.server
            .requestsTo('GET', '/api/env')
            .any((r) => r.queryParameters['profile'] == 'work'),
        isTrue,
      );
      expect(opened(), [
        {'source': 'profiles'},
      ]);
      expect(find.byType(ProviderDetailPage), findsNothing);
    });
  });
}
