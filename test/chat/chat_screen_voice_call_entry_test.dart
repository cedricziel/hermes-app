import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/voice/voice_call_screen.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/memory_token_store.dart';
import '../support/pump_chat.dart';

class _Recorder extends RecordPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
  @override
  Future<void> create(String recorderId) async {}
  @override
  Future<void> dispose(String recorderId) async {}
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
}) async {
  final previous = RecordPlatform.instance;
  RecordPlatform.instance = _Recorder();
  addTearDown(() => RecordPlatform.instance = previous);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final auth = AuthController(
    tokenStore: MemoryTokenStore(),
    interceptors: [
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/status') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'auth_required': false},
              ),
            );
            return;
          }
          handler.reject(
            DioException.badResponse(
              statusCode: 404,
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 404),
            ),
          );
        },
      ),
    ],
  );
  addTearDown(auth.dispose);
  await tester.runAsync(() => auth.connect('https://hermes.example'));
  final server = FakeHermesServer()
    ..on(
      'GET',
      '/api/sessions',
      sessionListBody([sessionRow(id: 'voice', title: 'Voice entry')]),
    )
    ..on('GET', '/api/sessions/voice/messages', messageListBody('voice', []))
    ..on('GET', '/api/audio/voice-config', {
      'detail': 'Not Found',
    }, status: 404);
  await pumpChatScreen(
    tester,
    server: server,
    transport: FakeChatTransport(),
    platform: platform,
    size: size,
    providers: [ChangeNotifierProvider<AuthController>.value(value: auth)],
  );
  await openThread(tester, 'Voice entry');
}

void main() {
  const entry = Key('header-voice-call');

  for (final platform in TargetPlatform.values.where(
    (p) => p != TargetPlatform.fuchsia,
  )) {
    testWidgets('the header offers a call on $platform', (tester) async {
      await _open(tester, platform: platform, size: const Size(1400, 900));
      expect(find.byKey(entry), findsOneWidget);
    });
  }

  testWidgets('on a Mac the call opens as a dialog, never a sheet', (
    tester,
  ) async {
    await _open(
      tester,
      platform: TargetPlatform.macOS,
      size: const Size(1100, 800),
    );
    await tester.tap(find.byKey(entry));
    await _settle(tester);
    expect(find.byKey(const Key('voice-call-dialog')), findsOneWidget);
    expect(find.byType(VoiceCallScreen), findsOneWidget);
    // Escape closes it; the chat is still there.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(const Key('voice-call-dialog')), findsNothing);
    expect(find.byKey(entry), findsOneWidget);
  });

  testWidgets('on Android a phone gets a full-screen page', (tester) async {
    await _open(
      tester,
      platform: TargetPlatform.android,
      size: const Size(390, 844),
    );
    await tester.tap(find.byKey(entry));
    await _settle(tester);
    expect(find.byKey(const Key('voice-call-dialog')), findsNothing);
    expect(find.byType(VoiceCallScreen), findsOneWidget);
  });
}
