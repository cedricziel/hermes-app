import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart' show SoLoud;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/voice/calls/call_bridge.dart';
import 'package:hermes_app/src/voice/calls/portable_call_settings.dart';
import 'package:hermes_app/src/voice/voice_call_screen.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../voice/calls/fakes.dart';
import '../support/fake_hermes_server.dart';
import '../support/memory_token_store.dart';
import '../support/pump_chat.dart';

class _Recorder extends RecordPlatform {
  /// Permission checks (`queries`) and permission prompts (`requests`).
  int queries = 0, requests = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
  @override
  Future<void> create(String recorderId) async {}
  @override
  Future<void> dispose(String recorderId) async {}
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    request ? requests++ : queries++;
    return true;
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The switch as the app has it: [on] true or false once loaded, null for an
/// app that provides none, [loaded] false for one that has not read it yet.
class _Setup {
  _Setup(this.recorder, this.bridges, this.settings);
  final _Recorder recorder;
  final List<CallBridge> bridges;
  final PortableCallSettings? settings;
}

Future<_Setup> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
  bool? on,
  bool loaded = true,
}) async {
  final recorder = _Recorder();
  final previous = RecordPlatform.instance;
  RecordPlatform.instance = recorder;
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
  PortableCallSettings? settings;
  if (on != null) {
    settings = PortableCallSettings();
    if (loaded) await tester.runAsync(() => settings!.setEnabled(on));
  }
  final bridges = <CallBridge>[];
  await pumpChatScreen(
    tester,
    server: server,
    transport: FakeChatTransport(),
    platform: platform,
    size: size,
    callBridge: () {
      final bridge = FakeCallBridge();
      bridges.add(bridge);
      return bridge;
    },
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      if (settings != null)
        ChangeNotifierProvider<PortableCallSettings>.value(value: settings),
    ],
  );
  await openThread(tester, 'Voice entry');
  return _Setup(recorder, bridges, settings);
}

void main() {
  const entry = Key('header-voice-call');
  const portable = [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];
  // The three places the button lives: the Mac toolbar, the wide header and
  // the phone's app bar.
  final layouts = <(String, TargetPlatform, Size)>[
    for (final platform in portable)
      (
        platform == TargetPlatform.macOS ? 'Mac toolbar' : 'wide header',
        platform,
        const Size(1400, 900),
      ),
    for (final platform in portable.where((p) => p != TargetPlatform.macOS))
      ('phone app bar', platform, const Size(390, 844)),
  ];

  group('with the switch on', () {
    for (final (name, platform, size) in layouts) {
      testWidgets('the $name offers a call on $platform', (tester) async {
        await _open(tester, platform: platform, size: size, on: true);
        expect(find.byKey(entry), findsOneWidget);
      });
    }
  });

  group('with the switch off', () {
    // Off is the default, a missing switch and one not read yet alike.
    final offStates = <(String, bool?, bool)>[
      ('saved off', false, true),
      ('not provided', null, true),
      ('not read yet', true, false),
    ];
    for (final (name, platform, size) in layouts) {
      for (final (state, on, loaded) in offStates) {
        testWidgets('no button in the $name on $platform, $state', (
          tester,
        ) async {
          final setup = await _open(
            tester,
            platform: platform,
            size: size,
            on: on,
            loaded: loaded,
          );
          await _settle(tester);
          expect(find.byKey(entry), findsNothing);
          expect(find.byTooltip('Start voice call'), findsNothing);
          expect(setup.bridges, isEmpty, reason: 'no bridge was created');
          expect(setup.recorder.queries, 0);
          expect(setup.recorder.requests, 0, reason: 'no microphone prompt');
          expect(
            SoLoud.instance.isInitialized,
            isFalse,
            reason: 'the engine never started',
          );
        });
      }
    }
  });

  group('iOS is unchanged', () {
    for (final size in [const Size(1400, 900), const Size(390, 844)]) {
      for (final on in <bool?>[null, false, true]) {
        testWidgets('the button shows at ${size.width.toInt()} with switch '
            '${on ?? 'not provided'}', (tester) async {
          await _open(tester, platform: TargetPlatform.iOS, size: size, on: on);
          expect(find.byKey(entry), findsOneWidget);
        });
      }
    }
  });

  testWidgets('turning the switch on and off shows and hides the button', (
    tester,
  ) async {
    final setup = await _open(
      tester,
      platform: TargetPlatform.android,
      size: const Size(390, 844),
      on: false,
    );
    expect(find.byKey(entry), findsNothing);
    await tester.runAsync(() => setup.settings!.setEnabled(true));
    await tester.pump();
    expect(find.byKey(entry), findsOneWidget);
    await tester.runAsync(() => setup.settings!.setEnabled(false));
    await tester.pump();
    expect(find.byKey(entry), findsNothing);
  });

  testWidgets('with the switch on the call opens and checks the microphone '
      'without asking for it', (tester) async {
    final setup = await _open(
      tester,
      platform: TargetPlatform.linux,
      size: const Size(1400, 900),
      on: true,
    );
    await tester.tap(find.byKey(entry));
    await _settle(tester);
    expect(find.byType(VoiceCallScreen), findsOneWidget);
    expect(setup.recorder.queries, greaterThan(0));
    expect(setup.recorder.requests, 0);
    expect(setup.bridges, isEmpty, reason: 'a bridge only once Start is hit');
    expect(SoLoud.instance.isInitialized, isFalse);
  });

  testWidgets('turning the switch off while the call screen checks stops the '
      'call from starting', (tester) async {
    final setup = await _open(
      tester,
      platform: TargetPlatform.linux,
      size: const Size(1400, 900),
      on: true,
    );
    await tester.tap(find.byKey(entry));
    await tester.pump();
    await tester.runAsync(() => setup.settings!.setEnabled(false));
    await _settle(tester);
    expect(find.byType(VoiceCallScreen), findsOneWidget);
    expect(
      find.textContaining('This chat changed'),
      findsWidgets,
      reason: 'the checks end as no longer current',
    );
    expect(find.text('Start call'), findsNothing);
    expect(setup.bridges, isEmpty);
  });

  testWidgets('on a Mac the call opens as a dialog, never a sheet', (
    tester,
  ) async {
    await _open(
      tester,
      platform: TargetPlatform.macOS,
      size: const Size(1100, 800),
      on: true,
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
      on: true,
    );
    await tester.tap(find.byKey(entry));
    await _settle(tester);
    expect(find.byKey(const Key('voice-call-dialog')), findsNothing);
    expect(find.byType(VoiceCallScreen), findsOneWidget);
  });
}
