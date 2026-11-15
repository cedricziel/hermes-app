import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/profiles/soul/soul_availability.dart';
import 'package:hermes_app/src/profiles/soul/soul_screen.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profiles_view.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../widgetbook/catalog_auth.dart';
import '../../support/fake_device_authenticator.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/protected_catalog_auth.dart';
import '../../support/pump_chat.dart';
import 'soul_fixtures.dart';

/// Where Personality is offered: a sidebar row after Memory (the More section
/// of a wide window and the drawer of a phone), and a section after Memory on
/// the Mac Profiles page; nowhere once the server said it has no such route.
void main() {
  late FakeHermesServer server;
  late BreadcrumbTrail trail;
  late SoulAvailability availability;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail();
    availability = SoulAvailability();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work', description: 'Day job'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/skills', <Object?>[])
      ..on('GET', '/api/learning/graph', {
        'nodes': <Object?>[],
        'edges': <Object?>[],
        'memory': <Object?>[],
      })
      ..on('GET', '/api/profiles/work/soul', {
        'content': 'You are Quill.',
        'exists': true,
      })
      ..on('GET', '/api/profiles/default/soul', {
        'content': 'You are the default.',
        'exists': true,
      });
  });

  tearDown(() => availability.dispose());

  Finder inSidebar(Finder finder) =>
      find.descendant(of: find.byType(ThreadSidebar), matching: finder);

  Iterable<Map<String, Object>> opened() => trail.recent
      .where((c) => c.name == 'profile_soul.opened')
      .map((c) => c.attributes);

  List<SingleChildWidget> providers() => [
    ChangeNotifierProvider<AuthController>(
      create: (_) => ProtectedCatalogAuth(server),
    ),
    Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
    ChangeNotifierProvider<SoulAvailability?>.value(value: availability),
  ];

  Future<void> pumpChat(WidgetTester tester, {Size? size}) => pumpChatScreen(
    tester,
    server: server,
    size: size ?? const Size(1400, 900),
    providers: providers(),
  );

  group('the More section', () {
    testWidgets('lists Personality directly after Memory', (tester) async {
      await pumpChat(tester);
      await openSidebarMore(tester);

      double top(String label) =>
          tester.getTopLeft(inSidebar(find.text(label))).dy;
      expect(top('Personality'), greaterThan(top('Memory')));
      expect(top('Personality'), lessThan(top('Messaging')));
    });

    testWidgets('opens Personality for the chat profile', (tester) async {
      await pumpChat(tester);
      await openSidebarMore(tester);

      await tester.tap(inSidebar(find.text('Personality')));
      await tester.pumpAndSettle();

      expect(find.byType(SoulScreen), findsOneWidget);
      final reads = server.requestsTo('GET', '/api/profiles/work/soul');
      expect(reads, hasLength(1));
      expect(reads.single.queryParameters, isEmpty);
      expect(find.text('You are Quill.'), findsOneWidget);
      expect(opened(), [
        {'source': 'sidebar'},
      ]);
      // Opening reads nothing else of the profile's text, and never the
      // server's active profile.
      expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
    });

    testWidgets('a chat with no profile opens default, not the active one', (
      tester,
    ) async {
      // A server without the active-profile route leaves the chat on no
      // profile at all; the active profile (`work`) is not consulted.
      server = FakeHermesServer()
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([
            profileRow(name: 'default', isDefault: true),
            profileRow(name: 'work'),
          ]),
        )
        ..on('GET', '/api/sessions', sessionListBody([]))
        ..on('GET', '/api/skills', <Object?>[])
        ..on('GET', '/api/profiles/default/soul', {
          'content': 'You are the default.',
          'exists': true,
        })
        ..on('GET', '/api/profiles/work/soul', {
          'content': 'You are Quill.',
          'exists': true,
        });
      await pumpChat(tester);
      await openSidebarMore(tester);

      await tester.tap(inSidebar(find.text('Personality')));
      await tester.pumpAndSettle();

      expect(find.byType(SoulScreen), findsOneWidget);
      expect(
        server.requestsTo('GET', '/api/profiles/default/soul'),
        hasLength(1),
      );
      expect(server.requestsTo('GET', '/api/profiles/work/soul'), isEmpty);
      expect(find.text('You are the default.'), findsOneWidget);
    });

    testWidgets('is not offered without a dashboard connection', (
      tester,
    ) async {
      await pumpChatScreen(tester);

      expect(find.text('Personality'), findsNothing);
    });

    testWidgets('is hidden once the server has no such route', (tester) async {
      await pumpChat(tester);
      await openSidebarMore(tester);
      expect(inSidebar(find.text('Personality')), findsOneWidget);

      availability.markUnsupported();
      await tester.pumpAndSettle();

      expect(inSidebar(find.text('Personality')), findsNothing);
      expect(inSidebar(find.text('Memory')), findsOneWidget);
    });

    testWidgets('a 404 from the page hides the row for the connection', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/profiles/work/soul',
        soulRouteMissing,
        status: 404,
      );
      await pumpChat(tester);
      await openSidebarMore(tester);
      await tester.tap(inSidebar(find.text('Personality')));
      await tester.pumpAndSettle();
      expect(
        find.text("This server doesn't offer personality settings."),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pumpAndSettle();
      await openSidebarMore(tester);

      expect(availability.shown, isFalse);
      expect(inSidebar(find.text('Personality')), findsNothing);
    });

    testWidgets('a missing profile does not hide the row', (tester) async {
      server.on(
        'GET',
        '/api/profiles/work/soul',
        soulProfileMissing,
        status: 404,
      );
      await pumpChat(tester);
      await openSidebarMore(tester);
      await tester.tap(inSidebar(find.text('Personality')));
      await tester.pumpAndSettle();
      expect(find.text('This profile no longer exists.'), findsOneWidget);
      expect(availability.shown, isTrue);
    });
  });

  testWidgets('the phone drawer lists Personality after Memory', (
    tester,
  ) async {
    await pumpChat(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('shell-menu')));
    await tester.pumpAndSettle();

    final drawer = find.byType(Drawer);
    double top(String label) => tester
        .getTopLeft(find.descendant(of: drawer, matching: find.text(label)))
        .dy;
    expect(top('Personality'), greaterThan(top('Memory')));
    expect(top('Personality'), lessThan(top('Messaging')));

    await tester.tap(
      find.descendant(of: drawer, matching: find.text('Personality')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SoulScreen), findsOneWidget);
    expect(server.requestsTo('GET', '/api/profiles/work/soul'), hasLength(1));
    expect(opened(), [
      {'source': 'sidebar'},
    ]);
  });

  testWidgets('the phone drawer hides it once the server lacks the route', (
    tester,
  ) async {
    availability.markUnsupported();
    await pumpChat(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('shell-menu')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Memory')),
      findsOneWidget,
    );
    expect(find.text('Personality'), findsNothing);
  });

  group('the Mac Profiles page', () {
    Future<void> pumpShell(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1200, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = ProtectedCatalogAuth(server);
      addTearDown(auth.dispose);
      // The app stays covered until App Lock has read its setting.
      final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
      addTearDown(lock.dispose);
      await tester.runAsync(lock.load);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SoulAvailability?>.value(
              value: availability,
            ),
            Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          ],
          child: withAppProviders(
            auth,
            lock: lock,
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
              home: const AppShell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(inSidebar(find.text('Profiles')));
      await tester.pumpAndSettle();
    }

    final row = find.byKey(const ValueKey('profile-section-personality'));

    testWidgets('has a Personality section after Memory', (tester) async {
      await pumpShell(tester);

      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Personality')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text('Who Hermes is and how it talks'),
        ),
        findsOneWidget,
      );
      final memory = tester.getTopLeft(
        find.byKey(const ValueKey('profile-section-memory')),
      );
      final messaging = tester.getTopLeft(
        find.byKey(const ValueKey('profile-section-messaging')),
      );
      expect(tester.getTopLeft(row).dy, greaterThan(memory.dy));
      expect(tester.getTopLeft(row).dy, lessThan(messaging.dy));
    });

    testWidgets('shows no preview and reads no text for the list', (
      tester,
    ) async {
      await pumpShell(tester);

      expect(find.text('You are Quill.'), findsNothing);
      expect(server.requestsTo('GET', '/api/profiles/work/soul'), isEmpty);
      expect(server.requestsTo('GET', '/api/profiles/default/soul'), isEmpty);
    });

    testWidgets('pushes the page for the selected profile', (tester) async {
      await pumpShell(tester);

      // The shell's socket keeps asking for tickets, so the page never
      // settles; a few frames are enough for the reads.
      Future<void> frames() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      await tester.tap(find.byKey(const ValueKey('profile-row-work')));
      await frames();
      await tester.tap(row);
      await frames();

      expect(find.byType(SoulScreen), findsOneWidget);
      expect(server.requestsTo('GET', '/api/profiles/work/soul'), hasLength(1));
      expect(server.requestsTo('GET', '/api/profiles/default/soul'), isEmpty);
      expect(find.text('You are Quill.'), findsOneWidget);
      expect(opened(), [
        {'source': 'profiles_page'},
      ]);
      // The page has a bar with Back, and Save beneath the editor.
      expect(find.byKey(const Key('settings-back')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
    });

    testWidgets('is gone once the server lacks the route', (tester) async {
      await pumpShell(tester);
      expect(row, findsOneWidget);

      availability.markUnsupported();
      await tester.pumpAndSettle();

      expect(row, findsNothing);
      expect(
        find.byKey(const ValueKey('profile-section-memory')),
        findsOneWidget,
      );
    });
  });

  test('Personality sits directly after Memory in the sections', () {
    final names = ProfileSection.values.map((s) => s.name).toList();
    expect(names.indexOf('personality'), names.indexOf('memory') + 1);
  });
}
