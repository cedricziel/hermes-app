import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/drag_out/drag_out_item.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_drag_out_source.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

/// A sidebar row in the Mac sidebar drags out as `<title>.md`.
void main() {
  late FakeHermesServer server;
  late FakeDragOutSource source;
  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  const total = 250;

  String line(int id) => 'line-${id.toString().padLeft(3, '0')}';

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    source = FakeDragOutSource();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Long chat', lastActive: now - 60),
          sessionRow(id: 's2', title: 'Broken chat', lastActive: now - 120),
        ]),
      )
      ..onRequest('GET', '/api/sessions/s1/messages', (request) {
        final limit = request.queryParameters['limit'] as int;
        final offset = request.queryParameters['offset'] as int;
        final newest = total - offset;
        final oldest = newest - limit + 1 < 1 ? 1 : newest - limit + 1;
        return (
          status: 200,
          body: messageListBody('s1', [
            for (var id = oldest; id <= newest; id++)
              messageRow(id: id, role: 'user', content: line(id)),
          ]),
        );
      })
      ..on('GET', '/api/sessions/s2/messages', {'detail': 'boom'}, status: 500);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          Provider<DragOutSource?>.value(value: source),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: MacSidebarScope(
            child: ChatScreen(
              repository: HermesChatRepository(server.client().raw),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  DragOutFile? exported(String title) {
    for (final wrap in source.wraps.reversed) {
      if (wrap.kind != DragOutKind.thread) continue;
      final item = wrap.item();
      if (item is DragOutFile && item.name == '$title.md') return item;
    }
    return null;
  }

  testWidgets('a thread row is a thread drag source', (tester) async {
    await pump(tester);

    expect(exported('Broken chat'), isNotNull);
    expect(exported('Long chat'), isNotNull);
  });

  testWidgets('the file holds the heading and every page, loaded or not', (
    tester,
  ) async {
    await pump(tester);
    final file = exported('Long chat')!;
    final before = server.requestsTo('GET', '/api/sessions/s1/messages').length;

    final text = await tester.runAsync(
      () async => utf8.decode(await file.read()),
    );

    expect(before, 0, reason: 'nothing is read before the drop');
    expect(
      server.requestsTo('GET', '/api/sessions/s1/messages'),
      hasLength(3),
      reason: '250 rows are three pages of 100',
    );
    final expected = StringBuffer('# Long chat\n\n')
      ..write(
        [for (var id = 1; id <= total; id++) '## You\n\n${line(id)}']
            .join('\n\n'),
      );
    expect(text, expected.toString());
  });

  testWidgets('a history that cannot be read produces no file', (tester) async {
    await pump(tester);
    final file = exported('Broken chat')!;

    final error = await tester.runAsync(() async {
      try {
        await file.read();
        return null;
      } on Object catch (e) {
        return e;
      }
    });

    expect(error, isNotNull);
    expect(file.failure, DragOutFailure.history);
  });
}
