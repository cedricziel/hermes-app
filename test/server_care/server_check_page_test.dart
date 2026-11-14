import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/server_care/doctor_report.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/server_check_controller.dart';
import 'package:hermes_app/src/server_care/server_check_page.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

/// A widget test that puts the platform override back before the framework
/// checks that no debug variable was left changed.
void pageTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (tester) async {
  try {
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late ServerCareController care;
  late ServerCheckController check;
  late DateTime clock;
  final secureCalls = <Object?>[];

  const secureChannel = MethodChannel('hermes_app/secure_window');
  const header = '=== doctor started 2026-11-14 09:00:00 ===';

  Map<String, dynamic> finished(List<String> lines, {int exit = 1}) => {
    'name': 'doctor',
    'running': false,
    'exit_code': exit,
    'lines': [header, ...lines],
  };

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    secureCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          secureCalls.add(call.arguments);
          return null;
        });
    clock = DateTime(2026, 11, 14, 9);
    server = FakeHermesServer()
      ..on('GET', '/api/status', statusHealthy())
      ..on('POST', '/api/ops/doctor', {'ok': true, 'pid': 1, 'name': 'doctor'})
      ..on('GET', '/api/actions/doctor/status', finished(doctorProblems));
    final repository = ServerCareRepository(server.client());
    care = ServerCareController(repository: repository, profile: 'default');
    check = ServerCheckController(
      repository: repository,
      now: () => clock,
      delay: (d) async => clock = clock.add(d),
      onUnsupported: () => care.reportUnsupported(CarePart.check),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    care.dispose();
    check.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    double width = 400,
    bool pushed = false,
    bool runOnOpen = false,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final page = ServerCheckPage(runOnOpen: runOnOpen);
    Widget provided(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerCareController>.value(value: care),
        ChangeNotifierProvider<ServerCheckController>.value(value: check),
      ],
      child: child,
    );
    await tester.pumpWidget(
      Provider<HermesRepositories>.value(
        value: HermesRepositories(server.client()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: provided(
            pushed
                ? Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => provided(page),
                          ),
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  )
                : page,
          ),
        ),
      ),
    );
    if (pushed) await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  int posts() => server.requestsTo('POST', '/api/ops/doctor').length;

  pageTest('before a run it offers Run check and sends nothing', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Check Hermes for problems'), findsOneWidget);
    expect(find.text('default'), findsOneWidget);
    expect(posts(), 0);
  });

  pageTest('Run check runs for the chat profile and shows what was found', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Run check'));
    await tester.pumpAndSettle();
    expect(
      server.requestsTo('POST', '/api/ops/doctor').single.queryParameters,
      {'profile': 'default'},
    );
    expect(find.text('1 problem and 1 warning'), findsOneWidget);
    expect(find.text('Telegram token rejected (401)'), findsOneWidget);
    expect(find.text('Config version 30 is behind 31'), findsOneWidget);
    expect(find.text('Older keys still work'), findsOneWidget);
    expect(find.text('1. Re-run \'hermes setup telegram\''), findsOneWidget);
    // The command Hermes quoted can be copied.
    expect(find.text('hermes setup telegram'), findsOneWidget);
    // What no rule matched is shown as written.
    await tester.scrollUntilVisible(
      find.text('something unexpected'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('something unexpected'), findsOneWidget);
    expect(find.text('Run again'), findsWidgets);
  });

  pageTest('all passed folds the checks that passed', (tester) async {
    server.on('GET', '/api/actions/doctor/status', {
      ...finished(doctorAllPassed.sublist(1), exit: 0),
    });
    await pump(tester);
    await tester.tap(find.text('Run check'));
    await tester.pumpAndSettle();
    expect(find.text('All checks passed'), findsOneWidget);
    expect(find.text('1 passed'), findsOneWidget);
    expect(find.text('config.yaml found'), findsNothing);
    await tester.tap(find.text('1 passed'));
    await tester.pumpAndSettle();
    expect(find.text('config.yaml found'), findsOneWidget);
  });

  pageTest('the buttons that offer a check run it as the page opens', (
    tester,
  ) async {
    await pump(tester, runOnOpen: true);
    expect(posts(), 1);
    expect(find.text('Telegram token rejected (401)'), findsOneWidget);
  });

  pageTest('a result that is kept is shown without running again', (
    tester,
  ) async {
    await tester.runAsync(() => check.run(profile: 'default'));
    await pump(tester);
    expect(posts(), 1);
    expect(find.text('Telegram token rejected (401)'), findsOneWidget);
  });

  pageTest('a check that is taking long offers Keep waiting', (tester) async {
    // The earlier run is over when the check starts, then the new one goes on.
    var reads = 0;
    server.onRequest(
      'GET',
      '/api/actions/doctor/status',
      (_) => (
        status: 200,
        body: reads++ == 0
            ? finished(const ['◆ Old'], exit: 0)
            : {
                'name': 'doctor',
                'running': true,
                'lines': [header, '◆ A'],
              },
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Run check'));
    await tester.pumpAndSettle();
    expect(find.text('The check is taking longer than expected'), findsOne);
    server.on(
      'GET',
      '/api/actions/doctor/status',
      finished(doctorAllPassed.sublist(1), exit: 0),
    );
    await tester.tap(find.text('Keep waiting'));
    await tester.pumpAndSettle();
    expect(find.text('All checks passed'), findsOneWidget);
    expect(posts(), 1);
  });

  pageTest('Hermes refusal is shown with Try again', (tester) async {
    server.on('POST', '/api/ops/doctor', {
      'detail': 'doctor is already running',
    }, status: 500);
    await pump(tester);
    await tester.tap(find.text('Run check'));
    await tester.pumpAndSettle();
    expect(find.text("The check couldn't start"), findsOneWidget);
    expect(find.text('doctor is already running'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(posts(), 2);
  });

  pageTest('a server without the route closes the page', (tester) async {
    server.on('POST', '/api/ops/doctor', {'detail': 'Not Found'}, status: 404);
    await pump(tester, pushed: true, runOnOpen: true);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(care.offers(CarePart.check), isFalse);
  });

  pageTest('the result goes when the shell drops it', (tester) async {
    await pump(tester, runOnOpen: true);
    expect(find.text('Telegram token rejected (401)'), findsOneWidget);
    check.cover();
    await tester.pump();
    expect(find.text('Telegram token rejected (401)'), findsNothing);
    expect(find.text('Check Hermes for problems'), findsOneWidget);
  });

  pageTest('a route found missing while the page was closed closes it at '
      'once, with no error shown', (tester) async {
    care.reportUnsupported(CarePart.check);
    await pump(tester, pushed: true);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text("Can't reach Hermes"), findsNothing);
    expect(posts(), 0);
  });

  pageTest('a failed run that found no route closes the page when it opens', (
    tester,
  ) async {
    server.on('POST', '/api/ops/doctor', {'detail': 'Not Found'}, status: 404);
    await tester.runAsync(() => check.run(profile: 'default'));
    expect(care.offers(CarePart.check), isFalse);
    await pump(tester, pushed: true);
    expect(find.text('open'), findsOneWidget);
    expect(find.text("Can't reach Hermes"), findsNothing);
  });

  group('the result as the page shows it', () {
    test('lines are listed once', () {
      final lines = [
        '────────',
        '  Found 2 issue(s) to address:',
        '',
        "  1. Re-run 'hermes setup telegram'",
        '  2. Migrate the config',
        'something odd',
      ];
      final view = serverCheckResultOf(DoctorReport.parse(lines), lines);
      expect(view.fixes.map((f) => f.text), [
        "Re-run 'hermes setup telegram'",
        'Migrate the config',
      ]);
      expect(view.unknown.map((u) => u.text), ['something odd']);
    });

    test('with sections the trailing lines are listed once', () {
      final lines = [
        '◆ A',
        '  ✗ Bad',
        '  Found 1 issue(s) to address:',
        '  1. Fix it',
        '  and then this',
      ];
      final view = serverCheckResultOf(DoctorReport.parse(lines), lines);
      expect(view.unknown.map((u) => u.text), ['and then this']);
    });

    test('the command beside Copy is what Copy copies', () {
      final lines = [
        '◆ A',
        '  ✗ Bad',
        '  Found 1 issue(s) to address:',
        "  1. Run 'hermes \u202Esetup\u202C telegram'",
      ];
      final fix = serverCheckResultOf(
        DoctorReport.parse(lines),
        lines,
      ).fixes.single;
      expect(fix.command, 'hermes setup telegram');
      expect(fix.text.contains('\u202E'), isFalse);
    });
  });

  group('privacy', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      pageTest('draws no text while inactive on $platform', (tester) async {
        await pump(tester, platform: platform, runOnOpen: true);
        expect(find.text('Telegram token rejected (401)'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(find.byType(Text), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        expect(find.byType(Text), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('Telegram token rejected (401)'), findsOneWidget);
        // Coming back did not run again.
        expect(posts(), 1);
      });
    }

    pageTest('a desktop keeps drawing while inactive', (tester) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1000,
        runOnOpen: true,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Telegram token rejected (401)'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    pageTest('the Android window is secure only while the page is up', (
      tester,
    ) async {
      await pump(tester, pushed: true);
      expect(secureCalls, [true]);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(secureCalls, [true, false]);
    });

    pageTest('nothing is readable while the page is blanked', (tester) async {
      final semantics = tester.ensureSemantics();
      String everything() {
        final out = StringBuffer();
        void walk(SemanticsNode node) {
          final data = node.getSemanticsData();
          out.write('${data.label} ${data.value} ${data.hint} ');
          node.visitChildren((c) {
            walk(c);
            return true;
          });
        }

        walk(
          tester
              .binding
              .renderViews
              .first
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        return out.toString();
      }

      await pump(tester, runOnOpen: true);
      expect(everything(), contains('Telegram token rejected'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(everything(), isNot(contains('Telegram')));
      expect(everything(), isNot(contains('Server check')));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      semantics.dispose();
    });

    pageTest('the output is not kept in preferences', (tester) async {
      await pump(tester, runOnOpen: true);
      final keys = await tester.runAsync(SharedPreferencesAsync().getKeys);
      expect(keys, isEmpty);
    });
  });
}
