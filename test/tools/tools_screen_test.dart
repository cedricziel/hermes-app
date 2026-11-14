import 'dart:async';

import 'package:dio/dio.dart' show RequestOptions;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:hermes_app/src/tools/tools_availability.dart';
import 'package:hermes_app/src/tools/tools_screen.dart';
import 'package:hermes_app/src/tools/widgets/tools_switch.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import 'tools_screen_fixtures.dart';

const _phone = Size(390, 844);
const _wide = Size(1200, 900);

void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    routeTools(server);
  });

  Finder row(String name) => find.byKey(ValueKey('tool-row-$name'));
  Finder switchOf(String name) =>
      find.descendant(of: row(name), matching: find.byType(ToolsSwitch));
  bool isOn(WidgetTester tester, String name) =>
      tester.widget<ToolsSwitch>(switchOf(name)).value;
  Iterable<RequestOptions> puts() => server.requests.where(
    (r) => r.method == 'PUT' && r.path.startsWith('/api/tools/toolsets/'),
  );
  int listReads() => server.requestsTo('GET', '/api/tools/toolsets').length;

  Future<void> pumpTools(
    WidgetTester tester, {
    Size size = _phone,
    TargetPlatform platform = TargetPlatform.android,
    ToolsAvailability? availability,
    AppLockController? lock,
    VoidCallback? onProfileGone,
    Locale locale = const Locale('en'),
    bool settle = true,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHermesLightTheme(platform: platform),
      home: const Scaffold(body: Text('home')),
    );
    await tester.pumpWidget(
      lock == null
          ? app
          : ChangeNotifierProvider<AppLockController>.value(
              value: lock,
              child: app,
            ),
    );
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ToolsScreen(
                repository: HermesToolsRepository(
                  server.client().raw,
                  profile: 'work',
                ),
                availability: availability,
                onProfileGone: onProfileGone,
              ),
            ),
          ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// Taps [name]'s switch, scrolling it into view first.
  Future<void> tapSwitch(WidgetTester tester, String name) async {
    await tester.ensureVisible(switchOf(name));
    await tester.pump();
    await tester.tap(switchOf(name));
  }

  /// Taps the text of a row, which opens its details.
  Future<void> openRow(WidgetTester tester, String text) async {
    final finder = find.descendant(
      of: find.byKey(const Key('tools-list')),
      matching: find.text(text),
    );
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> scrollToTop(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('tools-list')),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(
      find.byKey(const Key('tools-list')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
  }

  group('the list', () {
    testWidgets('groups the rows as Needs setup, On and Off, in that order', (
      tester,
    ) async {
      await pumpTools(tester);

      expect(find.text('Tools'), findsWidgets);
      expect(find.text('work · 2 on'), findsOneWidget);
      final setup = tester.getTopLeft(find.text('Needs setup').first).dy;
      final on = tester.getTopLeft(find.text('On').first).dy;
      final off = tester.getTopLeft(find.text('Off').first).dy;
      expect(setup, lessThan(on));
      expect(on, lessThan(off));
      // Web is on but not configured, so it sits under Needs setup.
      expect(
        tester.getTopLeft(row('web')).dy,
        lessThan(tester.getTopLeft(row('file')).dy),
      );
      expect(isOn(tester, 'web'), isTrue);
      expect(isOn(tester, 'terminal'), isFalse);
      expect(
        server.requestsTo('GET', '/api/tools/toolsets').single.queryParameters,
        containsPair('profile', 'work'),
      );
    });

    testWidgets('leaves out the groups that are empty', (tester) async {
      server.on('GET', '/api/tools/toolsets', [
        toolsetRow('file', enabled: true),
        toolsetRow('todo'),
      ]);
      await pumpTools(tester);

      expect(find.text('Needs setup'), findsNothing);
      expect(find.text('On'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('says what a built-in does in its own words and a plugin '
        'in the server\'s', (tester) async {
      await pumpTools(tester);

      expect(
        find.text('Run commands on the machine where Hermes runs.'),
        findsOneWidget,
      );
      expect(find.text('Terminal & Processes'), findsNothing);
      expect(find.text('Acme digest'), findsOneWidget);
      expect(
        find.text('Summarize the team channel every morning.'),
        findsOneWidget,
      );
      // The risk line of terminal and files; none for the plugin.
      expect(
        find.descendant(
          of: row('terminal'),
          matching: find.text('Can change things'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row('acme_digest'),
          matching: find.text('Can change things'),
        ),
        findsNothing,
      );
    });

    testWidgets('starts from the rows the shell read and still reads', (
      tester,
    ) async {
      final availability = ToolsAvailability(
        HermesToolsRepository(server.client().raw, profile: 'work'),
      );
      addTearDown(availability.dispose);
      await tester.runAsync(() => availability.refresh('work'));
      final before = listReads();
      final gate = holdAnswer(server, 'GET', '/api/tools/toolsets');

      await pumpTools(tester, availability: availability, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      // The rows are there while the read is still out.
      expect(row('terminal'), findsOneWidget);
      expect(find.text('Loading tools…'), findsNothing);
      expect(listReads(), before + 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(row('terminal'), findsOneWidget);
    });

    testWidgets('shows a progress state while it loads', (tester) async {
      final gate = holdAnswer(server, 'GET', '/api/tools/toolsets');
      await pumpTools(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Loading tools…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Loading tools…'), findsNothing);
    });

    testWidgets('says so when the profile has no tools', (tester) async {
      server.on('GET', '/api/tools/toolsets', <Object?>[]);
      await pumpTools(tester);

      expect(find.text('This profile has no tools to set up.'), findsOneWidget);
      expect(
        find.text('Tools Hermes offers for this profile will show here.'),
        findsOneWidget,
      );
    });

    testWidgets('the footer opens "What\'s the difference?"', (tester) async {
      await pumpTools(tester);

      await tester.scrollUntilVisible(
        find.text('What\'s the difference?'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('What\'s the difference?'));
      await tester.pumpAndSettle();

      expect(find.text('Tools, skills, plugins and MCP servers'), findsOne);
      expect(find.textContaining('written instructions Hermes'), findsOne);
    });

    testWidgets('is German in a German app', (tester) async {
      await pumpTools(tester, locale: const Locale('de'));

      expect(find.text('work · 2 an'), findsOneWidget);
      expect(find.text('Einrichtung nötig'), findsWidgets);
    });
  });

  group('switching', () {
    testWidgets('a plain toolset is sent at once and moves after the read', (
      tester,
    ) async {
      await pumpTools(tester);

      await tapSwitch(tester, 'todo');
      await tester.pumpAndSettle();

      final sent = puts().single;
      expect(sent.path, '/api/tools/toolsets/todo');
      expect(
        writeBody(sent),
        allOf(containsPair('enabled', true), containsPair('profile', 'work')),
      );
      expect(isOn(tester, 'todo'), isTrue);
      expect(find.text('work · 3 on'), findsOneWidget);
      await scrollToTop(tester);
      expect(find.text('Applies from your next chat.'), findsOneWidget);
      expect(
        find.text(
          'A chat that is already open keeps the tools it started with.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a confirm-level toolset sends nothing until Switch on, and '
        'the switch stays off while the question is open', (tester) async {
      await pumpTools(tester);

      await tapSwitch(tester, 'terminal');
      await tester.pumpAndSettle();

      expect(find.text('Let Hermes run commands?'), findsOneWidget);
      expect(
        find.textContaining('It applies to the profile "work".'),
        findsOneWidget,
      );
      expect(puts(), isEmpty);
      expect(isOn(tester, 'terminal'), isFalse);

      await tester.tap(find.text('Switch on'));
      await tester.pumpAndSettle();

      expect(puts().single.path, '/api/tools/toolsets/terminal');
      expect(isOn(tester, 'terminal'), isTrue);
    });

    testWidgets('Cancel sends nothing and leaves the switch off', (
      tester,
    ) async {
      await pumpTools(tester);

      await tapSwitch(tester, 'terminal');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Let Hermes run commands?'), findsNothing);
      expect(puts(), isEmpty);
      expect(isOn(tester, 'terminal'), isFalse);
      // The same switch asks again.
      await tapSwitch(tester, 'terminal');
      await tester.pumpAndSettle();
      expect(find.text('Let Hermes run commands?'), findsOneWidget);
    });

    testWidgets('a toolset with an install step asks first', (tester) async {
      await pumpTools(tester);

      await tapSwitch(tester, 'tts');
      await tester.pumpAndSettle();

      expect(find.text('Install on your server?'), findsOneWidget);
      expect(
        find.textContaining('Switching Text to speech on may run an installer'),
        findsOneWidget,
      );
      expect(puts(), isEmpty);
      expect(isOn(tester, 'tts'), isFalse);

      await tester.tap(find.text('Switch on'));
      await tester.pumpAndSettle();
      expect(puts().single.path, '/api/tools/toolsets/tts');
    });

    testWidgets('switching off asks nothing', (tester) async {
      await pumpTools(tester);

      await tapSwitch(tester, 'file');
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(writeBody(puts().single), containsPair('enabled', false));
    });

    testWidgets('a refusal rolls the switch back with Hermes\' own text', (
      tester,
    ) async {
      server.on('PUT', '/api/tools/toolsets/todo', {
        'detail': 'Planning is locked for this platform.',
      }, status: 400);
      await pumpTools(tester);

      await tapSwitch(tester, 'todo');
      await tester.pumpAndSettle();

      expect(isOn(tester, 'todo'), isFalse);
      expect(
        find.descendant(
          of: row('todo'),
          matching: find.text('Planning is locked for this platform.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Applies from your next chat.'), findsNothing);
    });

    testWidgets('other failures say what failed, on the row', (tester) async {
      server.on('PUT', '/api/tools/toolsets/todo', {
        'detail': 'x',
      }, status: 500);
      goOffline(server, 'PUT', '/api/tools/toolsets/tts');
      server.on('PUT', '/api/tools/toolsets/acme_digest', {
        'detail': 'x',
      }, status: 403);
      await pumpTools(tester);

      await tapSwitch(tester, 'todo');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: row('todo'),
          matching: find.text('Couldn\'t change Task planning. Try again.'),
        ),
        findsOneWidget,
      );

      await tapSwitch(tester, 'acme_digest');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: row('acme_digest'),
          matching: find.text('You can\'t change tools on this server.'),
        ),
        findsOneWidget,
      );

      await tapSwitch(tester, 'tts');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch on'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: row('tts'),
          matching: find.text(
            'You\'re offline. Couldn\'t change Text to speech.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a lost answer ends in "Couldn\'t confirm" within 10 seconds, '
        'and nothing is sent again', (tester) async {
      await pumpTools(tester);
      loseAnswer(server, 'PUT', '/api/tools/toolsets/todo');
      holdAnswer(server, 'GET', '/api/tools/toolsets');

      await tapSwitch(tester, 'todo');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('May have changed. Checking…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));
      expect(find.text('May have changed. Checking…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1, milliseconds: 200));

      expect(find.text('May have changed. Checking…'), findsNothing);
      expect(find.text('Couldn\'t confirm. Pull to refresh.'), findsOneWidget);
      expect(isOn(tester, 'todo'), isFalse);
      expect(puts(), hasLength(1));
      await tester.pump(const Duration(seconds: 30));
      expect(puts(), hasLength(1));
    });

    testWidgets('on a wide window "Couldn\'t confirm" offers Try again', (
      tester,
    ) async {
      await pumpTools(tester, size: _wide);
      loseAnswer(server, 'PUT', '/api/tools/toolsets/todo');
      final gate = holdAnswer(server, 'GET', '/api/tools/toolsets');

      await tapSwitch(tester, 'todo');
      await tester.pump(const Duration(seconds: 11));

      expect(find.text('Couldn\'t confirm. Try again.'), findsWidgets);
      expect(find.text('Pull to refresh'), findsNothing);
      gate.complete();
      server.on('GET', '/api/tools/toolsets', toolsCatalog(on: {'todo'}));
      await tester.tap(find.text('Try again').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Couldn\'t confirm'), findsNothing);
      expect(isOn(tester, 'todo'), isTrue);
      expect(puts(), hasLength(1));
    });

    testWidgets('a second tap waits for the first answer', (tester) async {
      await pumpTools(tester);
      final gate = Completer<void>();
      server.onRequest('PUT', '/api/tools/toolsets/todo', (_) async {
        await gate.future;
        return (
          status: 200,
          body: {'ok': true, 'name': 'todo', 'enabled': true},
        );
      });

      await tapSwitch(tester, 'todo');
      await tester.pump(const Duration(milliseconds: 50));
      // The switch is disabled while the write is out.
      await tapSwitch(tester, 'todo');
      await tester.pump(const Duration(milliseconds: 50));
      expect(puts(), hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();
      expect(puts(), hasLength(1));
    });

    testWidgets('a toolset that left the server says so', (tester) async {
      await pumpTools(tester);
      server
        ..on('PUT', '/api/tools/toolsets/todo', {
          'detail': 'Unknown toolset: todo',
        }, status: 400)
        ..on(
          'GET',
          '/api/tools/toolsets',
          toolsCatalog().where((t) => t['name'] != 'todo').toList(),
        );

      await tapSwitch(tester, 'todo');
      await tester.pumpAndSettle();

      await scrollToTop(tester);
      expect(find.text('That tool is no longer on this server.'), findsOne);
      expect(row('todo'), findsNothing);
    });
  });

  group('when the list cannot be read', () {
    testWidgets('an old server hides the content and offers Back', (
      tester,
    ) async {
      server.on('GET', '/api/tools/toolsets', {
        'detail': 'Not Found',
      }, status: 404);
      await pumpTools(tester);

      expect(find.text('This server doesn\'t offer tools settings.'), findsOne);
      expect(find.text('Updating Hermes on the server adds them.'), findsOne);
      expect(find.text('Couldn\'t load tools.'), findsNothing);
      expect(row('terminal'), findsNothing);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolsScreen), findsNothing);
    });

    testWidgets('a server that loses the route while it is open says so', (
      tester,
    ) async {
      await pumpTools(tester);
      server.on('GET', '/api/tools/toolsets', {
        'detail': 'Not Found',
      }, status: 404);

      await pullToRefresh(tester);

      expect(find.text('This server doesn\'t offer tools settings.'), findsOne);
      expect(row('terminal'), findsNothing);
      // What the server listed before is not counted any more.
      expect(find.text('work · 2 on'), findsNothing);
      expect(find.text('work'), findsOneWidget);
    });

    testWidgets('a failed read keeps the rows under a banner', (tester) async {
      await pumpTools(tester);
      server.on('GET', '/api/tools/toolsets', {'detail': 'x'}, status: 500);

      await pullToRefresh(tester);

      expect(find.text('Couldn\'t load tools.'), findsOneWidget);
      expect(find.text('The list below may be out of date.'), findsOneWidget);
      expect(row('terminal'), findsOneWidget);

      routeTools(server);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn\'t load tools.'), findsNothing);
    });

    testWidgets('offline keeps the rows under a banner', (tester) async {
      await pumpTools(tester);
      goOffline(server, 'GET', '/api/tools/toolsets');

      await pullToRefresh(tester);

      expect(find.text('You\'re offline.'), findsOneWidget);
      expect(
        find.text('Couldn\'t load tools. Switches show what was last saved.'),
        findsOneWidget,
      );
      expect(row('terminal'), findsOneWidget);
      // Nothing is read again by itself.
      final reads = listReads();
      await tester.pump(const Duration(seconds: 60));
      expect(listReads(), reads);
    });

    testWidgets('a first read that fails offers Try again', (tester) async {
      goOffline(server, 'GET', '/api/tools/toolsets');
      await pumpTools(tester);

      expect(find.text('You\'re offline.'), findsOneWidget);
      expect(row('terminal'), findsNothing);

      routeTools(server);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(row('terminal'), findsOneWidget);
    });

    testWidgets('a deleted profile says so and asks for the profiles again', (
      tester,
    ) async {
      var reads = 0;
      server.on('GET', '/api/tools/toolsets', {
        'detail': "Profile 'work' does not exist",
      }, status: 404);
      await pumpTools(tester, onProfileGone: () => reads++);

      expect(find.text('This profile no longer exists.'), findsOneWidget);
      expect(
        find.text('This server doesn\'t offer tools settings.'),
        findsNothing,
      );
      expect(reads, 1);
    });
  });

  group('the details', () {
    testWidgets('open as a page below 900 points and close with Back', (
      tester,
    ) async {
      await pumpTools(tester);

      await tester.tap(
        find.text('Run commands on the machine where Hermes runs.'),
      );
      await tester.pumpAndSettle();

      // Header, risk note, where it applies, and the collapsed tool names.
      expect(find.text('Can change things on your server'), findsOneWidget);
      expect(find.text('Hermes asks before you switch it on.'), findsOneWidget);
      expect(
        find.text('Used in your chats in this app and in the terminal.'),
        findsOneWidget,
      );
      expect(find.text('What\'s inside (2)'), findsOneWidget);
      expect(find.text('read_file'), findsNothing);
      // The tap on the text did not switch anything.
      expect(puts(), isEmpty);

      await tester.tap(find.text('What\'s inside (2)'));
      await tester.pumpAndSettle();
      expect(find.text('terminal'), findsOneWidget);
      expect(find.text('process'), findsOneWidget);
      expect(
        find.text('These are the names you see on tool cards in a chat.'),
        findsOneWidget,
      );
    });

    testWidgets('switch from the page, with the same question', (tester) async {
      await pumpTools(tester);
      await tester.tap(
        find.text('Run commands on the machine where Hermes runs.'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ToolsSwitch));
      await tester.pumpAndSettle();
      expect(find.text('Let Hermes run commands?'), findsOneWidget);
      expect(puts(), isEmpty);
      await tester.tap(find.text('Switch on'));
      await tester.pumpAndSettle();

      expect(puts().single.path, '/api/tools/toolsets/terminal');
      expect(find.text('On'), findsWidgets);
      expect(find.text('Applies from your next chat.'), findsOneWidget);
    });

    testWidgets('sit beside the list from 900 points, selected row filled', (
      tester,
    ) async {
      await pumpTools(tester, size: _wide);

      // The first row's details show, with no Back button of their own.
      expect(
        find.text('Used in your chats in this app and in the terminal.'),
        findsOneWidget,
      );
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(
        find.text('Run commands on the machine where Hermes runs.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Can change things on your server'), findsOneWidget);
      expect(find.byType(ToolsScreen), findsOneWidget);

      await openRow(tester, 'Summarize the team channel every morning.');
      expect(find.text('Can change things on your server'), findsNothing);
      expect(find.text('What\'s inside (1)'), findsOneWidget);
    });

    testWidgets('a vanished toolset moves the selection to the first row', (
      tester,
    ) async {
      await pumpTools(tester, size: _wide);
      await openRow(tester, 'Task planning');
      expect(find.text('What\'s inside (1)'), findsOneWidget);
      server
        ..on('PUT', '/api/tools/toolsets/todo', {
          'detail': 'Unknown toolset: todo',
        }, status: 400)
        ..on(
          'GET',
          '/api/tools/toolsets',
          toolsCatalog().where((t) => t['name'] != 'todo').toList(),
        );

      await tapSwitch(tester, 'todo');
      await tester.pumpAndSettle();

      await scrollToTop(tester);
      expect(find.text('That tool is no longer on this server.'), findsOne);
      // Web is the first row; its details show.
      expect(find.text('What\'s inside (2)'), findsOneWidget);
    });
  });

  group('App Lock', () {
    testWidgets('dismisses an open question as cancelled', (tester) async {
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
      await pumpTools(tester, lock: lock);

      await tapSwitch(tester, 'terminal');
      await tester.pumpAndSettle();
      expect(find.text('Let Hermes run commands?'), findsOneWidget);

      // Inactive covers the app at once, and frames still run.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      expect(lock.covered, isTrue);
      expect(find.text('Let Hermes run commands?'), findsNothing);
      expect(puts(), isEmpty);
      expect(isOn(tester, 'terminal'), isFalse);
    });
  });

  group('on a Mac', () {
    testWidgets('has no pull to refresh and the Try again wording', (
      tester,
    ) async {
      await pumpTools(
        tester,
        size: const Size(800, 700),
        platform: TargetPlatform.macOS,
      );

      expect(find.byType(RefreshIndicator), findsNothing);
      expect(row('terminal'), findsOneWidget);
      loseAnswer(server, 'PUT', '/api/tools/toolsets/todo');
      holdAnswer(server, 'GET', '/api/tools/toolsets');
      await tapSwitch(tester, 'todo');
      await tester.pump(const Duration(seconds: 11));
      expect(find.text('Couldn\'t confirm. Try again.'), findsWidgets);
    });
  });
}
