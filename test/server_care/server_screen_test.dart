import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/server_care/gateway_restart.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_screen.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late BreadcrumbTrail trail;
  late ServerCareController care;
  late GatewayRestart gateway;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/status', statusHealthy())
      ..on('GET', '/api/hermes/update/check', {
        ...updateCheckBehind(),
        'behind': 0,
        'update_available': false,
      });
    trail = BreadcrumbTrail();
  });

  Future<void> pump(WidgetTester tester, {Size? size, Locale? locale}) async {
    tester.view.physicalSize = size ?? const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repositories = HermesRepositories(server.client());
    care = ServerCareController(
      repository: repositories.serverCare,
      profile: 'default',
    );
    addTearDown(care.dispose);
    gateway = GatewayRestart(
      repository: repositories.serverCare,
      care: care,
      delay: (_) async {},
    );
    addTearDown(gateway.dispose);
    // As in the app, the controller is provided below the root Navigator, so
    // a route the screen pushes must carry it along.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HermesRepositories>.value(value: repositories),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ServerCareController>.value(value: care),
              ChangeNotifierProvider<GatewayRestart>.value(value: gateway),
            ],
            child: const ServerScreen(source: 'test'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void gatewayOff() => server.on('GET', '/api/status', {
    ...statusHealthy(),
    'gateway_running': false,
    'gateway_state': 'stopped',
  });

  group('headline', () {
    testWidgets('says everything looks good', (tester) async {
      await pump(tester);
      expect(find.text('Everything looks good'), findsOneWidget);
      expect(find.text('Hermes 0.22.2'), findsOneWidget);
      expect(find.textContaining('checked just now'), findsNothing);
      expect(find.text('default · 2 profiles'), findsOneWidget);
      expect(find.text('Released 2 Nov 2026'), findsOneWidget);
    });

    testWidgets('names a gateway that is off', (tester) async {
      gatewayOff();
      await pump(tester);
      expect(find.text('The messaging gateway is off'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      // How many channels are connected says nothing beside "Off".
      expect(find.text('Channels'), findsNothing);
      // The headline and the gateway section both offer it.
      expect(find.text('Start gateway'), findsNWidgets(2));
    });

    testWidgets('offers Try again when Hermes cannot be reached', (
      tester,
    ) async {
      server.onRequest(
        'GET',
        '/api/status',
        (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'down',
        ),
      );
      await pump(tester);
      expect(find.text("Can't reach Hermes"), findsOneWidget);
      // The sections that need the status are hidden; Tools stay.
      expect(find.text('Messaging gateway'), findsNothing);
      expect(find.text('Usage'), findsOneWidget);
      expect(find.text('Connection details'), findsOneWidget);
      final reads = server.requestsTo('GET', '/api/status').length;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(server.requestsTo('GET', '/api/status').length, reads + 1);
    });
  });

  group('parts the server lacks', () {
    testWidgets('hide the update check and the status components', (
      tester,
    ) async {
      server
        ..on('GET', '/api/status', statusOld())
        ..on('GET', '/api/hermes/update/check', null, status: 404);
      await pump(tester);
      expect(find.text('Everything looks good'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Updates'), findsNothing);
      expect(find.text('Channels'), findsNothing);
      expect(find.text('Disk'), findsNothing);
      expect(find.text('Memory'), findsNothing);
      expect(find.text('Session store'), findsNothing);
      expect(find.text('Shared with'), findsNothing);
      expect(find.text("Couldn't check"), findsNothing);
    });
  });

  group('Updates row', () {
    testWidgets('says up to date', (tester) async {
      await pump(tester);
      expect(find.text('Up to date'), findsOneWidget);
    });

    testWidgets('says an update is available, with the change count', (
      tester,
    ) async {
      server.on('GET', '/api/hermes/update/check', updateCheckBehind());
      await pump(tester);
      // The test font is wide, so the value may move under the title.
      expect(find.textContaining('Update available'), findsOneWidget);
      expect(find.textContaining('2 changes'), findsOneWidget);
      // An update alone is not an attention state.
      expect(find.text('Everything looks good'), findsOneWidget);
    });

    testWidgets("says it couldn't check", (tester) async {
      server.on('GET', '/api/hermes/update/check', updateCheckDocker());
      await pump(tester);
      expect(find.text("Couldn't check"), findsOneWidget);
    });

    testWidgets('opens the Update page, whose Check now forces the check', (
      tester,
    ) async {
      await pump(tester);
      expect(
        server
            .requestsTo('GET', '/api/hermes/update/check')
            .every((r) => r.queryParameters['force'] != true),
        isTrue,
      );
      await tester.tap(find.text('Updates'));
      await tester.pumpAndSettle();
      expect(find.text('Hermes is up to date'), findsOneWidget);
      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();
      expect(
        server
            .requestsTo('GET', '/api/hermes/update/check')
            .any((r) => r.queryParameters['force'].toString() == 'true'),
        isTrue,
      );
    });
  });

  group('restarting and starting the gateway', () {
    void answers({bool running = true}) {
      server
        ..on('POST', '/api/gateway/restart', {
          'ok': true,
          'pid': 1,
          'name': 'gateway-restart',
        })
        ..on('POST', '/api/gateway/start', {
          'ok': true,
          'pid': 2,
          'name': 'gateway-start',
        })
        ..on('GET', '/api/actions/gateway-restart/status', {
          'name': 'gateway-restart',
          'running': false,
          'exit_code': 0,
          'lines': <String>[],
        })
        ..on('GET', '/api/actions/gateway-start/status', {
          'name': 'gateway-start',
          'running': false,
          'exit_code': 0,
          'lines': <String>[],
        })
        ..on('GET', '/api/status', {
          ...statusHealthy(),
          'gateway_running': running,
          'gateway_state': running ? 'running' : 'stopped',
        });
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a start runs at once, with the profile, no question asked', (
      tester,
    ) async {
      gatewayOff();
      await pump(tester);
      answers(running: false);
      server.on('GET', '/api/status', {
        ...statusHealthy(),
        'gateway_running': false,
        'gateway_state': 'stopped',
      });
      await tester.tap(find.text('Start gateway').first);
      await tester.pump();
      await settle(tester);
      final posts = server.requestsTo('POST', '/api/gateway/start');
      expect(posts, hasLength(1));
      expect(posts.single.queryParameters, {'profile': 'default'});
      expect(find.text('Restart the messaging gateway?'), findsNothing);
    });

    testWidgets('a restart asks first, and Cancel sends nothing', (
      tester,
    ) async {
      answers();
      server.on('GET', '/api/status', {
        ...statusHealthy(),
        'gateway_state': 'startup_failed',
        'gateway_running': false,
        'active_agents': 2,
      });
      await pump(tester);
      await tester.tap(find.text('Restart gateway').first);
      await tester.pumpAndSettle();
      expect(find.text('Restart the messaging gateway?'), findsOneWidget);
      expect(
        find.textContaining('Chats in this app keep running.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 conversations on messaging channels'),
        findsOneWidget,
      );
      expect(find.textContaining('This gateway is shared'), findsOneWidget);
      expect(find.text('Restart for all'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.requestsTo('POST', '/api/gateway/restart'), isEmpty);
    });

    testWidgets('confirming restarts with the profile and reads the status '
        'again', (tester) async {
      answers();
      await pump(tester);
      final before = server.requestsTo('GET', '/api/status').length;
      await tester.tap(find.text('Restart gateway'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart for all'));
      await tester.pump();
      await settle(tester);
      final posts = server.requestsTo('POST', '/api/gateway/restart');
      expect(posts, hasLength(1));
      expect(posts.single.queryParameters, {'profile': 'default'});
      expect(
        server.requestsTo('GET', '/api/status').length,
        greaterThan(before),
      );
      expect(find.text('Running again'), findsOneWidget);
    });

    testWidgets('a refusal shows Hermes\' own text and sends nothing again', (
      tester,
    ) async {
      answers();
      server.on('POST', '/api/gateway/restart', {
        'detail': 'gateway restart already in progress for another profile',
      }, status: 500);
      await pump(tester);
      await tester.tap(find.text('Restart gateway'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart for all'));
      await tester.pump();
      await settle(tester);
      expect(
        find.text('gateway restart already in progress for another profile'),
        findsOneWidget,
      );
      expect(server.requestsTo('POST', '/api/gateway/restart'), hasLength(1));
    });
  });

  group('pages it opens', () {
    testWidgets('Usage and Update open with the controller above them', (
      tester,
    ) async {
      server.on('GET', '/api/analytics/usage', usage30());
      await pump(tester);
      await tester.tap(find.text('Usage'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.text('Tokens'), findsWidgets);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Updates'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Hermes is up to date'), findsOneWidget);
    });
  });

  group('a failed read', () {
    testWidgets('does not keep an older cheerful headline', (tester) async {
      await pump(tester);
      expect(find.text('Everything looks good'), findsOneWidget);
      server.on('GET', '/api/status', {}, status: 500);
      await tester.runAsync(care.refresh);
      await tester.pumpAndSettle();
      expect(find.text('Everything looks good'), findsNothing);
      expect(find.text("Couldn't read Hermes' status"), findsOneWidget);
      expect(find.text('Messaging gateway'), findsNothing);
      // The update check does not depend on the status.
      expect(find.text('Updates'), findsOneWidget);
    });
  });

  group('a missing or failing part', () {
    testWidgets('a failed re-check says so instead of keeping the old answer', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Updates'));
      await tester.pumpAndSettle();
      expect(find.text('Hermes is up to date'), findsOneWidget);

      server.on('GET', '/api/hermes/update/check', {}, status: 500);
      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();
      expect(find.text('Hermes is up to date'), findsNothing);
      expect(find.text("Couldn't check"), findsWidgets);
    });

    testWidgets('Usage goes from Tools once the server has no usage route', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Usage'), findsOneWidget);
      care.reportUnsupported(CarePart.usage);
      await tester.pumpAndSettle();
      expect(find.text('Usage'), findsNothing);
      expect(find.text('Tools'), findsNothing);
    });
  });

  group('Usage on a server without the route', () {
    testWidgets('closes the page it opened and hides the row', (tester) async {
      server.on('GET', '/api/analytics/usage', {
        'detail': 'Not Found',
      }, status: 404);
      await pump(tester);
      await tester.tap(find.text('Usage'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text("Usage isn't available"), findsNothing);
      expect(find.text('Server'), findsWidgets);
      expect(find.text('Usage'), findsNothing);
    });
  });

  group('sizes follow the language', () {
    testWidgets('a German disk size uses a decimal comma', (tester) async {
      server.on('GET', '/api/status', {
        ...statusHealthy(),
        'disk': {'pressure': 'ok', 'free_mb': 8600, 'used_percent': 91.0},
      });
      await pump(tester, locale: const Locale('de'));
      expect(find.textContaining('8,6 GB'), findsWidgets);
    });

    testWidgets('an English one keeps the point', (tester) async {
      server.on('GET', '/api/status', {
        ...statusHealthy(),
        'disk': {'pressure': 'ok', 'free_mb': 8600, 'used_percent': 91.0},
      });
      await pump(tester);
      expect(find.textContaining('8.6 GB'), findsWidgets);
    });
  });

  group('Server section', () {
    testWidgets('shows the free space with the share used under it', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('52 GB free'), findsOneWidget);
      expect(find.text('38% used'), findsOneWidget);
      expect(find.text('Disk space is getting low.'), findsNothing);
      expect(find.text('OK'), findsNWidgets(2));
    });

    testWidgets('warns when the disk is getting full', (tester) async {
      server.on('GET', '/api/status', {
        ...statusHealthy(),
        'disk': {'pressure': 'critical', 'free_mb': 1200, 'used_percent': 97.0},
      });
      await pump(tester);
      expect(find.text('Disk almost full: 1.2 GB free'), findsOneWidget);
      expect(find.text('1.2 GB free'), findsOneWidget);
      expect(find.text('97% used'), findsOneWidget);
      expect(
        find.text('Disk is almost full. Hermes may stop saving chats.'),
        findsOneWidget,
      );
    });

    testWidgets('moves a gateway state that is too long under its title', (
      tester,
    ) async {
      server.on('GET', '/api/status', {
        ...statusHealthy(),
        'gateway_state': 'degraded',
        'components': {
          'storage': {'status': 'ok'},
          'platforms': {'configured': 2, 'connected': 1},
        },
      });
      await pump(tester, size: const Size(360, 1600));
      expect(
        find.text('1 of 2 messaging channels are offline'),
        findsOneWidget,
      );
      expect(find.text('Running, some channels offline'), findsOneWidget);
      expect(find.text('1 of 2 connected'), findsOneWidget);
    });
  });

  group('privacy and profile', () {
    testWidgets('every profile route carries the explicit profile', (
      tester,
    ) async {
      await pump(tester);
      final reads = server.requestsTo('GET', '/api/status');
      expect(reads, isNotEmpty);
      expect(
        reads.every((r) => r.queryParameters['profile'] == 'default'),
        true,
      );
    });

    testWidgets('the opening breadcrumb carries only its source', (
      tester,
    ) async {
      server.on('GET', '/api/hermes/update/check', updateCheckBehind());
      await pump(tester);
      expect(
        [for (final c in trail.recent) '${c.name} ${c.attributes}'],
        ['server_care.opened {source: test}'],
      );
    });
  });
}
