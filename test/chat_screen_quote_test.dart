import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_device_authenticator.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart';

/// Text selected in another app arrives through the Services menu as a quote:
/// a new chat whose composer holds it, never sent.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late BreadcrumbTrail trail;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail(capacity: 50);
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'recent', title: 'Recent chat')]),
      );
  });

  Widget screen() => ChatScreen(
    repository: HermesChatRepository(server.client().raw),
    transport: transport,
  );

  Future<void> pump(
    WidgetTester tester,
    ShareController share, {
    bool locked = false,
    List<SingleChildWidget> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>.value(value: share),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          ...extra,
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          builder: locked
              ? (context, child) => AppLockGate(child: child!)
              : null,
          home: screen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(composerField).controller.text;

  Finder sidebarRow(String title) => find.descendant(
    of: find.byType(ThreadSidebar),
    matching: find.text(title),
  );

  /// "New chat" is also the sidebar's button, so a new chat is a second one.
  Finder newChatRows() => sidebarRow('New chat');

  Future<ShareController> sharing(FakeShareInbox inbox) async {
    final share = ShareController(inbox);
    await share.start();
    return share;
  }

  testWidgets('a quote held at launch opens a new chat with the selection', (
    tester,
  ) async {
    final share = await sharing(
      FakeShareInbox([const SharedQuote('line one\nline two')]),
    );

    await pump(tester, share);

    expect(composerText(tester), '> line one\n> line two\n\n');
    expect(newChatRows(), findsNWidgets(2));
    expect(transport.sends, isEmpty);
    final field = tester.widget<EditableText>(composerField);
    expect(
      field.controller.selection,
      const TextSelection.collapsed(offset: 23),
    );
    expect(field.focusNode.hasFocus, isTrue);
  });

  testWidgets('a quote delivered while the chat is open does the same', (
    tester,
  ) async {
    final inbox = FakeShareInbox();
    final share = await sharing(inbox);
    await pump(tester, share);
    await tester.tap(sidebarRow('Recent chat'));
    await tester.pumpAndSettle();
    expect(newChatRows(), findsOneWidget);

    inbox.emit([const SharedQuote('a question')]);
    await tester.pumpAndSettle();

    expect(composerText(tester), '> a question\n\n');
    expect(newChatRows(), findsNWidgets(2));
    expect(transport.sends, isEmpty);
  });

  testWidgets('a draft stays above the quote', (tester) async {
    final inbox = FakeShareInbox();
    final share = await sharing(inbox);
    await pump(tester, share);
    await tester.enterText(composerField, 'Summarize:');

    inbox.emit([const SharedQuote('the text')]);
    await tester.pumpAndSettle();

    expect(composerText(tester), 'Summarize:\n\n> the text\n\n');
  });

  testWidgets('blank lines inside a quote keep the quote marker', (
    tester,
  ) async {
    final share = await sharing(
      FakeShareInbox([const SharedQuote('one\n\ntwo')]),
    );

    await pump(tester, share);

    expect(composerText(tester), '> one\n>\n> two\n\n');
  });

  testWidgets('a shortened selection ends with a line saying so', (
    tester,
  ) async {
    final share = await sharing(
      FakeShareInbox([const SharedQuote('first part', truncated: true)]),
    );

    await pump(tester, share);

    expect(composerText(tester), '> first part\n> [selection shortened]\n\n');
  });

  testWidgets('plain shares in the same batch are still added', (tester) async {
    final share = await sharing(
      FakeShareInbox([
        const SharedText('https://example.com'),
        const SharedQuote('quoted'),
      ]),
    );

    await pump(tester, share);

    expect(composerText(tester), contains('https://example.com'));
    expect(composerText(tester), contains('> quoted'));
  });

  testWidgets('a quote held under app lock shows after unlock', (tester) async {
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
    final share = await sharing(
      FakeShareInbox([const SharedQuote('private words')]),
    );

    await pump(
      tester,
      share,
      locked: true,
      extra: [ChangeNotifierProvider<AppLockController>.value(value: lock)],
    );
    expect(lock.locked, isTrue);
    expect(find.text('Hermes is locked'), findsOneWidget);

    device.succeeds = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(composerText(tester), '> private words\n\n');
    expect(newChatRows(), findsNWidgets(2));
  });

  testWidgets('records that the chat opened, held or not, without text', (
    tester,
  ) async {
    final inbox = FakeShareInbox([const SharedQuote('secret words')]);
    final share = await sharing(inbox);
    await pump(tester, share);
    inbox.emit([const SharedQuote('more secret words')]);
    await tester.pumpAndSettle();

    final crumbs = trail.recent.where((c) => c.name == 'chat.share.quote');
    expect(
      [for (final c in crumbs) c.attributes],
      [
        {'held': true},
        {'held': false},
      ],
    );
    for (final crumb in trail.recent) {
      expect(crumb.toString(), isNot(contains('secret')));
    }
  });
}
