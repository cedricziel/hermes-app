import 'dart:async';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/skills/curator/curator_config.dart';
import 'package:hermes_app/src/skills/curator/hermes_curator_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';
import 'package:hermes_app/src/skills/widgets/curator_run_confirmation.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import 'curator_fixtures.dart';

const _curatorPath = '/api/curator';
const _statusPath = '/api/actions/curator-run/status';

/// The skill curator on the Skills screen: where its section sits in every
/// state of the screen, what hides it, and the confirmed run, through the real
/// generated client against the fake dashboard.
void main() {
  late FakeHermesServer server;

  Finder title() => find.text('Skill curator');
  Finder runNow() => find.text('Run now');
  Finder confirmTitle() => find.text('Run the curator now?');
  Finder confirmRunButton() => find.descendant(
    of: find.byType(CuratorRunConfirmation),
    matching: find.text('Run now'),
  );
  Finder cancelButton() => find.descendant(
    of: find.byType(CuratorRunConfirmation),
    matching: find.text('Cancel'),
  );

  /// Lifecycle changes go through `inactive`, as the engine sends them.
  void away(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }

  void back(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  int posts() => server.requestsTo('POST', '/api/curator/run').length;

  /// The action status answers like the recorded log of a first pass, then
  /// (after the POST) like the log of a second one that finished.
  void logs({List<Object?>? answers}) {
    final given =
        answers ??
        [
          recordedStatusFinished,
          recordedStatusFinished,
          recordedStatusArchived,
        ];
    var i = 0;
    server.onRequest('GET', _statusPath, (_) {
      final body = given[i < given.length ? i : given.length - 1];
      i++;
      return (status: 200, body: body);
    });
  }

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/skills', [
        skillRow(name: 'apple-notes', description: 'Read', category: 'apple'),
        skillRow(name: 'pr-review', description: 'Review', category: 'github'),
      ])
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('GET', '/api/config', recordedConfigCurator);
    serveRecordedCurator(server, status: recordedCuratorRan);
    logs();
  });

  Future<void> pumpSkills(
    WidgetTester tester, {
    Size size = const Size(800, 1400),
    AppLockController? lock,
    bool withCurator = true,
    String? chatProfile = 'default',
    bool settle = true,
    Widget Function(Widget screen)? wrap,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = MaterialApp(
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        ...kMaterialUiLocalizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppThemeScopes(child: child!),
      theme: buildHermesLightTheme(),
      home: (wrap ?? (w) => w)(
        SkillsScreen(
          repository: HermesSkillsRepository(server.client().raw),
          profiles: HermesProfilesRepository(server.client().raw),
          chatProfile: chatProfile,
          curatorRepository: withCurator
              ? HermesCuratorRepository(
                  server.client(),
                  timeout: const Duration(seconds: 5),
                )
              : null,
          curatorConfig: withCurator
              ? CuratorConfigReader(server.client())
              : null,
        ),
      ),
    );
    await tester.pumpWidget(
      lock == null
          ? app
          : ChangeNotifierProvider<AppLockController>.value(
              value: lock,
              child: app,
            ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> pumpPast(WidgetTester tester, Duration d) async {
    for (
      var spent = Duration.zero;
      spent < d;
      spent += const Duration(milliseconds: 250)
    ) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Runs the whole pass from the Run now row: confirm, send, follow to the end.
  Future<void> runAPass(WidgetTester tester) async {
    await tester.tap(runNow());
    await tester.pumpAndSettle();
    await tester.tap(confirmRunButton());
    await tester.pumpAndSettle();
    await pumpPast(tester, const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  group('placement', () {
    testWidgets('sits above the first category and asks for its profile', (
      tester,
    ) async {
      await pumpSkills(tester);

      expect(title(), findsOneWidget);
      expect(
        tester.getTopLeft(title()).dy,
        lessThan(tester.getTopLeft(find.text('Apple')).dy),
      );
      for (final r in server.requestsTo('GET', _curatorPath)) {
        expect(r.queryParameters['profile'], 'default');
      }
      expect(server.requestsTo('GET', _curatorPath), isNotEmpty);
    });

    testWidgets('shows above the empty message', (tester) async {
      server.on('GET', '/api/skills', <Object?>[]);
      await pumpSkills(tester);

      expect(title(), findsOneWidget);
      expect(find.text('This profile has no skills yet.'), findsOneWidget);
      expect(
        tester.getTopLeft(title()).dy,
        lessThan(
          tester.getTopLeft(find.text('This profile has no skills yet.')).dy,
        ),
      );
    });

    testWidgets('shows above the failed message', (tester) async {
      server.on('GET', '/api/skills', {'detail': 'x'}, status: 500);
      await pumpSkills(tester);

      expect(title(), findsOneWidget);
      expect(find.text('Could not load skills'), findsOneWidget);
      expect(
        tester.getTopLeft(title()).dy,
        lessThan(tester.getTopLeft(find.text('Could not load skills')).dy),
      );
    });

    testWidgets('shows above the spinner while the list loads', (tester) async {
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/skills', (_) => gate.future);
      await pumpSkills(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(title(), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      gate.complete((status: 200, body: <Object?>[]));
      await tester.pumpAndSettle();
    });

    testWidgets('search or a filter hides it and clearing brings it back', (
      tester,
    ) async {
      await pumpSkills(tester);
      expect(title(), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'review');
      await tester.pump();
      expect(title(), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(title(), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-search-filter')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<VoidCallback>, 'Enabled'),
      );
      await tester.pumpAndSettle();
      expect(title(), findsNothing);
    });

    testWidgets('an old server hides it and keeps the list', (tester) async {
      server.on(
        'GET',
        _curatorPath,
        recordedRouteMissing404.body,
        status: recordedRouteMissing404.status,
      );
      await pumpSkills(tester);

      expect(title(), findsNothing);
      expect(find.text('apple-notes'), findsOneWidget);
    });

    testWidgets('a server with no skills support has no section', (
      tester,
    ) async {
      server.on('GET', '/api/skills', {'detail': 'x'}, status: 404);
      await pumpSkills(tester);

      expect(
        find.text('The connected Hermes does not support skills.'),
        findsOneWidget,
      );
      expect(title(), findsNothing);
    });

    testWidgets('a screen with no curator wired shows none', (tester) async {
      await pumpSkills(tester, withCurator: false);

      expect(title(), findsNothing);
      expect(find.text('apple-notes'), findsOneWidget);
      expect(server.requestsTo('GET', _curatorPath), isEmpty);
    });

    testWidgets('a status read with no answer says so and Try again reads', (
      tester,
    ) async {
      server.onRequest(
        'GET',
        _curatorPath,
        (r) => throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await pumpSkills(tester);

      expect(find.text("Couldn't confirm the curator's state"), findsOneWidget);
      final before = server.requestsTo('GET', _curatorPath).length;
      server.on('GET', _curatorPath, recordedCuratorRan);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', _curatorPath).length, before + 1);
      expect(find.text("Couldn't confirm the curator's state"), findsNothing);
      expect(runNow(), findsOneWidget);
    });
  });

  group('profile', () {
    testWidgets('switching the profile reads the curator for the new one', (
      tester,
    ) async {
      await pumpSkills(tester);

      await tester.tap(find.text('default'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'work'),
      );
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('GET', _curatorPath).last.queryParameters['profile'],
        'work',
      );
      expect(title(), findsOneWidget);
    });
  });

  group('no profile and searching', () {
    testWidgets('no chat profile: no section, no curator request, no crash', (
      tester,
    ) async {
      await pumpSkills(tester, chatProfile: null);

      expect(title(), findsNothing);
      expect(server.requestsTo('GET', _curatorPath), isEmpty);
      expect(server.requestsTo('GET', _statusPath), isEmpty);
      expect(server.requestsTo('GET', '/api/config'), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a search that is active while the profile changes keeps the '
        'section hidden, and clearing it shows the new profile', (
      tester,
    ) async {
      await pumpSkills(tester);
      await tester.enterText(find.byType(TextField), 'review');
      await tester.pump();
      expect(title(), findsNothing);

      await tester.tap(find.text('default'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'work'),
      );
      await tester.pumpAndSettle();
      expect(title(), findsNothing);
      expect(
        server.requestsTo('GET', _curatorPath).last.queryParameters['profile'],
        'work',
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(title(), findsOneWidget);
    });
  });

  group('confirmed run', () {
    testWidgets('Run now opens the confirmation and sends nothing yet', (
      tester,
    ) async {
      await pumpSkills(tester);
      await tester.tap(runNow());
      await tester.pumpAndSettle();

      expect(confirmTitle(), findsOneWidget);
      expect(posts(), 0);
    });

    testWidgets('Cancel closes it and sends nothing, ever', (tester) async {
      await pumpSkills(tester);
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      await pumpPast(tester, const Duration(seconds: 6));

      expect(confirmTitle(), findsNothing);
      expect(posts(), 0);
      // Run now is back and can open it again.
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      expect(confirmTitle(), findsOneWidget);
    });

    testWidgets('back and Escape cancel too', (tester) async {
      await pumpSkills(tester);
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(confirmTitle(), findsNothing);

      await tester.tap(runNow());
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(confirmTitle(), findsNothing);
      expect(posts(), 0);
      expect(runNow(), findsOneWidget);
    });

    testWidgets('a tap outside the sheet cancels it', (tester) async {
      await pumpSkills(tester, size: const Size(390, 1800));
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();

      expect(confirmTitle(), findsNothing);
      expect(posts(), 0);
    });

    testWidgets('a config that lands while the sheet is open changes no words, '
        'the next open uses it', (tester) async {
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/config', (_) => gate.future);
      await pumpSkills(tester);
      final maybe = find.textContaining('May also merge and rewrite skills');
      final sure = find.textContaining(RegExp('^Merge and rewrite skills'));

      await tester.tap(runNow());
      await tester.pumpAndSettle();
      expect(maybe, findsOneWidget);

      gate.complete((
        status: 200,
        body: {
          'curator': {'consolidate': true, 'prune_builtins': false},
        },
      ));
      await tester.pumpAndSettle();
      expect(maybe, findsOneWidget);
      expect(sure, findsNothing);

      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      // The second read stays out: the words come from the first one.
      server.onRequest(
        'GET',
        '/api/config',
        (_) => Completer<FakeResponse>().future,
      );
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      expect(sure, findsOneWidget);
      expect(maybe, findsNothing);
      expect(posts(), 0);
    });

    testWidgets('Run now pressed twice in one frame sends one POST', (
      tester,
    ) async {
      final gate = Completer<FakeResponse>();
      server.onRequest('POST', '/api/curator/run', (_) => gate.future);
      await pumpSkills(tester);
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      await tester.tap(confirmRunButton());
      await tester.tap(confirmRunButton(), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(posts(), 1);
      expect(confirmTitle(), findsNothing);
      gate.complete((status: 200, body: recordedRunStarted));
      await tester.pumpAndSettle();
      await pumpPast(tester, const Duration(seconds: 6));
      expect(posts(), 1);
    });

    testWidgets('Run now sends exactly one POST, follows it and reads the '
        'skills again', (tester) async {
      await pumpSkills(tester);
      final skillReads = server.requestsTo('GET', '/api/skills').length;
      await runAPass(tester);

      expect(posts(), 1);
      expect(
        server.requestsTo('POST', '/api/curator/run').single.queryParameters,
        {'profile': 'default'},
      );
      expect(find.text('The pass finished'), findsOneWidget);
      expect(find.text('Run again'), findsOneWidget);
      expect(
        server.requestsTo('GET', '/api/skills').length,
        greaterThan(skillReads),
        reason: 'archived skills leave the list',
      );
    });

    testWidgets('a second press while the answer is out sends no second POST', (
      tester,
    ) async {
      final gate = Completer<FakeResponse>();
      server.onRequest('POST', '/api/curator/run', (_) => gate.future);
      await pumpSkills(tester);
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      await tester.tap(confirmRunButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(confirmTitle(), findsNothing);
      expect(posts(), 1);
      // Run now is not offered while the answer is out.
      expect(runNow(), findsNothing);
      gate.complete((status: 200, body: recordedRunStarted));
      await tester.pumpAndSettle();
      await pumpPast(tester, const Duration(seconds: 6));
      expect(posts(), 1);
    });

    testWidgets('leaving the screen while the sheet is open sends nothing', (
      tester,
    ) async {
      await pumpSkills(tester);
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      expect(confirmTitle(), findsOneWidget);

      // The screen goes away (the home shell is rebuilt).
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await pumpPast(tester, const Duration(seconds: 3));

      expect(confirmTitle(), findsNothing);
      expect(posts(), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the screen rebuilt under a live navigator closes the sheet', (
      tester,
    ) async {
      final show = ValueNotifier(true);
      addTearDown(show.dispose);
      await pumpSkills(
        tester,
        wrap: (screen) => ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, on, _) => on ? screen : const SizedBox(),
        ),
      );
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      expect(confirmTitle(), findsOneWidget);

      show.value = false;
      await tester.pumpAndSettle();

      expect(confirmTitle(), findsNothing);
      expect(posts(), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pausing is a switch that sends one PUT with the profile', (
      tester,
    ) async {
      await pumpSkills(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final puts = server.requestsTo('PUT', '/api/curator/paused');
      expect(puts, hasLength(1));
      expect(puts.single.queryParameters['profile'], 'default');
    });
  });

  group('Hermes\' own text', () {
    Future<AppLockController> enabledLock(WidgetTester tester) async {
      final lock = AppLockController(
        authenticator: FakeDeviceAuthenticator(),
        coverWhenInactive: false,
      );
      addTearDown(lock.dispose);
      await tester.runAsync(lock.load);
      await tester.runAsync(() => lock.setEnabled(true));
      return lock;
    }

    void refusePause() => server.on('PUT', '/api/curator/paused', {
      'detail': 'not\nallowed\u202E here',
    }, status: 400);

    void failSpawn() => server.on('POST', '/api/curator/run', {
      'detail': 'Failed to run curator: [Errno 21] Is a directory',
    }, status: 500);

    testWidgets('a refused pause says why, cleaned', (tester) async {
      refusePause();
      await pumpSkills(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't change it: not allowed<U+202E> here"),
        findsOneWidget,
      );
    });

    testWidgets('a refused pause with no readable text says only that', (
      tester,
    ) async {
      server.on('PUT', '/api/curator/paused', {'detail': '  '}, status: 400);
      await pumpSkills(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't change it"), findsOneWidget);
    });

    testWidgets('a spawn failure says nothing started, with its text', (
      tester,
    ) async {
      failSpawn();
      await pumpSkills(tester);
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      await tester.tap(confirmRunButton());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nothing started. Failed to run curator: [Errno 21] Is a directory',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a failed pass shows its last line under Failed', (
      tester,
    ) async {
      logs(
        answers: [
          recordedStatusArchived,
          recordedStatusArchived,
          recordedStatusDisabled,
        ],
      );
      await pumpSkills(tester);
      await runAPass(tester);

      expect(find.text('Failed'), findsOneWidget);
      expect(
        find.text(
          'curator: disabled via config; enable with `curator.enabled: true`',
        ),
        findsWidgets,
        reason: 'the failure line, and the line in the output when opened',
      );
    });

    testWidgets('App Lock drops the pause text for good', (tester) async {
      refusePause();
      final lock = await enabledLock(tester);
      await pumpSkills(tester, lock: lock);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('not allowed'), findsOneWidget);

      away(tester);
      await tester.pump();
      expect(find.textContaining('not allowed'), findsNothing);
      back(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('not allowed'), findsNothing);
      expect(find.text("Couldn't change it"), findsOneWidget);
    });

    testWidgets('App Lock drops the text of a failed pass', (tester) async {
      logs(
        answers: [
          recordedStatusArchived,
          recordedStatusArchived,
          recordedStatusDisabled,
        ],
      );
      final lock = await enabledLock(tester);
      await pumpSkills(tester, lock: lock);
      await runAPass(tester);
      expect(find.textContaining('disabled via config'), findsOneWidget);

      away(tester);
      await tester.pump();
      back(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('disabled via config'), findsNothing);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('inactive hides the failed line and brings it back', (
      tester,
    ) async {
      logs(
        answers: [
          recordedStatusArchived,
          recordedStatusArchived,
          recordedStatusDisabled,
        ],
      );
      await pumpSkills(tester);
      await runAPass(tester);
      expect(find.textContaining('disabled via config'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.textContaining('disabled via config'), findsNothing);
      back(tester);
      await tester.pump();
      expect(find.textContaining('disabled via config'), findsOneWidget);
    });

    testWidgets('another profile does not show the pause text of the first', (
      tester,
    ) async {
      refusePause();
      await pumpSkills(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('not allowed'), findsOneWidget);

      await tester.tap(find.text('default'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'work'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('not allowed'), findsNothing);
    });

    testWidgets('a spawn failure text goes with a profile switch', (
      tester,
    ) async {
      failSpawn();
      await pumpSkills(tester);
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      await tester.tap(confirmRunButton());
      await tester.pumpAndSettle();
      expect(find.textContaining('Errno 21'), findsOneWidget);

      await tester.tap(find.text('default'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'work'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Errno 21'), findsNothing);
    });
  });

  group('App Lock and inactive', () {
    Future<AppLockController> enabledLock(WidgetTester tester) async {
      final lock = AppLockController(
        authenticator: FakeDeviceAuthenticator(),
        coverWhenInactive: false,
      );
      addTearDown(lock.dispose);
      await tester.runAsync(lock.load);
      await tester.runAsync(() => lock.setEnabled(true));
      return lock;
    }

    testWidgets('output is blank while the app is inactive and back after', (
      tester,
    ) async {
      await pumpSkills(tester);
      await runAPass(tester);
      await tester.tap(find.textContaining('Show output'));
      await tester.pumpAndSettle();
      expect(find.textContaining('running review pass'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.textContaining('running review pass'), findsNothing);
      expect(
        find.text('Hidden while the app is locked or away'),
        findsOneWidget,
      );

      back(tester);
      await tester.pump();
      expect(find.textContaining('running review pass'), findsOneWidget);
    });

    testWidgets('App Lock drops the output for good', (tester) async {
      final lock = await enabledLock(tester);
      await pumpSkills(tester, lock: lock);
      await runAPass(tester);
      await tester.tap(find.textContaining('Show output'));
      await tester.pumpAndSettle();
      expect(find.textContaining('running review pass'), findsOneWidget);

      away(tester);
      await tester.pump();
      expect(lock.locked, isTrue);
      expect(find.textContaining('running review pass'), findsNothing);

      back(tester);
      await tester.pumpAndSettle();
      expect(lock.locked, isFalse);
      expect(find.textContaining('running review pass'), findsNothing);
      expect(find.text('Output cleared when the app locked.'), findsOneWidget);
    });

    testWidgets('App Lock closes an open confirmation and sends nothing', (
      tester,
    ) async {
      final lock = await enabledLock(tester);
      await pumpSkills(tester, lock: lock);
      await tester.tap(runNow());
      await tester.pumpAndSettle();
      expect(confirmTitle(), findsOneWidget);

      away(tester);
      await tester.pumpAndSettle();
      back(tester);
      await tester.pumpAndSettle();

      expect(confirmTitle(), findsNothing);
      expect(posts(), 0);
    });
  });
}
