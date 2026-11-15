import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/session_export_alert.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_device_authenticator.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_media_actions.dart';
import 'support/fake_session_auth.dart';
import 'support/pump_chat.dart';

final _body = Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'id': 's1',
      'messages': [
        {'role': 'user', 'content': 'hi'},
      ],
    }),
  ),
);

/// "Export chat as JSON" as the chat screen offers it: the Chat menu command,
/// the header menu, the sidebar row menu, and the controller's owner and
/// lifecycle.
void main() {
  late FakeHermesServer server;
  late MacCommandRegistry commands;
  late FakeMediaActions actions;
  late FakeSessionAuth auth;
  late AppLockController lock;
  late Directory cache;
  Completer<FakeResponse>? held;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    held = null;
    commands = MacCommandRegistry();
    actions = FakeMediaActions();
    auth = FakeSessionAuth();
    cache = Directory.systemTemp.createTempSync('export-screen-');
    addTearDown(() {
      auth.dispose();
      cache.deleteSync(recursive: true);
    });
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', displayName: 'Personal', isDefault: true),
          profileRow(name: 'work', displayName: 'Work'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [messageRow(id: 1, role: 'user', content: 'hi')]),
      )
      ..onRequest('GET', '/api/sessions/s1/export', (_) async {
        final gate = held;
        return gate == null ? (status: 200, body: _body) : await gate.future;
      });
  });

  /// Frames instead of pumpAndSettle: with the repositories provided something
  /// on the screen (a loading indicator) keeps animating.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> pump(WidgetTester tester, {bool signedIn = true}) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    addTearDown(lock.dispose);
    await tester.runAsync(lock.load);
    await tester.runAsync(() => lock.setEnabled(true));
    final chatProfiles = ChatProfiles(
      HermesProfilesRepository(server.client().raw),
    );
    addTearDown(chatProfiles.dispose);
    final store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: actions,
    );
    addTearDown(store.dispose);
    await pumpChatScreen(
      tester,
      settle: false,
      server: server,
      withProfiles: true,
      chatProfiles: chatProfiles,
      transport: FakeChatTransport(),
      commands: commands,
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<AppLockController>.value(value: lock),
        if (signedIn)
          Provider<HermesRepositories?>.value(
            value: HermesRepositories(server.client()),
          ),
        Provider<MediaStore?>.value(value: store),
      ],
    );
    await frames(tester);
    await frames(tester);
  }

  bool enabled() =>
      commands.handlerFor(MacCommand.exportThread)?.enabled ?? false;

  testWidgets('is offered but disabled until a chat is open', (tester) async {
    await pump(tester);

    expect(commands.handlerFor(MacCommand.exportThread), isNotNull);
    expect(enabled(), isFalse);

    await openThread(tester, 'Run failure');
    expect(enabled(), isTrue);
  });

  testWidgets('is disabled where the screen has no API client', (tester) async {
    await pump(tester, signedIn: false);
    await openThread(tester, 'Run failure');

    expect(commands.handlerFor(MacCommand.exportThread), isNotNull);
    expect(enabled(), isFalse);
  });

  testWidgets('asks, fetches with the chat profile and saves as .json', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Run failure');

    expect(commands.invoke(MacCommand.exportThread), isTrue);
    await frames(tester);
    expect(find.text('Export this chat as JSON?'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await frames(tester);

    final request = server.requests.singleWhere(
      (r) => r.path == '/api/sessions/s1/export',
    );
    expect(request.queryParameters['profile'], 'default');
    expect(actions.saved.single.name, 'Run failure.json');
    expect(actions.saved.single.bytes, _body);
    expect(find.text('Chat saved'), findsOneWidget);
  });

  testWidgets('a cancelled save sheet shows no snack bar', (tester) async {
    actions.saves = false;
    await pump(tester);
    await openThread(tester, 'Run failure');

    commands.invoke(MacCommand.exportThread);
    await frames(tester);
    await tester.tap(find.text('Export'));
    await frames(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(SessionExportAlert), findsNothing);
  });

  testWidgets('is disabled while an export runs, enabled after', (
    tester,
  ) async {
    held = Completer<FakeResponse>();
    await pump(tester);
    await openThread(tester, 'Run failure');
    commands.invoke(MacCommand.exportThread);
    await frames(tester);
    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump();

    expect(enabled(), isFalse);
    expect(commands.invoke(MacCommand.exportThread), isFalse);

    held!.complete((status: 200, body: _body));
    await frames(tester);
    expect(enabled(), isTrue);
  });

  testWidgets('App Lock closes the alert and nothing shows after unlock', (
    tester,
  ) async {
    held = Completer<FakeResponse>();
    await pump(tester);
    await openThread(tester, 'Run failure');
    commands.invoke(MacCommand.exportThread);
    await frames(tester);
    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump();

    lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await frames(tester);
    expect(find.byType(SessionExportAlert), findsNothing);

    held!.complete((status: 200, body: _body));
    await tester.runAsync(lock.unlock);
    await frames(tester);
    expect(find.byType(SessionExportAlert), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(actions.saved, isEmpty);
  });

  testWidgets('a sign-out closes the alert and saves nothing', (tester) async {
    held = Completer<FakeResponse>();
    await pump(tester);
    await openThread(tester, 'Run failure');
    commands.invoke(MacCommand.exportThread);
    await frames(tester);
    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump();

    auth.depart();
    await frames(tester);
    expect(find.byType(SessionExportAlert), findsNothing);

    held!.complete((status: 200, body: _body));
    await frames(tester);
    expect(actions.saved, isEmpty);
  });
  testWidgets('the header menu offers it after Copy transcript', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Run failure');

    await tester.tap(find.byKey(const Key('header-thread-actions')));
    await frames(tester);
    final copy = tester.getTopLeft(find.text('Copy transcript')).dy;
    final export = tester.getTopLeft(find.text('Export chat as JSON…')).dy;
    expect(export, greaterThan(copy));

    await tester.tap(find.text('Export chat as JSON…'));
    await frames(tester);
    expect(find.text('Export this chat as JSON?'), findsOneWidget);
  });

  testWidgets('the sidebar row menu off the Mac does not', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Chat actions').first);
    await frames(tester);

    expect(find.text('Archive'), findsOneWidget);
    expect(find.textContaining('Export'), findsNothing);
  });
}
