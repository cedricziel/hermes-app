import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/deep_links/deep_link_listener.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_create_screen.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/schedules/blueprint_screens.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_detail.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/chat/widgets/chat_thread_view.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/skills/skill_editor_screen.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_device_authenticator.dart';
import 'support/fake_conversation_window_host.dart';
import 'support/fake_notification_service.dart';
import 'support/fake_share_inbox.dart';
import 'support/fake_session_auth.dart';
import 'support/kanban_fixtures.dart';
import 'support/mac_commands_builder.dart';
import 'support/pump_chat.dart' show composerField, openThread;

/// The Kanban tab exists only while the server has the plugin on.
void main() {
  late FakeHermesServer server;
  late FakeShareInbox inbox;
  late FakeNotificationService notifications;

  /// Boards built and torn down, in the order they happened.
  late List<String> boardLog;

  setUp(() {
    boardLog = [];
    inbox = FakeShareInbox();
    notifications = FakeNotificationService();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
    NotificationSettings? settings,
    bool settle = true,
    WidgetBuilder? kanbanBuilder,
    TargetPlatform? platform,
    MacCommandRegistry? commands,
    BreadcrumbTrail? trail,
    AppLockController? lock,
    DeepLinks? links,
    ConversationWindows? windows,
    AuthController? auth,
    HermesRepositories? repositories,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          if (auth == null)
            ChangeNotifierProvider<AuthController>(create: (_) => _ShellAuth())
          else
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(inbox)..start(),
          ),
          Provider<NotificationService>.value(value: notifications),
          if (repositories != null)
            Provider<HermesRepositories>.value(value: repositories),
          if (lock != null)
            ChangeNotifierProvider<AppLockController>.value(value: lock),
          if (links != null)
            ChangeNotifierProvider<DeepLinks?>.value(value: links),
          if (windows != null)
            ChangeNotifierProvider<ConversationWindows?>.value(value: windows),
          if (trail != null)
            Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          if (settings != null)
            ChangeNotifierProvider<NotificationSettings>.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: platform),
          builder: (context, child) {
            final content =
                macCommandsBuilder(commands)?.call(context, child) ?? child!;
            return lock == null ? content : AppLockGate(child: content);
          },
          home: AppShell(
            plugins: HermesPluginsRepository(server.client().raw),
            cron: HermesCronRepository(server.client().raw),
            kanbanBuilder: kanbanBuilder ?? (_) => _Board(boardLog),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  void kanbanPlugin({required bool on}) => server.on(
    'GET',
    '/api/dashboard/plugins',
    on
        ? [
            {'name': 'kanban'},
          ]
        : <Object?>[],
  );

  /// Opens the drawer of a narrow layout: Chat's own, or the shell's on
  /// another page.
  Future<void> openMenu(WidgetTester tester) async {
    if (find
        .byTooltip('Open navigation menu')
        .hitTestable()
        .evaluate()
        .isEmpty) {
      await tester.tap(find.byType(BackButton).hitTestable().first);
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.byTooltip('Open navigation menu').hitTestable().first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> closeMenu(WidgetTester tester) async {
    tester
        .state<ScaffoldState>(
          find
              .ancestor(
                of: find.byType(Drawer),
                matching: find.byType(Scaffold),
              )
              .first,
        )
        .closeDrawer();
    await tester.pumpAndSettle();
  }

  /// The destinations in the drawer of a narrow layout, or null without any.
  Future<List<String>?> navigationLabels(WidgetTester tester) async {
    await openMenu(tester);
    final found = find.byType(ShellNavigation);
    final labels = found.evaluate().isEmpty
        ? null
        : [
            for (final d in tester.widget<ShellNavigation>(found).destinations)
              d.label,
          ];
    await closeMenu(tester);
    return labels;
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await openMenu(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(ShellNavigation),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('breadcrumbs', () {
    testWidgets('record each destination the user moves to', (tester) async {
      kanbanPlugin(on: true);
      final trail = BreadcrumbTrail();
      await pumpShell(tester, size: const Size(400, 800), trail: trail);

      await openTab(tester, 'Kanban');
      await openTab(tester, 'Chat');

      expect(
        [for (final c in trail.recent) '${c.name} ${c.attributes}'],
        [
          'nav.destination {destination: kanban}',
          'nav.destination {destination: chat}',
        ],
      );
    });

    testWidgets('do not repeat a destination that is already in front', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      final trail = BreadcrumbTrail();
      await pumpShell(tester, size: const Size(400, 800), trail: trail);

      await openTab(tester, 'Chat');

      expect(trail.recent, isEmpty);
    });

    testWidgets('record the app going to the background and coming back', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      final trail = BreadcrumbTrail();
      await pumpShell(tester, size: const Size(400, 800), trail: trail);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        [for (final c in trail.recent) '${c.name} ${c.attributes}'],
        ['app.lifecycle {state: paused}', 'app.lifecycle {state: resumed}'],
      );
    });

    Future<void> runnerReportsWindowless(
      WidgetTester tester, {
      required bool windowless,
    }) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'hermes_app/app',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('windowless', windowless),
      ),
      (_) {},
    );

    testWidgets(
      'record a macOS app that has no window, not one that is covered',
      (tester) async {
        kanbanPlugin(on: true);
        final trail = BreadcrumbTrail();
        await pumpShell(tester, size: const Size(900, 700), trail: trail);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pumpAndSettle();
        expect(trail.recent, isEmpty);

        await runnerReportsWindowless(tester, windowless: true);
        await runnerReportsWindowless(tester, windowless: false);
        await tester.pumpAndSettle();

        expect(
          [for (final c in trail.recent) '${c.name} ${c.attributes}'],
          ['app.lifecycle {state: windowless}'],
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  testWidgets('shows no navigation while the plugin is off', (tester) async {
    kanbanPlugin(on: false);

    await pumpShell(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsNothing);
    expect(await navigationLabels(tester), isNull);
  });

  testWidgets('offers Kanban in the drawer on a phone, with no bottom bar', (
    tester,
  ) async {
    kanbanPlugin(on: true);

    await pumpShell(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsNothing);
    await openTab(tester, 'Kanban');

    expect(find.text('the board'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('a page other than Chat opens the destinations from its menu', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openTab(tester, 'Kanban');
    expect(find.byKey(const Key('shell-menu')), findsOneWidget);

    await openTab(tester, 'Chat');

    expect(find.text('the board'), findsNothing);
    expect(find.byKey(const Key('shell-menu')), findsOneWidget);
  });

  testWidgets('lists the destinations in the sidebar on a wide screen', (
    tester,
  ) async {
    kanbanPlugin(on: true);

    await pumpShell(tester, size: const Size(1400, 900));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.byType(ShellNavigation),
      ),
      findsOneWidget,
    );
  });

  group('on an iPad', () {
    for (final size in const [Size(834, 1194), Size(744, 1133)]) {
      testWidgets('shows the sidebar in portrait at ${size.width.toInt()}', (
        tester,
      ) async {
        kanbanPlugin(on: true);

        await pumpShell(tester, size: size, platform: TargetPlatform.iOS);

        expect(
          find.descendant(
            of: find.byType(ThreadSidebar),
            matching: find.byType(ShellNavigation),
          ),
          findsOneWidget,
        );
        expect(find.byTooltip('Open navigation menu'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps the drawer on an iPhone', (tester) async {
      kanbanPlugin(on: true);

      await pumpShell(
        tester,
        size: const Size(390, 844),
        platform: TargetPlatform.iOS,
      );

      expect(find.byTooltip('Open navigation menu'), findsWidgets);
    });

    testWidgets('keeps the drawer on Android at 834', (tester) async {
      kanbanPlugin(on: true);

      await pumpShell(
        tester,
        size: const Size(834, 1194),
        platform: TargetPlatform.android,
      );

      expect(find.byTooltip('Open navigation menu'), findsWidgets);
    });
  });

  testWidgets('keeps the destinations in place on the board of a wide screen', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(1400, 900));
    final inChat = tester.getTopLeft(find.text('Kanban'));

    await tester.tap(find.text('Kanban'));
    await tester.pumpAndSettle();

    expect(find.text('the board'), findsOneWidget);
    expect(find.byType(ShellSidebar), findsOneWidget);
    expect(tester.getTopLeft(find.text('Kanban')), inChat);
  });

  testWidgets('drops the tab when the plugin is turned off', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    expect(await navigationLabels(tester), ['Chat', 'Kanban']);

    kanbanPlugin(on: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(await navigationLabels(tester), isNull);
  });

  testWidgets('ignores a slower answer that a newer check has superseded', (
    tester,
  ) async {
    final first = Completer<FakeResponse>();
    var calls = 0;
    server.onRequest('GET', '/api/dashboard/plugins', (_) {
      calls++;
      return calls == 1 ? first.future : (status: 200, body: <Object?>[]);
    });
    await pumpShell(tester, size: const Size(400, 800));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    first.complete((
      status: 200,
      body: [
        {'name': 'kanban'},
      ],
    ));
    await tester.pumpAndSettle();

    expect(await navigationLabels(tester), isNull);
  });

  Future<void> openKanban(WidgetTester tester) => openTab(tester, 'Kanban');

  /// The page in front: its index among the destinations. The shell's stack
  /// is the outermost one, and is offstage while a page is pushed over it.
  int selectedTab(WidgetTester tester) => tester
      .widget<IndexedStack>(
        find.byType(IndexedStack, skipOffstage: false).first,
      )
      .index!;

  Future<void> flipPlugin(WidgetTester tester, {required bool on}) async {
    kanbanPlugin(on: on);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  Future<void> editSkill(
    WidgetTester tester, {
    Future<String?> Function(String, String, String)? onSave,
  }) async {
    Navigator.of(tester.element(find.byType(AppShell))).push<void>(
      MaterialPageRoute(
        builder: (_) => SkillEditorScreen.edit(
          name: 'example',
          initialText: 'Original skill',
          onSave: onSave ?? (_, _, _) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved skill');
    await tester.pump();
  }

  String? selectedChat(WidgetTester tester) {
    final detail = find.byType(ChatThreadView, skipOffstage: false);
    if (detail.evaluate().isNotEmpty) {
      return tester.widget<ChatThreadView>(detail).thread?.id;
    }
    return tester
        .widget<ThreadSidebar>(find.byType(ThreadSidebar, skipOffstage: false))
        .selectedId;
  }

  ({FakeConversationWindowHost host, ConversationWindows windows}) windowHost({
    AuthController? auth,
  }) {
    final host = FakeConversationWindowHost();
    final windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      connection: () => auth == null || auth.protectedRequestsAllowed
          ? (baseUrl: 'https://hermes.test', authRequired: false)
          : null,
      ownerKey: () =>
          auth == null || auth.protectedRequestsAllowed ? 'test-owner' : null,
      headers: ({rejected}) async => {},
    );
    addTearDown(host.dispose);
    addTearDown(windows.dispose);
    if (auth != null) windows.bindSession(auth);
    return (host: host, windows: windows);
  }

  group('guarded notification navigation', () {
    testWidgets('retains the editor and delivers only the latest tap', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      await pumpShell(tester, size: const Size(400, 800));
      await openThread(tester, "Summarize last night's run logs");
      await openKanban(tester);
      await editSkill(tester);

      notifications.tap('t2');
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(selectedTab(tester), 1);
      expect(selectedChat(tester), 't1');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      notifications.tap('t3');
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Unsaved skill'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
      expect(selectedChat(tester), 't3');
    });

    testWidgets('retains the draft and error when saving fails', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      await pumpShell(tester, size: const Size(1400, 900));
      final saved = Completer<String?>();
      await editSkill(tester, onSave: (_, _, _) => saved.future);
      await tester.tap(find.text('Save'));
      await tester.pump();
      notifications.tap('t2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(selectedChat(tester), 't1');
      saved.complete('The test save failed');
      await tester.pumpAndSettle();
      expect(find.text('Unsaved skill'), findsOneWidget);
      expect(find.text('The test save failed'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(selectedChat(tester), 't2');
    });

    testWidgets('defers an unsent-question draft until the editor closes', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      await pumpShell(tester, size: const Size(1400, 900));
      await editSkill(tester);
      notifications.tapTarget(
        const NotificationTarget.newChat(prompt: 'Pending question'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(selectedChat(tester), 't1');
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'Pending question',
      );
    });

    testWidgets('resumes a locked tap without a deep-link provider', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      late AppLockController lock;
      await tester.runAsync(() async {
        lock = AppLockController(
          authenticator: FakeDeviceAuthenticator(),
          coverWhenInactive: true,
        );
        await lock.load();
        await lock.setEnabled(true);
      });
      addTearDown(lock.dispose);
      await pumpShell(tester, size: const Size(1400, 900), lock: lock);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      notifications.tap('t2');
      await tester.pumpAndSettle();
      expect(selectedChat(tester), 't1');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(selectedChat(tester), 't2');
    });

    testWidgets('ignores a host callback after shell disposal', (tester) async {
      kanbanPlugin(on: false);
      await pumpShell(tester, size: const Size(1400, 900));
      final dispatch = tester
          .widget<ChatScreen>(find.byType(ChatScreen))
          .onExternalNavigation!;
      await tester.pumpWidget(const SizedBox.shrink());
      var delivered = false;

      dispatch(() => delivered = true, false);

      expect(delivered, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rejected launch preserves a discovery-held link', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      final availability = Completer<FakeResponse>();
      server
        ..onRequest(
          'GET',
          '/api/cron/delivery-targets',
          (_) => availability.future,
        )
        ..on('GET', '/api/cron/jobs', [cronJobRow()])
        ..on('GET', '/api/cron/jobs/job1', cronJobRow())
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      final urls = StreamController<Uri>.broadcast(sync: true);
      final links = DeepLinks(
        links: urls.stream,
        signedOut: const Stream.empty(),
        firstFrame: Future.value(),
      );
      addTearDown(links.dispose);
      addTearDown(urls.close);
      await pumpShell(
        tester,
        size: const Size(400, 800),
        links: links,
        settle: false,
      );
      urls.add(Uri.parse('hermes://schedules?profile=work&job=job1'));
      await tester.pumpAndSettle();
      final dispatch = tester
          .widget<ChatScreen>(find.byType(ChatScreen))
          .onExternalNavigation!;
      var launched = false;
      dispatch(() => launched = true, true);
      availability.complete((status: 200, body: cronDeliveryTargets));
      await tester.pumpAndSettle();

      expect(launched, isFalse);
      expect(find.text('Say good morning'), findsOneWidget);
    });

    testWidgets('an unavailable job never opens after later discovery', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      server.on('GET', '/api/cron/delivery-targets', {}, status: 404);
      final trail = BreadcrumbTrail(capacity: 50);
      await pumpShell(tester, size: const Size(400, 800), trail: trail);
      notifications.tapJob('job1', profile: 'work');
      await tester.pumpAndSettle();
      final ignored = trail.recent.singleWhere(
        (crumb) => crumb.name == 'nav.notification.ignored',
      );
      expect(ignored.attributes, {'kind': 'job', 'reason': 'unavailable'});
      server
        ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
        ..on('GET', '/api/cron/jobs', [cronJobRow()])
        ..on('GET', '/api/cron/jobs/job1', cronJobRow())
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
      expect(server.requestsTo('GET', '/api/cron/jobs/job1'), isEmpty);
    });

    testWidgets('a held job is discarded when discovery confirms unavailable', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      final availability = Completer<FakeResponse>();
      server.onRequest(
        'GET',
        '/api/cron/delivery-targets',
        (_) => availability.future,
      );
      final trail = BreadcrumbTrail(capacity: 50);
      await pumpShell(
        tester,
        size: const Size(400, 800),
        trail: trail,
        settle: false,
      );
      notifications.tapJob('job1', profile: 'work');
      await tester.pumpAndSettle();
      availability.complete((status: 404, body: {}));
      await tester.pumpAndSettle();
      final ignored = trail.recent.singleWhere(
        (crumb) => crumb.name == 'nav.notification.ignored',
      );
      expect(ignored.attributes, {'kind': 'job', 'reason': 'unavailable'});
      server
        ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
        ..on('GET', '/api/cron/jobs', [cronJobRow()])
        ..on('GET', '/api/cron/jobs/job1', cronJobRow())
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
      expect(server.requestsTo('GET', '/api/cron/jobs/job1'), isEmpty);
    });

    testWidgets('defers a scheduled-job tap until the editor closes', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      server.on('GET', '/api/cron/delivery-targets', cronDeliveryTargets);
      server
        ..on('GET', '/api/cron/jobs', [cronJobRow()])
        ..on('GET', '/api/cron/jobs/job1', cronJobRow())
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      await pumpShell(tester, size: const Size(400, 800));
      await editSkill(tester);
      notifications.tapJob('job1', profile: 'work');
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(selectedTab(tester), 0);
      expect(server.requestsTo('GET', '/api/cron/jobs/job1'), isEmpty);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('Say good morning'), findsOneWidget);
    });
  });

  testWidgets('a notification tap switches from Kanban to Chat', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    expect(selectedTab(tester), 1);

    notifications.tap('t2');
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
  });

  group('guarded shared content', () {
    testWidgets(
      'retains all text/files and only the latest quote behind an editor',
      (tester) async {
        kanbanPlugin(on: true);
        await pumpShell(tester, size: const Size(400, 800));
        await openThread(tester, "Summarize last night's run logs");
        final composer = tester.widget<EditableText>(composerField).controller;
        await editSkill(tester);
        final share = tester
            .element(find.byType(ChatScreen, skipOffstage: false))
            .read<ShareController>();
        inbox.emit([
          const SharedText('first'),
          const SharedFile(path: '/tmp/report.pdf', name: 'report.pdf'),
          const SharedQuote('old quote'),
        ]);
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsOneWidget);
        expect(composer.text, isEmpty);
        expect(selectedChat(tester), 't1');
        expect(share.hasPending, isTrue);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        inbox.emit([
          const SharedText('second'),
          const SharedQuote('latest quote'),
        ]);
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsNothing);
        expect(find.text('Unsaved skill'), findsOneWidget);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(composer.text, 'first\nsecond\n\n> latest quote\n\n');
        expect(find.text('report.pdf'), findsOneWidget);
        expect(selectedChat(tester), isNot('t1'));
        expect(share.hasPending, isFalse);
        await openTab(tester, 'Chat');
        expect(composer.text, 'first\nsecond\n\n> latest quote\n\n');
      },
    );

    testWidgets('failed save keeps both the editor and pending share', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(400, 800));
      await openThread(tester, "Summarize last night's run logs");
      final composer = tester.widget<EditableText>(composerField).controller;
      final saved = Completer<String?>();
      await editSkill(tester, onSave: (_, _, _) => saved.future);
      await tester.tap(find.text('Save'));
      await tester.pump();
      inbox.emit([const SharedText('retained share')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Discard changes?'), findsNothing);
      expect(composer.text, isEmpty);
      saved.complete('Save failed');
      await tester.pumpAndSettle();
      expect(find.text('Save failed'), findsOneWidget);
      expect(find.text('Unsaved skill'), findsOneWidget);
      final routeContext = tester.element(find.byType(SkillEditorScreen));
      Navigator.of(routeContext).maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(composer.text, 'retained share');
    });

    testWidgets(
      'newer notification wins and repeated Chat entry recovers the share',
      (tester) async {
        kanbanPlugin(on: true);
        await pumpShell(tester, size: const Size(400, 800));
        await openThread(tester, "Summarize last night's run logs");
        final composer = tester.widget<EditableText>(composerField).controller;
        await editSkill(tester);
        final share = tester
            .element(find.byType(ChatScreen, skipOffstage: false))
            .read<ShareController>();
        inbox.emit([const SharedText('retained share')]);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        notifications.tap('t2');
        await tester.pumpAndSettle();
        expect(composer.text, isEmpty);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(selectedChat(tester), 't2');
        expect(composer.text, isEmpty);
        expect(share.hasPending, isTrue);
        await openTab(tester, 'Chat');
        expect(selectedChat(tester), 't2');
        expect(composer.text, 'retained share');
        expect(share.hasPending, isFalse);
        await openTab(tester, 'Chat');
        expect(composer.text, 'retained share');
      },
    );

    testWidgets('App Lock holds shared content until unlock', (tester) async {
      late AppLockController lock;
      await tester.runAsync(() async {
        lock = AppLockController(
          authenticator: FakeDeviceAuthenticator(),
          coverWhenInactive: true,
        );
        await lock.load();
        await lock.setEnabled(true);
      });
      addTearDown(lock.dispose);
      await pumpShell(tester, size: const Size(1400, 900), lock: lock);
      final composer = tester.widget<EditableText>(composerField).controller;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      inbox.emit([const SharedText('locked share')]);
      await tester.pumpAndSettle();
      expect(composer.text, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(composer.text, 'locked share');
    });

    testWidgets('held launch content stays pending behind App Lock', (
      tester,
    ) async {
      inbox = FakeShareInbox([const SharedText('held share')]);
      late AppLockController lock;
      await tester.runAsync(() async {
        lock = AppLockController(
          authenticator: FakeDeviceAuthenticator(),
          coverWhenInactive: true,
        );
        await lock.load();
        await lock.setEnabled(true);
      });
      addTearDown(lock.dispose);
      lock.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await pumpShell(tester, size: const Size(1400, 900), lock: lock);
      final share = tester
          .element(find.byType(ChatScreen, skipOffstage: false))
          .read<ShareController>();
      expect(share.hasPending, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'held share',
      );
      expect(share.hasPending, isFalse);
    });

    testWidgets('newer Kanban link retains shares until a later Chat entry', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      final urls = StreamController<Uri>.broadcast(sync: true);
      final links = DeepLinks(
        links: urls.stream,
        signedOut: const Stream.empty(),
        firstFrame: Future.value(),
      );
      addTearDown(links.dispose);
      addTearDown(urls.close);
      await pumpShell(tester, size: const Size(400, 800), links: links);
      await openThread(tester, "Summarize last night's run logs");
      final composer = tester.widget<EditableText>(composerField).controller;
      await editSkill(tester);
      inbox.emit([const SharedText('retained link share')]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      urls.add(Uri.parse('hermes://kanban'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 1);
      expect(composer.text, isEmpty);
      await openTab(tester, 'Chat');
      expect(composer.text, 'retained link share');
    });

    testWidgets('a newer link invalidates deferred Chat-entry recovery', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      final urls = StreamController<Uri>.broadcast(sync: true);
      final links = DeepLinks(
        links: urls.stream,
        signedOut: const Stream.empty(),
        firstFrame: Future.value(),
      );
      addTearDown(links.dispose);
      addTearDown(urls.close);
      await pumpShell(tester, size: const Size(400, 800), links: links);
      await openThread(tester, "Summarize last night's run logs");
      final composer = tester.widget<EditableText>(composerField).controller;
      await editSkill(tester);
      inbox.emit([const SharedText('still pending')]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      notifications.tap('t2');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(ShellNavigation),
          matching: find.text('Chat'),
        ),
      );
      urls.add(Uri.parse('hermes://kanban'));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 1);
      expect(composer.text, isEmpty);
      await openTab(tester, 'Chat');
      expect(composer.text, 'still pending');
    });

    testWidgets('delayed launch sharing yields to a newer notification', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      final initial = Completer<List<SharedItem>>();
      inbox.initialGate = initial;
      await pumpShell(tester, size: const Size(400, 800));
      await openThread(tester, "Summarize last night's run logs");
      final composer = tester.widget<EditableText>(composerField).controller;
      notifications.tap('t2');
      await tester.pumpAndSettle();
      initial.complete([const SharedQuote('older launch quote')]);
      await tester.pumpAndSettle();
      expect(selectedChat(tester), 't2');
      expect(composer.text, isEmpty);
      await openTab(tester, 'Chat');
      expect(composer.text, '> older launch quote\n\n');
      expect(selectedChat(tester), isNot('t2'));
    });

    testWidgets('disposal leaves untaken content pending', (tester) async {
      await pumpShell(tester, size: const Size(400, 800));
      await editSkill(tester);
      final share = tester
          .element(find.byType(ChatScreen, skipOffstage: false))
          .read<ShareController>();
      inbox.emit([const SharedText('pending share')]);
      await tester.pumpAndSettle();
      expect(share.hasPending, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(share.hasPending, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('shared content switches from Kanban to Chat', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    inbox.emit([const SharedText('https://example.com')]);
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
    expect(find.text('https://example.com'), findsOneWidget);
  });

  testWidgets('shared files switch from Kanban to Chat', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    inbox.emit([const SharedFile(path: '/tmp/report.pdf', name: 'report.pdf')]);
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
  });

  Future<void> pushOverBoard(WidgetTester tester) async {
    await tester.tap(find.text('open a task'));
    await tester.pumpAndSettle();
    expect(find.text('the task'), findsOneWidget);
  }

  testWidgets('a notification tap dismisses a screen pushed over the board', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    await pushOverBoard(tester);

    notifications.tap('t2');
    await tester.pumpAndSettle();

    expect(find.text('the task'), findsNothing);
    expect(selectedTab(tester), 0);
  });

  testWidgets('shared content dismisses a screen pushed over the board', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    await pushOverBoard(tester);

    inbox.emit([const SharedText('https://example.com')]);
    await tester.pumpAndSettle();

    expect(find.text('the task'), findsNothing);
    expect(selectedTab(tester), 0);
    expect(find.text('https://example.com'), findsOneWidget);
  });

  testWidgets('shared content dismisses a page pushed over Chat', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(400, 800));
    unawaited(
      Navigator.of(tester.element(find.byType(AppShell))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('a pushed page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('a pushed page'), findsOneWidget);

    inbox.emit([const SharedQuote('selected text')]);
    await tester.pumpAndSettle();

    expect(find.text('a pushed page'), findsNothing);
    expect(find.textContaining('selected text'), findsOneWidget);
  });

  testWidgets('the board is not built until its tab is opened', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));

    expect(boardLog, isEmpty);
    await openKanban(tester);
    expect(boardLog, ['open']);
  });

  testWidgets('the board and its local state survive a visit to Chat', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    await tester.enterText(find.byType(TextField), 'deploy');

    await openTab(tester, 'Chat');
    await openKanban(tester);

    expect(find.text('deploy'), findsOneWidget);
    expect(boardLog, ['open']);
  });

  testWidgets('a plugin that goes off and on does not reopen the board', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    await flipPlugin(tester, on: false);
    await flipPlugin(tester, on: true);

    expect(selectedTab(tester), 0);
    expect(boardLog, ['open', 'close']);
  });

  group("the board's event stream", () {
    /// The `since` of each stream the board opened, and whether each is open.
    late List<int> opened;
    late List<bool> open;

    Future<void> pumpWithBoard(WidgetTester tester) async {
      kanbanPlugin(on: true);
      server
        ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
        ..on(
          'GET',
          '/api/plugins/kanban/board',
          kanbanBoardBody([kanbanTaskRow(id: 't1')], latestEventId: 7),
        );
      opened = [];
      open = [];
      await pumpShell(
        tester,
        size: const Size(400, 800),
        kanbanBuilder: (_) => KanbanScreen(
          repository: KanbanRepository(server.client()),
          connect: ({required since, board}) async {
            final socket = StreamChannelController<String>();
            final i = opened.length;
            opened.add(since);
            open.add(true);
            socket.local.stream.listen(null, onDone: () => open[i] = false);
            return socket.foreign;
          },
        ),
      );
      await openKanban(tester);
    }

    Future<void> background(WidgetTester tester) async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
    }

    Future<void> foreground(WidgetTester tester) async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('closes while Chat is in front and reopens with the board', (
      tester,
    ) async {
      await pumpWithBoard(tester);
      expect(open, [true]);

      await openTab(tester, 'Chat');
      expect(open, [false]);

      await openKanban(tester);
      expect(opened, [7, 7]);
      expect(open, [false, true]);
    });

    testWidgets('closes while the app is in the background', (tester) async {
      await pumpWithBoard(tester);

      await background(tester);
      expect(open, [false]);

      await foreground(tester);
      expect(open, [false, true]);
    });

    testWidgets('stays closed when the app comes back on Chat', (tester) async {
      await pumpWithBoard(tester);
      await openTab(tester, 'Chat');

      await background(tester);
      await foreground(tester);

      expect(open, [false]);
    });
  });

  void cronRoutes({required bool on}) => server.on(
    'GET',
    '/api/cron/delivery-targets',
    cronDeliveryTargets,
    status: on ? 200 : 404,
  );

  void jobRoutes() => server
    ..on('GET', '/api/cron/jobs', [cronJobRow()])
    ..on('GET', '/api/cron/jobs/job1', cronJobRow())
    ..on('GET', '/api/cron/jobs/job1/runs', {
      'runs': [
        cronRunRow(
          id: 'cron_job1_1',
          startedAt: 1789800000,
          endedAt: 1789800042,
        ),
      ],
    });

  /// Opens [page] from the sidebar of a wide layout.
  Future<void> openInSidebar(WidgetTester tester, String page) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ShellNavigation),
        matching: find.text(page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'authenticated Chat retains text and attachment across Schedules navigation',
    (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      server
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([profileRow(name: 'work')]),
        )
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's1', title: 'Draft conversation')]),
        )
        ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
        // Keep the fixture offline if selecting a thread starts its feed.
        ..on('POST', '/api/auth/ws-ticket', {'detail': 'offline'}, status: 503);
      final auth = FakeSessionAuth();
      addTearDown(auth.dispose);
      await pumpShell(
        tester,
        size: const Size(1400, 900),
        platform: TargetPlatform.macOS,
        auth: auth,
        repositories: HermesRepositories(server.client()),
      );
      await openThread(tester, 'Draft conversation');
      const attachment = SharedFile(
        path: '/tmp/synthetic-navigation-draft.pdf',
        name: 'synthetic-navigation-draft.pdf',
        mimeType: 'application/pdf',
      );
      inbox.emit([attachment]);
      await tester.pumpAndSettle();
      const text = 'Synthetic unsent navigation draft';
      await tester.enterText(composerField, text);
      final before = tester.widget<ChatThreadView>(find.byType(ChatThreadView));
      final chatState = tester.state(find.byType(ChatScreen));
      final owner = auth.verifiedOwner;
      final generation = auth.ownerGeneration;
      expect(before.thread?.id, 's1');
      expect(before.attachments, [attachment]);
      expect(
        tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).searchProfile,
        'work',
      );
      final postsBefore = server.requests
          .where((r) => r.method == 'POST')
          .length;

      await openInSidebar(tester, 'Schedules');
      expect(find.byType(SchedulesScreen), findsOneWidget);
      expect(composerField, findsNothing);
      expect(
        tester.state(find.byType(ChatScreen, skipOffstage: false)),
        same(chatState),
      );
      await openInSidebar(tester, 'Chat');

      final after = tester.widget<ChatThreadView>(find.byType(ChatThreadView));
      expect(tester.state(find.byType(ChatScreen)), same(chatState));
      expect(after.composerController, same(before.composerController));
      expect(after.chatController, same(before.chatController));
      expect(after.thread, same(before.thread));
      expect(after.composerController.text, text);
      expect(after.attachments, [attachment]);
      expect(find.text(attachment.name), findsOneWidget);
      expect(
        tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).searchProfile,
        'work',
      );
      expect(auth.verifiedOwner, owner);
      expect(auth.ownerGeneration, generation);
      expect(
        server.requests.where((r) => r.method == 'POST').length,
        postsBefore,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  group('guarded main-window handoffs', () {
    testWidgets('Show in Main keeps the editor and composer until Save', (
      tester,
    ) async {
      kanbanPlugin(on: true);
      final fixture = windowHost();
      await fixture.windows.open('t2', profile: null, title: 'Window chat');
      await pumpShell(
        tester,
        size: const Size(1400, 900),
        windows: fixture.windows,
      );
      final composer = tester.widget<EditableText>(composerField).controller;
      await tester.enterText(composerField, 'Original draft');
      await openInSidebar(tester, 'Kanban');
      await editSkill(tester);

      await fixture.host.call('showInMain', {
        'window_id': 'w0',
        'thread_id': 't2',
      });
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(selectedTab(tester), 1);
      expect(selectedChat(tester), 't1');
      expect(composer.text, 'Original draft');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved skill'), findsOneWidget);
      expect(selectedChat(tester), 't1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(SkillEditorScreen), findsNothing);
      expect(selectedTab(tester), 0);
      expect(selectedChat(tester), 't2');
      expect(fixture.host.mainShown, 1);
    });

    testWidgets('a newer notification replaces Show in Main while editing', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      final fixture = windowHost();
      await fixture.windows.open('t2', profile: null, title: 'Window chat');
      final trail = BreadcrumbTrail();
      await pumpShell(
        tester,
        size: const Size(1400, 900),
        windows: fixture.windows,
        trail: trail,
      );
      await editSkill(tester);

      await fixture.host.call('showInMain', {
        'window_id': 'w0',
        'thread_id': 't2',
      });
      await tester.pumpAndSettle();
      expect(selectedChat(tester), 't1');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      notifications.tap('t3');
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(selectedChat(tester), 't1');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(SkillEditorScreen), findsNothing);
      expect(selectedChat(tester), 't3');
      expect(
        trail.recent
            .where((crumb) => crumb.name == 'chat.open.requested')
            .length,
        1,
      );
    });

    testWidgets('scheduled-run handoff waits for Keep editing then Save', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(1400, 900));
      final composer = tester.widget<EditableText>(composerField).controller;
      await tester.enterText(composerField, 'Original draft');
      await openInSidebar(tester, 'Schedules');
      final onOpenRun = tester
          .widget<SchedulesScreen>(find.byType(SchedulesScreen))
          .onOpenRun;
      await editSkill(tester);

      onOpenRun(
        CronRun(sessionId: 't2', startedAt: DateTime(2026)),
        const CronJob(id: 'job1', name: 'Morning brief'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(selectedTab(tester), 1);
      expect(selectedChat(tester), 't1');
      expect(composer.text, 'Original draft');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved skill'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(SkillEditorScreen), findsNothing);
      expect(selectedTab(tester), 0);
      expect(selectedChat(tester), 't2');
    });

    testWidgets('App Lock holds a scheduled-run handoff before Discard', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      late AppLockController lock;
      await tester.runAsync(() async {
        lock = AppLockController(
          authenticator: FakeDeviceAuthenticator(),
          coverWhenInactive: true,
        );
        await lock.load();
        await lock.setEnabled(true);
      });
      addTearDown(lock.dispose);
      await pumpShell(tester, size: const Size(1400, 900), lock: lock);
      await openInSidebar(tester, 'Schedules');
      final onOpenRun = tester
          .widget<SchedulesScreen>(find.byType(SchedulesScreen))
          .onOpenRun;
      await editSkill(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      onOpenRun(
        CronRun(sessionId: 't2', startedAt: DateTime(2026)),
        const CronJob(id: 'job1', name: 'Morning brief'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(selectedChat(tester), 't1');
      expect(selectedTab(tester), 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(SkillEditorScreen), findsNothing);
      expect(selectedTab(tester), 0);
      expect(selectedChat(tester), 't2');
    });
  });

  group('handoff authorization', () {
    testWidgets(
      'queued Show in Main cannot survive owner retirement while ready',
      (tester) async {
        kanbanPlugin(on: false);
        final auth = _ShellAuth();
        addTearDown(auth.dispose);
        final fixture = windowHost(auth: auth);
        await fixture.windows.open('t2', profile: null, title: 'Window chat');
        final trail = BreadcrumbTrail();
        await pumpShell(
          tester,
          size: const Size(1400, 900),
          windows: fixture.windows,
          auth: auth,
          trail: trail,
        );
        await editSkill(tester);
        await fixture.host.call('showInMain', {
          'window_id': 'w0',
          'thread_id': 't2',
        });
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();

        auth.retire();
        expect(auth.state, HermesConnectionState.ready);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.byType(SkillEditorScreen), findsNothing);
        expect(selectedChat(tester), 't1');
        expect(
          trail.recent.where((crumb) => crumb.name == 'chat.open.requested'),
          isEmpty,
        );
        auth.allow(true);
        await tester.pumpAndSettle();
        expect(selectedChat(tester), 't1');
      },
    );

    testWidgets(
      'queued scheduled-run handoff cannot survive owner retirement while ready',
      (tester) async {
        kanbanPlugin(on: false);
        cronRoutes(on: true);
        jobRoutes();
        final auth = _ShellAuth();
        addTearDown(auth.dispose);
        await pumpShell(tester, size: const Size(1400, 900), auth: auth);
        await openInSidebar(tester, 'Schedules');
        final onOpenRun = tester
            .widget<SchedulesScreen>(find.byType(SchedulesScreen))
            .onOpenRun;
        await editSkill(tester);
        onOpenRun(
          CronRun(sessionId: 't2', startedAt: DateTime(2026)),
          const CronJob(id: 'job1', name: 'Morning brief'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();

        auth.retire();
        expect(auth.state, HermesConnectionState.ready);
        onOpenRun(
          CronRun(sessionId: 't3', startedAt: DateTime(2026)),
          const CronJob(id: 'job1', name: 'Morning brief'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsNothing);
        expect(selectedChat(tester), 't1');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.byType(SkillEditorScreen), findsNothing);
        expect(selectedTab(tester), 1);
        expect(selectedChat(tester), 't1');
        auth.allow(true);
        await tester.pumpAndSettle();
        expect(selectedChat(tester), 't1');
      },
    );

    testWidgets('same-generation permission recovery resumes a held handoff', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      final auth = _ShellAuth();
      addTearDown(auth.dispose);
      await pumpShell(tester, size: const Size(1400, 900), auth: auth);
      await openInSidebar(tester, 'Schedules');
      final onOpenRun = tester
          .widget<SchedulesScreen>(find.byType(SchedulesScreen))
          .onOpenRun;
      await editSkill(tester);

      auth.allow(false);
      onOpenRun(
        CronRun(sessionId: 't2', startedAt: DateTime(2026)),
        const CronJob(id: 'job1', name: 'Morning brief'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Unsaved skill'), findsOneWidget);
      expect(selectedChat(tester), 't1');
      auth.transition(HermesConnectionState.needsLogin);
      auth.allow(true);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(selectedChat(tester), 't1');
      auth.transition(HermesConnectionState.ready);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
      expect(selectedChat(tester), 't2');
    });

    testWidgets('permission recovery cannot resume a disposed shell', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      final auth = _ShellAuth();
      addTearDown(auth.dispose);
      await pumpShell(tester, size: const Size(1400, 900), auth: auth);
      auth.allow(false);
      notifications.tap('t2');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(auth.observed, isFalse);

      auth.allow(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a route pushed over the shell after Kanban and Schedules '
      'were both opened animates without a hero clash', (tester) async {
    kanbanPlugin(on: true);
    cronRoutes(on: true);
    jobRoutes();
    server
      ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
      ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody([]))
      ..on('GET', '/api/profiles', {'profiles': <Object>[]});
    await pumpShell(
      tester,
      size: const Size(1400, 900),
      platform: TargetPlatform.android,
      kanbanBuilder: (_) => KanbanScreen(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
      ),
    );

    await openInSidebar(tester, 'Kanban');
    await openInSidebar(tester, 'Schedules');
    await tester.tap(find.byKey(const Key('schedules-new')).hitTestable());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BlueprintGalleryScreen), findsOneWidget);
  });

  testWidgets('File > New (Command-N) adds what the page in front holds', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    cronRoutes(on: true);
    jobRoutes();
    server
      ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
      ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody([]))
      ..on('GET', '/api/plugins/kanban/assignees', {'assignees': <String>[]})
      ..on('GET', '/api/plugins/kanban/model-options', {'providers': []})
      ..on('GET', '/api/profiles', {'profiles': <Object>[]});
    final commands = MacCommandRegistry();
    addTearDown(commands.dispose);
    await pumpShell(
      tester,
      size: const Size(1400, 900),
      platform: TargetPlatform.macOS,
      commands: commands,
      kanbanBuilder: (_) => KanbanScreen(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
      ),
    );
    String? newTitle() => commands.handlerFor(MacCommand.newChat)?.title;

    expect(newTitle(), isNull, reason: 'Chat keeps the New Chat label');

    await openInSidebar(tester, 'Kanban');
    expect(newTitle(), 'New Task');
    expect(commands.invoke(MacCommand.newChat), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(KanbanCreateScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await openInSidebar(tester, 'Schedules');
    expect(newTitle(), 'New Schedule');
    expect(commands.invoke(MacCommand.newChat), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(BlueprintGalleryScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await openInSidebar(tester, 'Chat');
    expect(newTitle(), isNull);
  });

  group('Schedules', () {
    testWidgets('is offered without Kanban when the server has cron routes', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(400, 800));

      expect(await navigationLabels(tester), ['Chat', 'Schedules']);
    });

    testWidgets('sits next to Kanban when both are on', (tester) async {
      kanbanPlugin(on: true);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(400, 800));

      expect(await navigationLabels(tester), ['Chat', 'Kanban', 'Schedules']);
    });

    testWidgets('is offered in the sidebar on a wide screen', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(1400, 900));

      expect(find.byType(ShellNavigation), findsOneWidget);
      expect(find.text('Schedules'), findsOneWidget);
    });

    testWidgets('is not offered by a server without the cron routes', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);

      await pumpShell(tester, size: const Size(400, 800));

      expect(await navigationLabels(tester), isNull);
    });

    testWidgets('does not load jobs until its tab is opened', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));

      expect(server.requests.where((r) => r.path == '/api/cron/jobs'), isEmpty);
      await openTab(tester, 'Schedules');

      expect(find.text('Morning brief'), findsOneWidget);
    });

    testWidgets('keeps its filter across a visit to Chat', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');
      await tester.tap(find.byKey(const Key('schedule-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paused'));
      await tester.pumpAndSettle();

      await openTab(tester, 'Chat');
      await openTab(tester, 'Schedules');

      expect(find.text('No tasks match this filter'), findsOneWidget);
    });

    testWidgets('goes back to Chat when cron goes away while selected', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');

      cronRoutes(on: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Morning brief'), findsNothing);
      expect(await navigationLabels(tester), isNull);
    });

    testWidgets('opening a run brings Chat to the front', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('42 s'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ScheduleDetail),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('42 s'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
      expect(find.text('Delete task'), findsNothing);
    });

    testWidgets('a notification tap leaves Schedules for Chat', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');

      notifications.tap('t2');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
    });
  });

  group('schedule authorization', () {
    Future<void> pumpWatcher(WidgetTester tester, _ShellAuth auth) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      server.on('GET', '/api/cron/jobs', [
        cronJobRow(lastRunAt: '2026-09-20T08:00:00+00:00', lastStatus: 'ok'),
      ]);
      final settings = NotificationSettings();
      addTearDown(settings.dispose);
      await tester.runAsync(settings.load);
      await pumpShell(
        tester,
        size: const Size(400, 800),
        settings: settings,
        auth: auth,
      );
    }

    Future<String?> baseline(WidgetTester tester) async =>
        tester.runAsync<String?>(() async {
          await pumpEventQueue();
          return SharedPreferencesAsync().getString(
            'hermes.schedules.baseline.v1',
          );
        });

    testWidgets(
      'initially closed authorization starts no discovery or watcher work',
      (tester) async {
        final auth = _ShellAuth()..allow(false);
        addTearDown(auth.dispose);

        await pumpWatcher(tester, auth);
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();

        expect(server.requests, isEmpty);
        expect(notifications.shown, isEmpty);
        expect(await baseline(tester), isNull);
      },
    );

    testWidgets(
      'permission pause stops polling and same-owner recovery retains the baseline',
      (tester) async {
        final auth = _ShellAuth();
        addTearDown(auth.dispose);
        await pumpWatcher(tester, auth);
        final before = await baseline(tester);
        expect(before, isNotNull);
        final requests = server.requestsTo('GET', '/api/cron/jobs').length;

        auth.allow(false);
        server.on('GET', '/api/cron/jobs', [
          cronJobRow(lastRunAt: '2026-09-21T08:00:00+00:00', lastStatus: 'ok'),
        ]);
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();

        expect(server.requestsTo('GET', '/api/cron/jobs'), hasLength(requests));
        expect(notifications.shown, isEmpty);
        expect(await baseline(tester), before);
        auth.allow(true);
        await tester.pumpAndSettle();

        expect(notifications.shown.map((notification) => notification.body), [
          'Finished',
        ]);
        expect(await baseline(tester), isNot(before));
      },
    );

    testWidgets(
      'stale availability loss cannot clear the baseline during authorization pause',
      (tester) async {
        final auth = _ShellAuth();
        addTearDown(auth.dispose);
        await pumpWatcher(tester, auth);
        final before = await baseline(tester);
        expect(before, isNotNull);
        final availability = Completer<FakeResponse>();
        server.onRequest(
          'GET',
          '/api/cron/delivery-targets',
          (_) => availability.future,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        auth.allow(false);
        availability.complete((status: 404, body: {}));
        await tester.pumpAndSettle();

        expect(await baseline(tester), before);
        expect(await navigationLabels(tester), contains('Schedules'));
        expect(notifications.shown, isEmpty);
      },
    );

    testWidgets(
      'a retired mounted owner cannot resume watcher work while ready',
      (tester) async {
        final auth = _ShellAuth();
        addTearDown(auth.dispose);
        await pumpWatcher(tester, auth);
        final before = await baseline(tester);
        expect(before, isNotNull);
        final jobs = server.requestsTo('GET', '/api/cron/jobs').length;
        final discovery = server
            .requestsTo('GET', '/api/cron/delivery-targets')
            .length;
        auth.retire();
        auth.allow(true);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        server.on('GET', '/api/cron/jobs', [
          cronJobRow(lastRunAt: '2026-09-21T08:00:00+00:00', lastStatus: 'ok'),
        ]);
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();

        expect(server.requestsTo('GET', '/api/cron/jobs'), hasLength(jobs));
        expect(
          server.requestsTo('GET', '/api/cron/delivery-targets'),
          hasLength(discovery),
        );
        expect(notifications.shown, isEmpty);
        expect(await baseline(tester), before);
      },
    );
  });

  group('scheduled task notifications', () {
    void twoJobs() => server
      ..on('GET', '/api/cron/jobs', [cronJobRow()])
      ..on('GET', '/api/cron/jobs/job1', cronJobRow())
      ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});

    testWidgets('a tap opens the job in Schedules from Chat', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      twoJobs();
      await pumpShell(tester, size: const Size(400, 800));

      notifications.tapJob('job1', profile: 'work');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('Say good morning'), findsOneWidget);
    });

    testWidgets('a tap for a job that is gone shows the list and says so', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      server
        ..on('GET', '/api/cron/jobs', [])
        ..on('GET', '/api/cron/jobs/gone', {}, status: 404);
      await pumpShell(tester, size: const Size(400, 800));

      notifications.tapJob('gone', profile: 'work');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('This task no longer exists'), findsOneWidget);
      expect(find.text('No scheduled tasks'), findsOneWidget);
    });

    testWidgets('a summary tap shows the list', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      twoJobs();
      await pumpShell(tester, size: const Size(400, 800));

      notifications.tapJob('');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('Morning brief'), findsOneWidget);
    });

    testWidgets('a tap that comes before cron is detected waits for it', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      twoJobs();
      await pumpShell(tester, size: const Size(400, 800), settle: false);

      notifications.tapJob('job1', profile: 'work');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('Say good morning'), findsOneWidget);
    });

    testWidgets('a chat tap still opens Chat', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      twoJobs();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');

      notifications.tap('t2');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
    });

    testWidgets('a job that runs while the user is in Chat is announced', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      server.on('GET', '/api/profiles/active', {
        'active': 'work',
        'current': 'work',
      });
      server.on('GET', '/api/cron/jobs', [
        cronJobRow(lastRunAt: '2026-09-20T08:00:00+00:00', lastStatus: 'ok'),
      ]);
      final settings = NotificationSettings();
      await tester.runAsync(settings.load);
      await pumpShell(tester, size: const Size(400, 800), settings: settings);
      expect(notifications.shown, isEmpty);

      server.on('GET', '/api/cron/jobs', [
        cronJobRow(lastRunAt: '2026-09-21T08:00:00+00:00', lastStatus: 'ok'),
      ]);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(notifications.shown.map((n) => n.body), ['Finished']);
      expect(notifications.shown.single.jobId, 'job1');
      expect(
        server.requests
            .where((r) => r.path == '/api/cron/jobs')
            .every((r) => r.queryParameters['profile'] == 'all'),
        isTrue,
      );
    });

    group('the run times it keeps', () {
      Future<String?> stored(WidgetTester tester) async {
        final value = await tester.runAsync(() async {
          await pumpEventQueue();
          return SharedPreferencesAsync().getString(
            'hermes.schedules.baseline.v1',
          );
        });
        return value;
      }

      Future<void> recheck(WidgetTester tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }

      Future<void> pumpWithBaseline(WidgetTester tester) async {
        kanbanPlugin(on: false);
        cronRoutes(on: true);
        server.on('GET', '/api/cron/jobs', [
          cronJobRow(lastRunAt: '2026-09-20T08:00:00+00:00', lastStatus: 'ok'),
        ]);
        final settings = NotificationSettings();
        await tester.runAsync(settings.load);
        await pumpShell(tester, size: const Size(400, 800), settings: settings);
        expect(await stored(tester), isNotNull);
      }

      testWidgets('survive a check that could not tell', (tester) async {
        await pumpWithBaseline(tester);
        server.on('GET', '/api/cron/delivery-targets', {
          'detail': 'down',
        }, status: 503);

        await recheck(tester);

        expect(await stored(tester), isNotNull);
      });

      testWidgets('go with a server that has no cron routes', (tester) async {
        await pumpWithBaseline(tester);
        cronRoutes(on: false);

        await recheck(tester);

        expect(await stored(tester), isNull);
      });
    });

    testWidgets(
      'a job that runs while Schedules is in front is not announced',
      (tester) async {
        kanbanPlugin(on: false);
        cronRoutes(on: true);
        server.on('GET', '/api/cron/jobs', [
          cronJobRow(lastRunAt: '2026-09-20T08:00:00+00:00', lastStatus: 'ok'),
        ]);
        final settings = NotificationSettings();
        await tester.runAsync(settings.load);
        await pumpShell(tester, size: const Size(400, 800), settings: settings);
        await openTab(tester, 'Schedules');

        server.on('GET', '/api/cron/jobs', [
          cronJobRow(lastRunAt: '2026-09-21T08:00:00+00:00', lastStatus: 'ok'),
        ]);
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();

        expect(notifications.shown, isEmpty);
      },
    );
  });

  group('messages from Hermes', () {
    void inbox(List<Map<String, Object?>> rows) => server.on(
      'GET',
      '/api/sessions',
      sessionListBody(rows),
      query: {'source': 'hermes_app'},
    );

    Map<String, Object?> delivered(String id, double at, String title) =>
        sessionRow(
          id: id,
          title: title,
          startedAt: at,
          unread: true,
          source: 'hermes_app',
          messageCount: 1,
        );

    testWidgets('a delivered chat is announced at the next look', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      server
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([profileRow(name: 'work')]),
        )
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
        ..on('GET', '/api/sessions', sessionListBody([]))
        ..on(
          'GET',
          '/api/sessions/hermes-app-new/messages',
          messageListBody('hermes-app-new', [
            messageRow(
              id: 1,
              role: 'assistant',
              content: 'Three builds failed',
            ),
          ]),
        );
      inbox([delivered('hermes-app-old', 100, 'Message: Old')]);
      final settings = NotificationSettings();
      addTearDown(settings.dispose);
      await tester.runAsync(settings.load);
      final auth = FakeSessionAuth();
      addTearDown(auth.dispose);
      await pumpShell(
        tester,
        size: const Size(400, 800),
        settings: settings,
        auth: auth,
        repositories: HermesRepositories(server.client()),
      );
      expect(notifications.shown, isEmpty);

      inbox([
        delivered('hermes-app-new', 200, 'Message: Report'),
        delivered('hermes-app-old', 100, 'Message: Old'),
      ]);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      final alert = notifications.shown.single;
      expect(alert.threadId, 'hermes-app-new');
      expect(alert.profile, 'work');
      expect(alert.title, 'Message: Report');
      expect(alert.body, 'Three builds failed');
    });

    testWidgets('a chat of another profile than the one shown says which', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      server
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([profileRow(name: 'work'), profileRow(name: 'home')]),
        )
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
        ..on('GET', '/api/sessions', sessionListBody([]))
        ..on(
          'GET',
          '/api/sessions/hermes-app-new/messages',
          messageListBody('hermes-app-new', [
            messageRow(
              id: 1,
              role: 'assistant',
              content: 'Three builds failed',
            ),
          ]),
        );
      void inboxOf(String profile, List<Map<String, Object?>> rows) =>
          server.on(
            'GET',
            '/api/sessions',
            sessionListBody(rows),
            query: {'source': 'hermes_app', 'profile': profile},
          );
      inboxOf('work', []);
      inboxOf('home', [delivered('hermes-app-old', 100, 'Message: Old')]);
      final settings = NotificationSettings();
      addTearDown(settings.dispose);
      await tester.runAsync(settings.load);
      final auth = FakeSessionAuth();
      addTearDown(auth.dispose);
      await pumpShell(
        tester,
        size: const Size(400, 800),
        settings: settings,
        auth: auth,
        repositories: HermesRepositories(server.client()),
      );

      inboxOf('home', [
        delivered('hermes-app-new', 200, 'Message: Report'),
        delivered('hermes-app-old', 100, 'Message: Old'),
      ]);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      final alert = notifications.shown.single;
      expect(alert.profile, 'home');
      expect(alert.title, 'Message: Report (home)');
    });

    testWidgets('a signed-out shell looks at nothing', (tester) async {
      kanbanPlugin(on: false);
      final auth = FakeSessionAuth()..allowed = false;
      addTearDown(auth.dispose);
      final settings = NotificationSettings();
      addTearDown(settings.dispose);
      await tester.runAsync(settings.load);
      await pumpShell(
        tester,
        size: const Size(400, 800),
        settings: settings,
        auth: auth,
        repositories: HermesRepositories(server.client()),
      );

      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();

      expect(
        server
            .requestsTo('GET', '/api/sessions')
            .where((r) => r.queryParameters['source'] == 'hermes_app'),
        isEmpty,
      );
    });
  });
}

class _ShellAuth extends AuthController {
  bool get observed => hasListeners;

  var _allowed = true;
  var _generation = 0;
  var _connectionState = HermesConnectionState.ready;

  @override
  HermesConnectionState get state => _connectionState;

  @override
  bool get protectedRequestsAllowed => _allowed;

  @override
  int get ownerGeneration => _generation;

  void allow(bool value) {
    _allowed = value;
    notifyListeners();
  }

  void retire() {
    _allowed = false;
    _generation++;
    notifyListeners();
  }

  void transition(HermesConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }
}

/// A stand-in for the Kanban page that records when it starts and stops.
class _Board extends StatefulWidget {
  const _Board(this.log);

  final List<String> log;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  @override
  void initState() {
    super.initState();
    widget.log.add('open');
  }

  @override
  void dispose() {
    widget.log.add('close');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // A page the shell shows puts the shell's menu in its app bar.
      ?ShellMenu.button(context),
      const Text('the board'),
      const TextField(),
      TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('the task')),
          ),
        ),
        child: const Text('open a task'),
      ),
    ],
  );
}
