import 'dart:async';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/navigation/connection_pages.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/soul/open_soul.dart';
import 'package:hermes_app/src/profiles/soul/soul_availability.dart';
import 'package:hermes_app/src/profiles/soul/soul_screen.dart';
import 'package:hermes_app/src/profiles/soul/soul_telemetry.dart';
import 'package:hermes_app/src/server_care/widgets/private_surface.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_device_authenticator.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/mac_commands_builder.dart';
import '../../support/recorded_events.dart';
import '../../support/recording_tracer.dart';
import 'soul_fixtures.dart';

/// Puts the platform override back before the framework checks that no debug
/// variable was left changed.
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

class _Auth extends AuthController {
  var _state = HermesConnectionState.ready;
  var _owner = 1;
  var _allowed = true;
  final _server = 'https://hermes.example';

  @override
  HermesConnectionState get state => _state;
  @override
  bool get protectedRequestsAllowed =>
      _allowed && _state == HermesConnectionState.ready;
  @override
  int get ownerGeneration => _owner;
  @override
  String? get baseUrl => _server;

  /// An expiry the stored session may still rescue: ready, but closed.
  void pauseRequests() {
    _allowed = false;
    notifyListeners();
  }

  void restoreRequests() {
    _allowed = true;
    notifyListeners();
  }

  void endConnection() {
    _state = HermesConnectionState.needsLogin;
    _owner++;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late BreadcrumbTrail trail;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late SoulAvailability availability;
  late AppLockController lock;
  late ChatProfiles chatProfiles;

  var fileText = 'You are Quill.';
  var fileExists = true;
  var putStatus = 200;
  Object? putBody = soulSaved;
  final puts = <String>[];

  int gets() => server.requestsTo('GET', soulPath).length;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail();
    tracer = RecordingTracer();
    events = RecordedEvents();
    availability = SoulAvailability();
    lock = AppLockController(
      authenticator: FakeDeviceAuthenticator(),
      coverWhenInactive: true,
    );
    chatProfiles = ChatProfiles(
      HermesProfilesRepository(FakeHermesServer().client().raw),
    );
    fileText = 'You are Quill.';
    fileExists = true;
    putStatus = 200;
    putBody = soulSaved;
    puts.clear();
    server = FakeHermesServer()
      ..onRequest(
        'GET',
        soulPath,
        (_) => (status: 200, body: {'content': fileText, 'exists': fileExists}),
      )
      ..onRequest('PUT', soulPath, (request) {
        final sent =
            (jsonBody(request)! as Map<String, Object?>)['content']! as String;
        puts.add(sent);
        if (putStatus == 200 && putBody == soulSaved) {
          fileText = sent;
          fileExists = true;
        }
        return (status: putStatus, body: putBody);
      });
  });

  tearDown(() {
    lock.dispose();
    chatProfiles.dispose();
    availability.dispose();
  });

  /// Opens the page through [openSoul] from a button, as the entry points do,
  /// under the providers the app has.
  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    double width = 400,
    String profile = soulProfile,
    bool withLock = false,
    _Auth? auth,
    SoulOpenedFrom from = SoulOpenedFrom.sidebar,
    bool settle = true,
    bool withCloser = true,
    MacCommandRegistry? commands,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final pushed = PushedRoutes();
    if (auth != null && withCloser) {
      final closer = ConnectionPageCloser(pushed)..bind(auth);
      addTearDown(closer.dispose);
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HermesRepositories>.value(
            value: HermesRepositories(
              server.client(),
              telemetry: ConnectionTelemetry(
                events: events.call,
                tracer: tracer,
                serverAttributes: const {'hermes.version': '0.14.2'},
              ),
            ),
          ),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          ChangeNotifierProvider<SoulAvailability?>.value(value: availability),
          ChangeNotifierProvider<ChatProfiles>.value(value: chatProfiles),
          if (withLock)
            ChangeNotifierProvider<AppLockController>.value(value: lock),
          if (auth != null)
            ChangeNotifierProvider<AuthController>.value(value: auth),
        ],
        child: MaterialApp(
          navigatorObservers: [pushed],
          builder: macCommandsBuilder(commands),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    unawaited(openSoul(context, profile: profile, from: from)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Finder editor() => find.byType(TextField);
  Finder phoneSave() => find.widgetWithText(TextButton, 'Save');
  Finder wideSave() => find.widgetWithText(FilledButton, 'Save');

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(editor(), text);
    await tester.pump();
  }

  group('opening', () {
    pageTest('reads the file of the profile it was opened for', (tester) async {
      await pump(tester);
      final get = server.requestsTo('GET', soulPath).single;
      expect(get.queryParameters, isEmpty);
      expect(find.text('Personality'), findsWidgets);
      expect(find.text(soulProfile), findsWidgets);
      expect(find.text('You are Quill.'), findsOneWidget);
      expect(
        find.textContaining('This is the SOUL.md file Hermes reads'),
        findsOneWidget,
      );
    });

    pageTest('shows a spinner and the loading line while it reads', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('GET', soulPath, (_) => answer.future);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await pump(tester, settle: false);
      expect(find.text('Loading personality…'), findsOneWidget);
      expect(editor(), findsNothing);
      answer.complete((status: 200, body: soulWithText));
      await tester.pumpAndSettle();
      expect(editor(), findsOneWidget);
    });

    pageTest('a file that is not there yet says so and offers no revert', (
      tester,
    ) async {
      fileExists = false;
      fileText = '';
      await pump(tester);
      expect(find.text('No personality set yet.'), findsOneWidget);
      expect(find.text('0 characters'), findsOneWidget);
    });

    pageTest('an empty file says Hermes uses its default personality', (
      tester,
    ) async {
      fileText = '';
      await pump(tester);
      expect(
        find.text('Hermes uses its default personality while this is empty.'),
        findsOneWidget,
      );
    });

    pageTest('a long text only adds the note and stays editable', (
      tester,
    ) async {
      fileText = 'a' * 20500;
      await pump(tester);
      expect(
        find.textContaining('Hermes may shorten text this long'),
        findsOneWidget,
      );
      await type(tester, '${'a' * 20500}b');
      expect(phoneSave().evaluate().isNotEmpty, isTrue);
      expect(tester.widget<TextButton>(phoneSave()).onPressed, isNotNull);
    });

    pageTest('the opened breadcrumb names the source and nothing else', (
      tester,
    ) async {
      await pump(tester, from: SoulOpenedFrom.profilesPage);
      expect(
        trail.recent
            .singleWhere((c) => c.name == 'profile_soul.opened')
            .attributes,
        {'source': 'profiles_page'},
      );
    });

    pageTest('the title names the profile and Save starts disabled', (
      tester,
    ) async {
      await pump(tester);
      expect(tester.widget<TextButton>(phoneSave()).onPressed, isNull);
      final revert = find.widgetWithText(TextButton, 'Revert');
      expect(tester.widget<TextButton>(revert).onPressed, isNull);
    });
  });

  group('failed reads', () {
    pageTest('a 500 shows the fixed line and no editor, Try again reads', (
      tester,
    ) async {
      server.on('GET', soulPath, soulPlainServerError, status: 500);
      await pump(tester);
      expect(editor(), findsNothing);
      expect(
        find.text("Couldn't read the personality file on the server."),
        findsOneWidget,
      );
      expect(find.textContaining(soulPlainServerError), findsNothing);
      server.on('GET', soulPath, soulWithText);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(editor(), findsOneWidget);
      expect(gets(), 2);
    });

    pageTest('a missing profile has a message and no editor or action', (
      tester,
    ) async {
      server.on('GET', soulPath, soulProfileMissing, status: 404);
      await pump(tester);
      expect(find.text('This profile no longer exists.'), findsOneWidget);
      expect(
        find.text('It may have been deleted on the server.'),
        findsOneWidget,
      );
      expect(editor(), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(availability.shown, isTrue);
    });

    pageTest('a route the server lacks explains it and hides the entries', (
      tester,
    ) async {
      server.on('GET', soulPath, soulRouteMissing, status: 404);
      await pump(tester);
      expect(
        find.text("This server doesn't offer personality settings."),
        findsOneWidget,
      );
      expect(editor(), findsNothing);
      expect(availability.shown, isFalse);
      // 48 dp on Android.
      expect(
        tester.getSize(find.widgetWithText(OutlinedButton, 'Back')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    pageTest('a 405 hides the entries too', (tester) async {
      server.on('GET', soulPath, {'detail': 'Method Not Allowed'}, status: 405);
      await pump(tester);
      expect(availability.shown, isFalse);
    });

    pageTest('no answer is the offline banner with Try again', (tester) async {
      server.onRequest(
        'GET',
        soulPath,
        (request) => throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        ),
      );
      await pump(tester);
      expect(find.text("You're offline."), findsOneWidget);
      expect(editor(), findsNothing);
    });
  });

  group('saving', () {
    pageTest('Save asks first and sends nothing before Replace', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      expect(
        find.text('Replace the personality of $soulProfile?'),
        findsOneWidget,
      );
      expect(puts, isEmpty);
      expect(gets(), 1);
      // Cancel is first on Android and sends nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(puts, isEmpty);
      expect(gets(), 1);
      expect(find.text('You are Mara.'), findsOneWidget);
      expect(tester.widget<TextButton>(phoneSave()).onPressed, isNotNull);

      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(puts, ['You are Mara.']);
      expect(gets(), 2);
      expect(find.text('Saved. New chats use it.'), findsOneWidget);
      expect(tester.widget<TextButton>(phoneSave()).onPressed, isNull);
    });

    pageTest('empty text asks with the default-personality wording', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, '');
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Hermes will use its default personality.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(puts, isEmpty);
    });

    pageTest('the editor is read-only while the save runs', (tester) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      final put = Completer<FakeResponse>();
      server.onRequest('PUT', soulPath, (_) => put.future);
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<TextField>(editor()).readOnly, isTrue);
      expect(find.text('Saving'), findsWidgets);
      put.complete((status: 200, body: soulSaved));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor()).readOnly, isFalse);
    });

    pageTest('a change on the server opens the sheet and sends nothing', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      fileText = 'Someone else wrote this.';
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.text('Changed on the server'), findsOneWidget);
      expect(puts, isEmpty);
      // The server's text is closed behind the disclosure.
      expect(find.text('Someone else wrote this.'), findsNothing);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(puts, isEmpty);
      expect(find.text('You are Mara.'), findsOneWidget);

      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace anyway'));
      await tester.pumpAndSettle();
      expect(puts, ['You are Mara.']);
      expect(find.text('Saved. New chats use it.'), findsOneWidget);
    });

    pageTest('a lost answer keeps the text and Check settles it', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      putBody = <String, Object?>{};
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't confirm the save"), findsOneWidget);
      expect(find.text('Saved. New chats use it.'), findsNothing);
      expect(find.text('You are Mara.'), findsOneWidget);
      expect(puts, hasLength(1));

      fileText = 'You are Mara.';
      await tester.tap(find.widgetWithText(TextButton, 'Check'));
      await tester.pumpAndSettle();
      expect(find.text('Saved. New chats use it.'), findsOneWidget);
      expect(puts, hasLength(1));
    });

    pageTest('a refused write shows the fixed error, never the body', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      putStatus = 500;
      putBody = {'detail': 'Could not write SOUL.md: /home/secret/path'};
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't save"), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      expect(tester.widget<TextButton>(phoneSave()).onPressed, isNotNull);
    });

    pageTest('a failed check read sends nothing and Try again repeats it', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      server.on('GET', soulPath, soulPlainServerError, status: 500);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't check the server first, so nothing was sent."),
        findsOneWidget,
      );
      expect(puts, isEmpty);
      server.on('GET', soulPath, {'content': fileText, 'exists': true});
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(puts, ['You are Mara.']);
    });

    pageTest('Save and Revert sit under the editor on a wide window', (
      tester,
    ) async {
      await pump(tester, width: 1100);
      expect(phoneSave(), findsNothing);
      expect(wideSave(), findsOneWidget);
      await type(tester, 'You are Mara.');
      await tester.tap(wideSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(puts, ['You are Mara.']);
    });
  });

  group('leaving', () {
    pageTest('back with unsaved changes asks and Keep editing stays', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(
        find.text(
          "Your edits to the personality of $soulProfile haven't been saved.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('You are Mara.'), findsOneWidget);
      expect(find.text('open'), findsNothing);
    });

    pageTest('Discard leaves the page and sends nothing', (tester) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(puts, isEmpty);
    });

    pageTest('back from a clean page asks nothing', (tester) async {
      await pump(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    pageTest('back after typing and undoing to the same text asks nothing', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      await type(tester, 'You are Quill.');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
    });

    pageTest('Revert asks and puts the loaded text back on Discard', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      final revert = find.widgetWithText(TextButton, 'Revert');
      await tester.tap(revert);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('You are Mara.'), findsOneWidget);

      await tester.tap(revert);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('You are Quill.'), findsOneWidget);
      expect(tester.widget<TextButton>(phoneSave()).onPressed, isNull);
      expect(puts, isEmpty);
    });

    pageTest('on iOS the question is the platform alert, Keep editing first', (
      tester,
    ) async {
      await pump(tester, platform: TargetPlatform.iOS);
      await type(tester, 'You are Mara.');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Keep editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    });
  });

  group('opening', () {
    pageTest('pushes on the root navigator, not a nested one', (tester) async {
      final root = GlobalKey<NavigatorState>();
      final nested = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<HermesRepositories>.value(
              value: HermesRepositories(server.client()),
            ),
          ],
          child: MaterialApp(
            navigatorKey: root,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              key: nested,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Builder(
                  builder: (context) => TextButton(
                    onPressed: () => unawaited(
                      openSoul(
                        context,
                        profile: soulProfile,
                        from: SoulOpenedFrom.sidebar,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final page = find.byType(SoulScreen);
      expect(page, findsOneWidget);
      expect(
        Navigator.of(tester.element(page)),
        same(root.currentState),
        reason: 'ConnectionPageCloser sweeps the root navigator only',
      );
      expect(nested.currentState!.canPop(), isFalse);
      expect(
        find.descendant(
          of: find.byWidget(nested.currentContext!.widget),
          matching: page,
        ),
        findsNothing,
      );
    });
  });

  group('at the largest text', () {
    pageTest('iOS keeps the title and the profile name, Save goes below', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pump(tester, platform: TargetPlatform.iOS);
      final title = tester.getRect(find.text('Personality').first);
      final profile = tester.getRect(find.text(soulProfile).first);
      for (final rect in [title, profile]) {
        expect(rect.width, greaterThan(40), reason: 'room for the title');
        expect(rect.right, lessThanOrEqualTo(400));
      }
      expect(phoneSave(), findsNothing, reason: 'not in the bar');
      expect(wideSave(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    pageTest('Android keeps the title and the profile name in the bar', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pump(tester);
      expect(
        tester.getRect(find.text('Personality').first).width,
        greaterThan(40),
      );
      expect(
        tester.getRect(find.text(soulProfile).first).width,
        greaterThan(40),
      );
      expect(phoneSave(), findsOneWidget);
    });
  });

  group('binding', () {
    pageTest('a switch of the chat profile behind it changes nothing', (
      tester,
    ) async {
      await pump(tester);
      chatProfiles.showing('other');
      await tester.pumpAndSettle();
      expect(find.text(soulProfile), findsWidgets);
      expect(find.text('other'), findsNothing);
      await type(tester, 'You are Mara.');
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      expect(
        find.text('Replace the personality of $soulProfile?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(puts, ['You are Mara.']);
      expect(
        server.requests.every((r) => r.path == soulPath),
        isTrue,
        reason: 'every request names the profile the page was opened for',
      );
    });

    pageTest('the path carries the name it was opened with', (tester) async {
      server.on('GET', '/api/profiles/other-one/soul', soulWithText);
      await pump(tester, profile: 'other-one');
      expect(server.requests.single.path, '/api/profiles/other-one/soul');
      expect(server.requests.single.queryParameters, isEmpty);
    });
  });

  group('the connection ends', () {
    pageTest('closes the page with its text and sends nothing more', (
      tester,
    ) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      await pump(tester, auth: auth);
      await type(tester, 'You are Mara.');
      final before = server.requests.length;
      auth.endConnection();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('You are Mara.'), findsNothing);
      expect(editor(), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(server.requests.length, before);
      expect(tester.takeException(), isNull);
    });

    pageTest('an expiry that is rescued keeps the text and the editor', (
      tester,
    ) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      await pump(tester, auth: auth);
      await type(tester, 'You are Mara.');
      final before = server.requests.length;

      auth.pauseRequests();
      await tester.pump();
      await tester.pumpAndSettle();
      // Held: the text stays, read-only, no spinner, nothing sent.
      expect(find.text('You are Mara.'), findsOneWidget);
      expect(find.text('Loading personality…'), findsNothing);
      expect(tester.widget<TextField>(editor()).readOnly, isTrue);
      expect(tester.widget<TextButton>(phoneSave()).onPressed, isNull);
      expect(find.text('open'), findsNothing);
      expect(server.requests.length, before);

      auth.restoreRequests();
      await tester.pumpAndSettle();
      expect(find.text('You are Mara.'), findsOneWidget);
      expect(find.text('Loading personality…'), findsNothing);
      expect(tester.widget<TextField>(editor()).readOnly, isFalse);
      // Same text, same baseline: still unsaved, and Save asks as ever.
      expect(tester.widget<TextButton>(phoneSave()).onPressed, isNotNull);
      expect(server.requests.length, before, reason: 'nothing read or sent');
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      expect(
        find.text('Replace the personality of $soulProfile?'),
        findsOneWidget,
      );
      expect(puts, isEmpty);
    });

    pageTest('an expiry that is not rescued clears the text at once', (
      tester,
    ) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      await pump(tester, auth: auth);
      await type(tester, 'You are Mara.');
      auth.pauseRequests();
      await tester.pump();
      expect(find.text('You are Mara.'), findsOneWidget);

      auth.endConnection();
      // One frame, before the app has removed the page: the text is gone.
      await tester.pump();
      expect(find.text('You are Mara.'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    pageTest('a real end drops the text at once, before the page goes', (
      tester,
    ) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      // No closer: only the page's own reaction is looked at.
      await pump(tester, auth: auth, withCloser: false);
      await type(tester, 'You are Mara.');
      auth.endConnection();
      await tester.pump();
      expect(find.text('You are Mara.'), findsNothing);
      expect(editor(), findsNothing);
      expect(find.text('Loading personality…'), findsOneWidget);
      expect(find.text('open'), findsNothing, reason: 'the page is still up');
      expect(tester.takeException(), isNull);
    });

    pageTest('an open question goes with a pause and nothing is sent', (
      tester,
    ) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      await pump(tester, auth: auth);
      await type(tester, 'You are Mara.');
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      auth.pauseRequests();
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsNothing);
      expect(puts, isEmpty);
      auth.restoreRequests();
      await tester.pumpAndSettle();
      expect(find.text('You are Mara.'), findsOneWidget);
      expect(puts, isEmpty);
    });

    pageTest('an open question goes with it and nothing is sent', (
      tester,
    ) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      await pump(tester, auth: auth);
      await type(tester, 'You are Mara.');
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsOneWidget);
      auth.endConnection();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(puts, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('App Lock', () {
    pageTest('covering drops the text at once and unlocking reads again', (
      tester,
    ) async {
      await tester.runAsync(lock.load);
      await pump(tester, withLock: true);
      await type(tester, 'You are Mara.');
      await tester.runAsync(() => lock.setEnabled(true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(lock.covered, isTrue);
      expect(find.text('You are Mara.'), findsNothing);
      expect(editor(), findsNothing);
      expect(gets(), 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(lock.unlock);
      await tester.pumpAndSettle();
      expect(gets(), 2);
      expect(find.text('You are Quill.'), findsOneWidget);
      expect(find.text('You are Mara.'), findsNothing);
      expect(puts, isEmpty);
    });

    pageTest('the changed-on-server sheet is blank while the app is inactive', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'You are Mara.');
      fileText = 'Someone else wrote this.';
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Show server's version"));
      await tester.pumpAndSettle();
      expect(find.text('Someone else wrote this.'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      // The sheet's own surface (the last one: the page's is below it) holds
      // its content unpainted, unhittable and out of the semantics tree.
      final sheet = find.byType(PrivateSurface).last;
      Visibility shown() => tester.widget<Visibility>(
        find.descendant(of: sheet, matching: find.byType(Visibility)).first,
      );
      expect(shown().visible, isFalse);
      expect(
        find.descendant(of: sheet, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
        reason: 'the blank stands in with its lock',
      );
      expect(tester.takeException(), isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(shown().visible, isTrue);
      expect(find.text('Someone else wrote this.'), findsOneWidget);
    });

    pageTest('an open question closes when the lock covers', (tester) async {
      await tester.runAsync(lock.load);
      await pump(tester, withLock: true);
      await type(tester, 'You are Mara.');
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsOneWidget);
      await tester.runAsync(() => lock.setEnabled(true));
      // Inactive covers on a phone and frames still run, so the question
      // leaves the tree.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // The covered page shows a spinner, so it never settles.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Replace'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(puts, isEmpty);
    });

    pageTest('a phone shows a blank surface while the app is inactive', (
      tester,
    ) async {
      await pump(tester, platform: TargetPlatform.android);
      final semantics = tester.ensureSemantics();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('You are Quill.').hitTestable(), findsNothing);
      expect(find.byType(Offstage), findsWidgets);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('You are Quill.').hitTestable(), findsOneWidget);
      semantics.dispose();
    });
  });

  group('on a Mac', () {
    late MacCommandRegistry commands;

    setUp(() => commands = MacCommandRegistry());
    tearDown(() => commands.dispose());

    bool saveEnabled() =>
        commands.handlerFor(MacCommand.save)?.enabled ?? false;

    pageTest('File > Save is offered, enabled only while dirty and idle', (
      tester,
    ) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      expect(commands.handlerFor(MacCommand.save), isNotNull);
      expect(saveEnabled(), isFalse);

      await type(tester, 'You are Mara.');
      await tester.pump();
      expect(saveEnabled(), isTrue);

      // Back to the loaded text: clean again.
      await type(tester, 'You are Quill.');
      await tester.pump();
      expect(saveEnabled(), isFalse);

      await type(tester, 'You are Mara.');
      final put = Completer<FakeResponse>();
      server.onRequest('PUT', soulPath, (_) => put.future);
      commands.invoke(MacCommand.save);
      await tester.pumpAndSettle();
      // The command opens the question and sends nothing.
      expect(
        find.text('Replace the personality of $soulProfile?'),
        findsOneWidget,
      );
      expect(puts, isEmpty);
      expect(saveEnabled(), isFalse);
      await tester.tap(find.text('Replace'));
      await tester.pump();
      await tester.pump();
      // Running: not offered.
      expect(saveEnabled(), isFalse);
      put.complete((status: 200, body: soulSaved));
      await tester.pumpAndSettle();
      expect(find.text('Saved. New chats use it.'), findsOneWidget);
      expect(saveEnabled(), isFalse);
    });

    pageTest('leaving the page takes File > Save away', (tester) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      expect(commands.handlerFor(MacCommand.save), isNotNull);
      await tester.tap(find.byKey(const Key('settings-back')));
      await tester.pumpAndSettle();
      expect(commands.handlerFor(MacCommand.save), isNull);
    });

    pageTest('Back from the toolbar asks while dirty, as on a phone', (
      tester,
    ) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      await type(tester, 'You are Mara.');
      await tester.tap(find.byKey(const Key('settings-back')));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('You are Mara.'), findsOneWidget);
    });

    pageTest('File > Close Window asks while dirty and not otherwise', (
      tester,
    ) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      // Clean: the page offers nothing, the window closes as it always does.
      expect(commands.handlerFor(MacCommand.closeWindow), isNull);
      await type(tester, 'You are Mara.');
      await tester.pump();
      expect(commands.handlerFor(MacCommand.closeWindow), isNotNull);
      commands.invoke(MacCommand.closeWindow);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('You are Mara.'), findsOneWidget);
    });

    pageTest('File > Close Window twice asks one question, not two', (
      tester,
    ) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      await type(tester, 'You are Mara.');
      commands
        ..invoke(MacCommand.closeWindow)
        ..invoke(MacCommand.closeWindow);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      // While it is open the page offers neither command.
      expect(commands.handlerFor(MacCommand.closeWindow), isNull);
      expect(saveEnabled(), isFalse);
      commands
        ..invoke(MacCommand.closeWindow)
        ..invoke(MacCommand.save);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Replace'), findsNothing);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      // Back in front: offered again.
      expect(commands.handlerFor(MacCommand.closeWindow), isNotNull);
      expect(saveEnabled(), isTrue);
    });

    pageTest('File > Save over the Replace question opens nothing on top', (
      tester,
    ) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      await type(tester, 'You are Mara.');
      commands
        ..invoke(MacCommand.save)
        ..invoke(MacCommand.save);
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsOneWidget);
      commands.invoke(MacCommand.save);
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saveEnabled(), isTrue);
      expect(puts, isEmpty);
    });

    pageTest('Discard on Close Window drops the text even while a save runs', (
      tester,
    ) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      await type(tester, 'You are Mara.');
      final put = Completer<FakeResponse>();
      var sent = false;
      server.onRequest('PUT', soulPath, (_) {
        sent = true;
        return put.future;
      });
      commands.invoke(MacCommand.save);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      for (var i = 0; i < 20 && !sent; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(sent, isTrue, reason: 'the write is on its way');
      expect(tester.widget<TextField>(editor()).readOnly, isTrue);

      // The write is open: only short frames, so no deadline runs out.
      commands.invoke(MacCommand.closeWindow);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Discard'));
      await tester.pump(const Duration(milliseconds: 400));
      // The hidden window holds no text: the editor is gone.
      expect(find.text('You are Mara.'), findsNothing);
      expect(editor(), findsNothing);

      put.complete((status: 200, body: soulSaved));
      await tester.pumpAndSettle();
      // The file is read again for when the window comes back: the first
      // read, the check before the write, and this one.
      expect(find.text('Loading personality…'), findsNothing);
      expect(gets(), 3);
      expect(find.text('You are Quill.'), findsOneWidget);
    });

    pageTest('Discard on Close Window with no save running reads the file', (
      tester,
    ) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      await type(tester, 'You are Mara.');
      commands.invoke(MacCommand.closeWindow);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('You are Mara.'), findsNothing);
      expect(find.text('You are Quill.'), findsOneWidget);
      expect(puts, isEmpty);
    });

    pageTest('the toolbar has no Save: Save and Revert sit under the editor', (
      tester,
    ) async {
      await pump(
        tester,
        platform: TargetPlatform.macOS,
        width: 1100,
        commands: commands,
      );
      expect(wideSave(), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Revert'), findsOneWidget);
    });
  });

  group('privacy', () {
    const markerText = 'MARKER-TEXT-hunter2';
    const markerProfile = 'marker-profile';
    const markerPath = '/api/profiles/$markerProfile/soul';

    pageTest('neither the text nor the profile name reaches telemetry', (
      tester,
    ) async {
      server
        ..on('GET', markerPath, {'content': 'old', 'exists': true})
        ..on('PUT', markerPath, soulSaved);
      await pump(
        tester,
        profile: markerProfile,
        from: SoulOpenedFrom.profilesPage,
      );
      await type(tester, markerText);
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.text('Saved. New chats use it.'), findsOneWidget);

      final recorded = [
        for (final span in tracer.spans) ...[
          span.name,
          ...span.attributes.keys,
          ...span.attributes.values.map((v) => '$v'),
          ...span.events,
          ...span.eventDetails,
          '${span.statusDescription}',
        ],
        for (final name in events.namesStartingWith('')) ...[
          name,
          ...events
              .named(name)
              .expand((a) => [...a.keys, ...a.values.map((v) => '$v')]),
        ],
        for (final crumb in trail.recent) ...[
          crumb.name,
          ...crumb.attributes.keys,
          ...crumb.attributes.values.map((v) => '$v'),
        ],
      ].join('\n');
      expect(recorded, contains('profile_soul.save'));
      expect(recorded, isNot(contains(markerText)));
      expect(recorded, isNot(contains('MARKER')));
      expect(recorded, isNot(contains(markerProfile)));
    });
  });
}
