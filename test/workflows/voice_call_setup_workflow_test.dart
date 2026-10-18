import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/memory_token_store.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

class _PermissionRecorder extends RecordPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
  Completer<bool>? pending;
  final requests = <bool>[];
  @override
  Future<void> create(String recorderId) async {}
  @override
  Future<void> dispose(String recorderId) async {}
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    requests.add(request);
    return pending?.future ?? true;
  }
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final dark in [false, true]) {
    for (final ask in [false, true]) {
      testWidgets(
        'iPhone setup ${ask ? 'uses ordinary chat' : 'cancellation sends nothing'} ${dark ? 'dark' : 'light'}',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final previousRecorder = RecordPlatform.instance;
          final recorder = _PermissionRecorder()..pending = Completer<bool>();
          RecordPlatform.instance = recorder;
          addTearDown(() => RecordPlatform.instance = previousRecorder);
          final native = <MethodCall>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('hermes_app/calls'),
            (call) async {
              native.add(call);
              return null;
            },
          );
          addTearDown(
            () =>
                tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                  const MethodChannel('hermes_app/calls'),
                  null,
                ),
          );
          SharedPreferencesAsyncPlatform.instance =
              InMemorySharedPreferencesAsync.empty();
          final auth = AuthController(
            tokenStore: MemoryTokenStore(),
            interceptors: [
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  if (options.path != '/api/status') {
                    handler.reject(
                      DioException.badResponse(
                        statusCode: 404,
                        requestOptions: options,
                        response: Response(
                          requestOptions: options,
                          statusCode: 404,
                        ),
                      ),
                    );
                    return;
                  }
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      statusCode: 200,
                      data: {'auth_required': false},
                    ),
                  );
                },
              ),
            ],
          );
          addTearDown(auth.dispose);
          await tester.runAsync(() => auth.connect('http://hermes.example'));
          expect(auth.state, HermesConnectionState.ready);
          final server = FakeHermesServer()
            ..on(
              'GET',
              '/api/sessions',
              sessionListBody([sessionRow(id: 'voice', title: 'Voice setup')]),
            )
            ..on(
              'GET',
              '/api/sessions/voice/messages',
              messageListBody('voice', []),
            )
            ..on('GET', '/api/audio/voice-config', {
              'detail': 'Not Found',
            }, status: 404);
          final transport = FakeChatTransport();
          final shots = ScreenshotRecorder(
            'voice-call-setup-${dark ? 'dark' : 'light'}-${ask ? 'chat' : 'cancel'}',
          );
          await shots.start(tester, phoneSize);
          await pumpChatScreen(
            tester,
            server: server,
            transport: transport,
            platform: TargetPlatform.iOS,
            size: phoneSize,
            wrap: shots.frame,
            providers: [
              ChangeNotifierProvider<AuthController>.value(value: auth),
            ],
            theme: withScreenshotFont(
              dark
                  ? buildHermesDarkTheme(platform: TargetPlatform.iOS)
                  : buildHermesLightTheme(platform: TargetPlatform.iOS),
            ),
          );
          await openThread(tester, 'Voice setup');
          await tester.enterText(composerField, 'Keep my draft');
          await tester.pump();
          await tester.tap(find.byKey(const Key('header-voice-call')));
          await _frames(tester);
          expect(find.text('Getting your call ready'), findsOneWidget);
          expect(transport.sends, isEmpty);
          expect(native, isEmpty);
          await shots.capture(tester, 'checking');
          if (!ask) {
            await tester.tap(find.text('Cancel'));
            await _frames(tester);
            recorder.pending!.complete(true);
            await _frames(tester);
            expect(transport.sends, isEmpty);
            expect(native, isEmpty);
            expect(
              tester.widget<EditableText>(composerField).controller.text,
              'Keep my draft',
            );
          } else {
            recorder.pending!.complete(true);
            await _frames(tester);
            expect(find.text('Set up voice calls'), findsOneWidget);
            expect(
              find.text('Update Hermes to enable voice calls.'),
              findsWidgets,
            );
            expect(transport.sends, isEmpty);
            expect(recorder.requests, everyElement(isFalse));
            await shots.capture(tester, 'setup-needed');
            await tester.tap(find.text('Ask Hermes to set this up'));
            await _frames(tester);
            expect(transport.sends, hasLength(1));
            final request = transport.sends.single;
            expect(request.threadId, 'voice');
            expect(request.text, contains('/api/audio/speak-stream'));
            expect(request.attachments, isEmpty);
            expect(
              tester.widget<EditableText>(composerField).controller.text,
              'Keep my draft',
            );
            request.emit(
              const ReplyDelta(
                'I can help. Which speech provider would you like to use?',
              ),
            );
            await _frames(tester);
            expect(find.text('Set up voice calls'), findsNothing);
            expect(find.textContaining('Which speech provider'), findsWidgets);
            await shots.capture(tester, 'normal-chat');
            request
              ..emit(
                const ReplyCompleted(
                  'I can help. Which speech provider would you like to use?',
                ),
              )
              ..emit(const SessionInfo(running: false))
              ..finish();
            await _frames(tester);
            await tester.enterText(composerField, 'Use the local provider.');
            await tester.pump();
            await tester.tap(find.bySemanticsLabel('Send'));
            await _frames(tester);
            expect(transport.sends, hasLength(2));
            expect(transport.sends.last.text, 'Use the local provider.');
            transport.sends.last
              ..emit(
                const ReplyCompleted('Let’s check the installed providers.'),
              )
              ..finish();
            await _frames(tester);
          }
          expect(
            native,
            isEmpty,
            reason: 'No CallKit call before readiness succeeds',
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
          debugDefaultTargetPlatformOverride = null;
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
