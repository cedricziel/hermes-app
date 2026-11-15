import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/app.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/voice/calls/call_bridge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_device_authenticator.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart';

/// Opening or resuming the app must never touch the audio session: on iOS
/// that interrupts the music or video playing in another app. Only the user
/// starting dictation, playback or a call may reach these plugins. The Swift
/// side of the same rule is pinned by `test/native_audio_launch_test.dart`.
const _methodChannels = [
  'hermes_app/calls',
  'hermes_app/calls/events',
  'hermes_app/speech',
  'hermes_app/speech/events',
  'com.ryanheise.audio_session',
  'com.ryanheise.av_audio_session',
  'com.ryanheise.android_audio_manager',
  'com.llfbandit.record/messages',
];

/// Read-only questions the speech plugin answers without opening any audio
/// (model status, install); everything else would listen or transcribe.
const _speechReads = {'status', 'install'};

final _calls = <String>[];

void _record() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in _methodChannels) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      _calls.add('$name.${call.method}');
      return null;
    });
  }
  addTearDown(() {
    for (final name in _methodChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });
}

List<String> get _audioCalls => [
  for (final call in _calls)
    if (!(call.startsWith('hermes_app/speech.') &&
        _speechReads.contains(call.split('.').last)))
      call,
];

/// The binding checks its debug variables before a tearDown runs, so the
/// platform is put back here.
Future<void> _on(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

class _ReadyAuth extends AuthController {
  _ReadyAuth(this.client);
  final HermesApiClient client;
  @override
  HermesConnectionState get state => HermesConnectionState.ready;
  @override
  bool get protectedRequestsAllowed => true;
  @override
  HermesApiClient get api => client;
  @override
  String get baseUrl => 'https://hermes.test';
}

Future<void> _lifecycle(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester tester, AuthController auth) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
  await tester.runAsync(lock.load);
  addTearDown(lock.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider.value(value: lock),
        ChangeNotifierProvider(
          create: (_) => ShareController(FakeShareInbox()),
        ),
      ],
      child: const HermesApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    _calls.clear();
    _record();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('on ${platform.name}', () {
      testWidgets(
        'a signed-out app launches and resumes silently',
        (tester) => _on(platform, () async {
          final auth = AuthController();
          unawaited(auth.bootstrap());
          addTearDown(auth.dispose);
          await _pumpApp(tester, auth);
          await _lifecycle(tester);

          expect(find.text('Connect to Hermes'), findsOneWidget);
          expect(_audioCalls, isEmpty);
        }),
      );

      testWidgets(
        'a signed-in app launches and resumes silently',
        (tester) => _on(platform, () async {
          final server = FakeHermesServer();
          await _pumpApp(tester, _ReadyAuth(server.client()));
          await _lifecycle(tester);

          expect(tester.takeException(), isNull);
          expect(_audioCalls, isEmpty);
        }),
      );

      testWidgets(
        'an open chat launches and resumes silently',
        (tester) => _on(platform, () async {
          final server = FakeHermesServer()
            ..on(
              'GET',
              '/api/sessions',
              sessionListBody([
                sessionRow(id: 's1', title: 'Telegram pairing'),
              ]),
            );
          await pumpChatScreen(tester, server: server, platform: platform);
          await openThread(tester, 'Telegram pairing');
          await _lifecycle(tester);

          expect(_audioCalls, isEmpty);
        }),
      );
    });
  }

  // Without these the guards above would pass with the channels unwired.
  group('positive control', () {
    test('the call bridge reaches the calls channel', () async {
      await AppleCallBridge().start('id', 'Hermes');

      expect(_calls, ['hermes_app/calls.start']);
    });

    test('the audio session plugin reaches its channel', () async {
      await (await AudioSession.instance)
          .setActive(true)
          .catchError((Object _) => false);

      expect(_calls, contains('com.ryanheise.audio_session.getConfiguration'));
    });
  });
}
