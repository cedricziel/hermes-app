import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_broker.dart';
import 'package:hermes_app/src/chat/widgets/session_export_alert.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_window_screen.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:hermes_app/src/windows/conversation_windows_menu.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_conversation_window_host.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_media_actions.dart';

class _Link
    implements ConversationWindowLink, QueueWindowLink, ExportBusyWindowLink {
  // Closed in the tests' tear-down.
  // ignore: close_sinks
  final visibility = StreamController<bool>.broadcast(sync: true);
  final busyReports = <bool>[];

  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async =>
      const {};
  @override
  Stream<String> get commands => const Stream.empty();
  @override
  Stream<bool> get keyChanges => const Stream.empty();
  @override
  Stream<bool> get queueVisibility => visibility.stream;
  @override
  Future<Map<String, Object?>> queueOperation(
    String operation,
    Map<String, Object?> arguments,
  ) async => const {};
  @override
  void reportExportBusy(bool busy) => busyReports.add(busy);
  @override
  void reportFocus(bool focused) {}
  @override
  void reportThread(String title, {required bool pinned}) {}
  @override
  Future<void> showInMain(String threadId, String? profile) async {}
  @override
  Future<void> showMain() async {}
  @override
  Future<void> present({
    required String frameName,
    required String title,
  }) async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> share(String text, Rect anchor) async {}
}

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

void main() {
  late FakeHermesServer server;
  late _Link link;
  late FakeMediaActions actions;
  Completer<FakeResponse>? held;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    held = null;
    link = _Link();
    actions = FakeMediaActions();
    addTearDown(link.visibility.close);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Trip plan')]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Where?'),
        ]),
      )
      ..onRequest('GET', '/api/sessions/s1/export', (_) async {
        final gate = held;
        return gate == null ? (status: 200, body: _body) : await gate.future;
      });
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pump(WidgetTester tester, {String? profile = 'work'}) async {
    tester.view
      ..physicalSize = const Size(900, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => throw UnimplementedError(),
      actions: actions,
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      Provider<MediaStore?>.value(
        value: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: ConversationWindowScreen(
            args: ConversationWindowArgs(
              threadId: 's1',
              profile: profile,
              title: 'Trip plan',
              baseUrl: 'https://hermes.test',
              authRequired: true,
            ),
            link: link,
            chat: HermesChatRepository(server.client().raw),
            transport: FakeChatTransport(),
            api: server.client(),
          ),
        ),
      ),
    );
    await frames(tester);
  }

  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More'));
    await frames(tester);
  }

  testWidgets('the … menu has the row and it starts an export', (tester) async {
    await pump(tester);
    await openMore(tester);
    await tester.tap(find.text('Export Chat as JSON…'));
    await frames(tester);

    expect(find.text('Export this chat as JSON?'), findsOneWidget);
    await tester.tap(find.text('Export'));
    await frames(tester);
    expect(actions.saved.single.name, 'Trip plan.json');
  });

  testWidgets('the row is absent without a profile', (tester) async {
    await pump(tester, profile: null);
    await openMore(tester);

    expect(find.text('Copy Transcript'), findsOneWidget);
    expect(find.text('Export Chat as JSON…'), findsNothing);
  });

  testWidgets('the row is disabled and the main window told while it runs', (
    tester,
  ) async {
    held = Completer<FakeResponse>();
    await pump(tester);
    await openMore(tester);
    await tester.tap(find.text('Export Chat as JSON…'));
    await frames(tester);
    await tester.tap(find.text('Export'));
    await frames(tester);
    expect(link.busyReports, [true]);

    await tester.tap(find.text('Cancel'));
    await frames(tester);
    expect(link.busyReports, [true, false]);

    held!.complete((status: 200, body: _body));
    await frames(tester);
    expect(actions.saved, isEmpty);
  });

  testWidgets('the lock signal closes the alert mid-progress', (tester) async {
    held = Completer<FakeResponse>();
    await pump(tester);
    await openMore(tester);
    await tester.tap(find.text('Export Chat as JSON…'));
    await frames(tester);
    await tester.tap(find.text('Export'));
    await frames(tester);
    expect(find.text('Preparing the export…'), findsOneWidget);

    link.visibility.add(false);
    await frames(tester);
    expect(find.byType(SessionExportAlert), findsNothing);

    held!.complete((status: 200, body: _body));
    await frames(tester);
    expect(actions.saved, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  group('the menu bar item', () {
    testWidgets('is disabled while the key window exports', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final registry = MacCommandRegistry();
      final host = FakeConversationWindowHost();
      final windows = ConversationWindows(
        host: host,
        store: ConversationWindowStore(SharedPreferencesAsync()),
        ownerKey: () => 'test-owner',
        connection: () => (baseUrl: 'https://hermes.test', authRequired: true),
        headers: ({rejected}) async => const {},
      );
      addTearDown(() {
        windows.dispose();
        host.dispose();
        registry.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<ConversationWindows?>.value(
          value: windows,
          child: MacCommandScope.root(
            registry: registry,
            child: const ConversationWindowsMenu(child: SizedBox()),
          ),
        ),
      );
      await windows.open('s1', profile: 'work', title: 'A');
      await host.call('focused', {'window_id': 'w0', 'focused': true});
      await tester.pump();
      expect(registry.handlerFor(MacCommand.exportThread)!.enabled, isTrue);

      await host.call('exportBusy', {'window_id': 'w0', 'busy': true});
      await tester.pump();
      expect(registry.handlerFor(MacCommand.exportThread)!.enabled, isFalse);

      // A later title report of the same window keeps the flag.
      await host.call('title', {
        'window_id': 'w0',
        'title': 'A new title',
        'pinned': true,
      });
      await tester.pump();
      expect(registry.handlerFor(MacCommand.exportThread)!.enabled, isFalse);

      await host.call('exportBusy', {'window_id': 'w0', 'busy': false});
      await tester.pump();
      expect(registry.handlerFor(MacCommand.exportThread)!.enabled, isTrue);
    });
  });
}
