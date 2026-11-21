import 'package:dio/dio.dart' show SyncTransformer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_open_requests.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../test/support/fake_chat_transport.dart';
import '../../test/support/fake_hermes_server.dart';
import '../../test/support/fake_share_inbox.dart';
import '../../test/support/pump_chat.dart' show composerField;
import '../../test/support/test_localizations.dart';
import '../../test/support/screenshot_recorder.dart'
    show desktopSize, phoneSize, withScreenshotFont;
import 'fonts.dart';
import 'frame_stats.dart';

export '../../test/support/fake_chat_transport.dart';
export '../../test/support/fake_hermes_server.dart' show sessionRow;
export '../../test/support/pump_chat.dart' show composerField;

/// The two window sizes every scenario runs at.
const widths = <(String, Size)>[('phone', phoneSize), ('desktop', desktopSize)];

const threadId = 'bench-thread';

Future<void>? _fonts;

ThemeData _theme(TargetPlatform? platform) {
  final theme = buildHermesLightTheme(platform: platform);
  return profileMode ? theme : withScreenshotFont(theme);
}

/// A chat screen over a fake dashboard and a fake gateway, the way
/// `pumpChatScreen` mounts one, plus what a benchmark needs: a stored chat of
/// any length served in pages, an optional long chat list and the Mac sidebar.
class BenchChat {
  BenchChat(this.tester, this.server, this.transport);

  final WidgetTester tester;
  final FakeHermesServer server;
  final FakeChatTransport transport;

  FakeSend get send => transport.sends.last;

  /// The composer's text, set on its controller. `tester.enterText` goes
  /// through the test text-input channel, which a real app window under
  /// `flutter drive` does not have; this works the same in both modes.
  Composer get composer => Composer(tester);

  /// Types [text] into the composer and sends it. The fake transport then
  /// holds the reply stream, which [send] feeds.
  Future<void> submit(String text) async {
    composer.setText(text);
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    // On a real clock the send starts a few frames later.
    for (var i = 0; i < 50 && transport.sends.isEmpty; i++) {
      await tester.pump(frameStep);
    }
    if (transport.sends.isEmpty) throw StateError('the prompt was not sent');
  }
}

class Composer {
  Composer(this._tester);
  final WidgetTester _tester;
  late final TextEditingController _controller = _tester
      .widget<EditableText>(composerField)
      .controller;

  void setText(String text) => _controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}

/// Mounts the screen at [size] and opens [history] (oldest first) as the
/// stored chat [threadId]. With [settle] false it returns right after the
/// first frame, so a scenario can time the open itself; give it a [mountLog]
/// and that first frame (the mount) is the first one measured in it.
Future<BenchChat> openBenchChat(
  WidgetTester tester, {
  required Size size,
  List<Map<String, Object?>> history = const [],
  List<Map<String, Object?>> chats = const [],
  bool macSidebar = false,
  bool settle = true,
  FrameLog? mountLog,
}) async {
  // Profile mode runs in a real window with the system's fonts.
  if (!profileMode) {
    await tester.runAsync(() => _fonts ??= loadBenchmarkFonts());
  }
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = FakeHermesServer();
  final transport = FakeChatTransport();
  final all = [
    sessionRow(
      id: threadId,
      title: 'Benchmark chat',
      lastActive: 1780100000,
      messageCount: history.length,
    ),
    ...chats,
  ];
  server
    ..on(
      'GET',
      '/api/sessions',
      sessionListBody(all, total: all.length, limit: all.length + 1),
      query: const {'offset': '0'},
    )
    ..on('GET', '/api/sessions', sessionListBody(const [], total: all.length))
    ..on(
      'GET',
      '/api/sessions/$threadId',
      sessionDetailRow(id: threadId, title: 'Benchmark chat'),
    )
    ..onRequest('GET', '/api/sessions/$threadId/messages', (request) {
      final limit = request.queryParameters['limit'] as int;
      final offset = request.queryParameters['offset'] as int;
      final end = (history.length - offset).clamp(0, history.length);
      final start = (end - limit).clamp(0, history.length);
      return (
        status: 200,
        body: messageListBody(threadId, history.sublist(start, end)),
      );
    });

  // Dio decodes a large body in a background isolate, which a widget test's
  // fake clock never waits for; decode on the spot, as every test does.
  final api = HermesApiClient(server.dio()..transformer = SyncTransformer())
      .raw;

  final requests = ChatOpenRequests()
    ..request(const NotificationTarget(threadId: threadId));
  addTearDown(requests.dispose);

  Widget app = MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<ShareController>(
        create: (_) => ShareController(FakeShareInbox()),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _theme(macSidebar ? TargetPlatform.macOS : null),
      home: ChatScreen(
        repository: HermesChatRepository(api),
        transport: transport,
        openRequests: requests,
      ),
    ),
  );
  if (macSidebar) app = MacSidebarScope(child: app);
  if (mountLog != null) {
    await mountLog.frame(tester, before: () => tester.pumpWidget(app));
  } else {
    await tester.pumpWidget(app);
  }
  if (settle) {
    // The Mac window never goes idle (its toolbar keeps a frame scheduled).
    if (macSidebar) {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } else {
      await tester.pumpAndSettle();
    }
    // On a phone the open request leaves the chat list showing.
    if (composerField.evaluate().isEmpty) {
      await tester.tap(find.text('Benchmark chat'));
      await tester.pumpAndSettle();
    }
  }
  return BenchChat(tester, server, transport);
}

/// Feeds [events] to the open reply, [perFrame] events per frame, one measured
/// frame after each batch. The first [warmup] frames are not recorded.
Future<void> streamEvents(
  BenchChat chat,
  FrameLog log,
  List<ChatEvent> events, {
  int perFrame = 3,
  int warmup = 10,
  Future<void> Function(int frame)? alsoEachFrame,
}) async {
  final send = chat.send;
  var frame = 0;
  for (var i = 0; i < events.length; i += perFrame) {
    final batch = events.sublist(i, (i + perFrame).clamp(0, events.length));
    Future<void> before() async {
      batch.forEach(send.emit);
      if (alsoEachFrame != null) await alsoEachFrame(frame);
    }

    if (frame < warmup) {
      await log.warm(chat.tester, before: before);
    } else {
      await log.frame(chat.tester, before: before);
    }
    frame++;
  }
}
