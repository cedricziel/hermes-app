import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/deep_links/deep_link_listener.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_share_inbox.dart';
import '../support/pump_chat.dart';

/// How the shell acts on a `hermes://` link. The chat is the mock one (no
/// repository), whose threads are t1 to t3.
void main() {
  late FakeHermesServer server;
  late StreamController<Uri> links;
  late StreamController<void> signedOut;
  DeepLinks? deepLinks;
  late BreadcrumbTrail trail;
  Completer<void>? firstFrame;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    links = StreamController<Uri>.broadcast(sync: true);
    signedOut = StreamController<void>.broadcast(sync: true);
    trail = BreadcrumbTrail(capacity: 50);
    firstFrame = null;
    deepLinks = null;
  });

  /// Built inside the test body: a listener made in setUp would run its
  /// callbacks outside the test's fake async zone.
  DeepLinks startDeepLinks() => deepLinks ??= DeepLinks(
    links: links.stream,
    signedOut: signedOut.stream,
    firstFrame: (firstFrame = Completer<void>()).future,
    breadcrumbs: Breadcrumbs.of(trail),
  );

  tearDown(() async {
    deepLinks?.dispose();
    await links.close();
    await signedOut.close();
  });

  void kanbanPlugin({required bool on}) => server.on(
    'GET',
    '/api/dashboard/plugins',
    on
        ? [
            {'name': 'kanban'},
          ]
        : <Object?>[],
  );

  void cronRoutes({required bool on}) => server
    ..on(
      'GET',
      '/api/cron/delivery-targets',
      cronDeliveryTargets,
      status: on ? 200 : 404,
    )
    ..on('GET', '/api/cron/jobs', [cronJobRow()])
    ..on('GET', '/api/cron/jobs/job1', cronJobRow())
    ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});

  Future<void> pumpShell(
    WidgetTester tester, {
    bool settle = true,
    Size size = const Size(1400, 900),
    AppLockController? lock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ChangeNotifierProvider<DeepLinks?>.value(value: startDeepLinks()),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          if (lock != null)
            ChangeNotifierProvider<AppLockController>.value(value: lock),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          builder: lock == null
              ? null
              : (context, child) => AppLockGate(child: child!),
          home: AppShell(
            plugins: HermesPluginsRepository(server.client().raw),
            cron: HermesCronRepository(server.client().raw),
            kanbanBuilder: (_) => Column(
              children: [
                const Text('the board'),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(body: Text('the task')),
                      ),
                    ),
                    child: const Text('open a task'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    if (firstFrame case final frame? when !frame.isCompleted) frame.complete();
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, String url) async {
    links.add(Uri.parse(url));
    await tester.pumpAndSettle();
  }

  /// The page in front; Chat when the shell has no other page.
  int selectedTab(WidgetTester tester) {
    final stack = find.byType(IndexedStack, skipOffstage: false);
    return stack.evaluate().isEmpty
        ? 0
        : tester.widget<IndexedStack>(stack.first).index!;
  }

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(composerField).controller.text;

  String? selectedChat(WidgetTester tester) =>
      tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).selectedId;

  List<String> crumbs() => [
    for (final c in trail.recent)
      if (c.name.startsWith('deeplink.')) '${c.name} ${c.attributes}',
  ];

  group('chat', () {
    testWidgets('opens the chat with its prompt, leaving the other tab', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      cronRoutes(on: false);
      await pumpShell(tester);
      await open(tester, 'hermes://kanban');
      expect(selectedTab(tester), 1);

      await open(tester, 'hermes://chat?id=t2&prompt=Yes%2C%20book%20it');

      expect(selectedTab(tester), 0);
      expect(selectedChat(tester), 't2');
      expect(composerText(tester), 'Yes, book it');
    });

    testWidgets('closes a screen pushed over the tab it leaves', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      cronRoutes(on: false);
      await pumpShell(tester);
      await open(tester, 'hermes://kanban');
      await tester.tap(find.text('open a task'));
      await tester.pumpAndSettle();
      expect(find.text('the task'), findsOneWidget);

      await open(tester, 'hermes://chat?id=t3');

      expect(find.text('the task'), findsNothing);
      expect(selectedChat(tester), 't3');
    });

    testWidgets('says so when the chat does not exist', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);
      await pumpShell(tester);

      await open(tester, 'hermes://chat?id=nope&prompt=hi');

      expect(find.text('Could not open that chat.'), findsOneWidget);
      expect(composerText(tester), isEmpty);
    });
  });

  testWidgets('new fills the composer', (tester) async {
    kanbanPlugin(on: false);
    cronRoutes(on: false);
    await pumpShell(tester);

    await open(tester, 'hermes://new?prompt=Plan%20a%20trip%20%26%20book');

    expect(composerText(tester), 'Plan a trip & book');
  });

  testWidgets('requests opens the chat list when nothing waits', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    cronRoutes(on: false);
    await pumpShell(tester);
    await open(tester, 'hermes://kanban');

    await open(tester, 'hermes://requests');

    expect(selectedTab(tester), 0);
  });

  group('kanban', () {
    testWidgets('selects the tab', (tester) async {
      kanbanPlugin(on: true);
      cronRoutes(on: false);
      await pumpShell(tester);

      await open(tester, 'hermes://kanban');

      expect(selectedTab(tester), 1);
      expect(find.text('the board'), findsOneWidget);
    });

    testWidgets('waits for the server check', (tester) async {
      kanbanPlugin(on: true);
      cronRoutes(on: false);
      await pumpShell(tester, settle: false);

      links.add(Uri.parse('hermes://kanban'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(crumbs(), [
        'deeplink.opened {kind: kanban, cold: false, waited: true}',
      ]);
    });

    testWidgets('is ignored by a server without the plugin', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);
      await pumpShell(tester);

      await open(tester, 'hermes://kanban');

      expect(selectedTab(tester), 0);
      expect(crumbs(), ['deeplink.ignored {reason: unavailable}']);
    });

    testWidgets('is ignored when the check that was awaited finds no plugin', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);
      await pumpShell(tester, settle: false);

      links.add(Uri.parse('hermes://kanban'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
      expect(crumbs(), ['deeplink.ignored {reason: unavailable}']);
    });
  });

  group('schedules', () {
    testWidgets('selects the tab', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      await pumpShell(tester, size: const Size(400, 800));

      await open(tester, 'hermes://schedules');

      expect(selectedTab(tester), 1);
      expect(find.text('Morning brief'), findsOneWidget);
    });

    testWidgets('opens a job', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      await pumpShell(tester, size: const Size(400, 800));

      await open(tester, 'hermes://schedules?profile=work&job=job1');

      expect(selectedTab(tester), 1);
      expect(find.text('Say good morning'), findsOneWidget);
    });

    testWidgets('waits for the server check', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      await pumpShell(tester, settle: false, size: const Size(400, 800));

      links.add(Uri.parse('hermes://schedules?profile=work&job=job1'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('Say good morning'), findsOneWidget);
    });

    testWidgets('is ignored by a server without cron', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);
      await pumpShell(tester, size: const Size(400, 800));

      await open(tester, 'hermes://schedules');

      expect(selectedTab(tester), 0);
      expect(crumbs(), ['deeplink.ignored {reason: unavailable}']);
    });
  });

  group('a link that came before the shell', () {
    testWidgets('is applied once, when the shell mounts', (tester) async {
      kanbanPlugin(on: true);
      cronRoutes(on: false);
      startDeepLinks();
      links.add(Uri.parse('hermes://kanban'));

      await pumpShell(tester);

      expect(selectedTab(tester), 1);
      expect(deepLinks?.pending, isNull);
      expect(crumbs(), [
        'deeplink.opened {kind: kanban, cold: true, waited: true}',
      ]);
    });
  });

  group('breadcrumbs', () {
    testWidgets('hold the kind and flags and nothing of the link', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);
      await pumpShell(tester);

      await open(tester, 'hermes://new?profile=work&prompt=secret%20text');
      await open(tester, 'hermes://chat?id=t1');
      await open(tester, 'hermes://requests');

      expect(crumbs(), [
        'deeplink.opened {kind: new, cold: false, waited: false}',
        'deeplink.opened {kind: chat, cold: false, waited: false}',
        'deeplink.opened {kind: requests, cold: false, waited: false}',
      ]);
      expect(
        [for (final c in trail.recent) '${c.name} ${c.attributes}'].join(),
        isNot(contains('secret')),
      );
    });
  });

  group('app lock', () {
    testWidgets('holds a link, dictation included, until the app is unlocked', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);
      final device = FakeDeviceAuthenticator();
      late AppLockController lock;
      await tester.runAsync(() async {
        final first = AppLockController(authenticator: device);
        await first.load();
        await first.setEnabled(true);
        first.dispose();
        device.succeeds = false;
        lock = AppLockController(authenticator: device);
        await lock.load();
      });
      addTearDown(lock.dispose);
      await pumpShell(tester, lock: lock);
      expect(lock.locked, isTrue);

      await open(tester, 'hermes://new?dictate=1&prompt=Private');

      expect(deepLinks?.pending, isNotNull);
      expect(crumbs(), isEmpty);
      final covered = find.descendant(
        of: find.byKey(chatComposerFieldKey, skipOffstage: false),
        matching: find.byType(EditableText, skipOffstage: false),
      );
      expect(tester.widget<EditableText>(covered).controller.text, isEmpty);

      device.succeeds = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(deepLinks?.pending, isNull);
      expect(composerText(tester), 'Private');
      expect(crumbs(), [
        'deeplink.opened {kind: new, cold: false, waited: true}',
      ]);
    });
  });

  group('a server that could not be asked', () {
    testWidgets('keeps a Kanban link until a check answers', (tester) async {
      server.on('GET', '/api/dashboard/plugins', {'detail': 'x'}, status: 503);
      cronRoutes(on: false);
      await pumpShell(tester);

      await open(tester, 'hermes://kanban');
      expect(selectedTab(tester), 0);
      expect(crumbs(), isEmpty);

      kanbanPlugin(on: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(crumbs(), [
        'deeplink.opened {kind: kanban, cold: false, waited: true}',
      ]);
    });

    testWidgets('ignores a link once the server says it lacks the tab', (
      tester,
    ) async {
      server.on('GET', '/api/dashboard/plugins', {'detail': 'x'}, status: 503);
      cronRoutes(on: false);
      await pumpShell(tester);
      await open(tester, 'hermes://kanban');

      kanbanPlugin(on: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
      expect(crumbs(), ['deeplink.ignored {reason: unavailable}']);
    });
  });
}
