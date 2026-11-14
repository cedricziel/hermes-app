import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';

import '../providers/fake_provider_backend.dart';

import 'package:hermes_app/src/voice/widgets/voice_recording_controls.dart'
    show HoldToRecordSend;

import 'package:hermes_app/src/theme/app_icons.dart';

import '../support/fake_chat_transport.dart';
import '../support/find_app_icon.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart' show composerField;
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

const _fakeKey = 'sk-or-v1-test-aaaa-4f2a';

/// A server with no model, from the chat: the welcome card leads to Model
/// providers and back, and a failed reply leads there too. Phone and desktop,
/// light and dark, and one German pass; look at the screenshots in
/// `build/workflow_screenshots/`.
void main() {
  late FakeProviderBackend backend;
  late FakeChatTransport transport;

  setUp(() {
    backend = FakeProviderBackend();
    backend.server.on('GET', '/api/sessions', sessionListBody([]));
    transport = FakeChatTransport();
  });

  Future<void> pump(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    required TargetPlatform platform,
    Brightness brightness = Brightness.light,
    Locale? locale,
  }) async {
    final raw = backend.server.client().raw;
    await pumpScreen(
      tester,
      shots,
      ChatScreen(
        repository: HermesChatRepository(raw),
        models: HermesModelsRepository(raw),
        providers: ProvidersRepository(
          raw,
          checkBudget: const Duration(milliseconds: 300),
          recommendBudget: const Duration(milliseconds: 300),
        ),
        transport: transport,
      ),
      size: size,
      brightness: brightness,
      platform: platform,
      locale: locale,
    );
    // A phone starts on the list of chats; a new one shows the welcome view.
    if (size == phoneSize) {
      await tester.tap(findAppIcon(AppIcons.compose).first);
      await tester.pumpAndSettle();
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> typeKey(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), _fakeKey);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
  }

  final variants = [
    ('phone', phoneSize, TargetPlatform.iOS, Brightness.light),
    ('phone-dark', phoneSize, TargetPlatform.android, Brightness.dark),
    ('desktop', desktopSize, TargetPlatform.macOS, Brightness.light),
    ('desktop-dark', desktopSize, TargetPlatform.macOS, Brightness.dark),
  ];

  for (final (name, size, platform, brightness) in variants) {
    testWidgets('$name: connect a key from the welcome card', (tester) async {
      final shots = ScreenshotRecorder('first-run-key-$name');
      await pump(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
      );
      expect(find.text('Connect a model to start chatting'), findsOneWidget);
      await shots.capture(tester, 'welcome-card');

      await tester.tap(find.text('Connect a model'));
      await settle(tester);
      await shots.capture(tester, 'model-providers');

      await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
      await settle(tester);
      await typeKey(tester);
      await shots.capture(tester, 'key-typed');

      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text("You're ready"), findsOneWidget);
      await shots.capture(tester, 'default-model');

      await tester.tap(find.text('Start chatting'));
      await settle(tester);
      expect(find.text('What can you help me with?'), findsOneWidget);
      expect(find.text('Connect a model to start chatting'), findsNothing);
      await shots.capture(tester, 'back-in-chat');

      await tester.enterText(composerField, 'Summarise my open tasks');
      await tester.pump();
      await tester.tap(find.byType(HoldToRecordSend));
      await tester.pump();
      expect(transport.sends, hasLength(1));
      expect(transport.sends.single.text, 'Summarise my open tasks');
      transport.sends.single
        ..emit(const ThreadBound('t-1'))
        ..emit(const ReplyCompleted('Two tasks are open.'))
        ..finish();
      await settle(tester);
      await shots.capture(tester, 'first-reply');
      await letSocketsIdle(tester);
    });
  }

  for (final (name, size, platform, brightness) in [variants[0], variants[3]]) {
    testWidgets('$name: sign in with a code from the welcome card', (
      tester,
    ) async {
      // Hermes recommends a model its list shows, so the pill names it.
      backend.recommended['nous'] = 'example-model-a';
      final shots = ScreenshotRecorder('first-run-sign-in-$name');
      await pump(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await tester.tap(find.text('Connect a model'));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
      await settle(tester);
      expect(find.textContaining('ABCD'), findsWidgets);
      await shots.capture(tester, 'code');

      backend.pollAnswer = {'session_id': 's-1', 'status': 'approved'};
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      await shots.capture(tester, 'ready');

      await tester.tap(find.text('Start chatting'));
      await settle(tester);
      expect(find.text('What can you help me with?'), findsOneWidget);
      await shots.capture(tester, 'back-in-chat');
      await letSocketsIdle(tester);
    });
  }

  for (final (name, size, platform, brightness) in [
    variants[0],
    variants[1],
    variants[2],
  ]) {
    testWidgets('$name: the provider lost its key', (tester) async {
      backend
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
      final shots = ScreenshotRecorder('first-run-reconnect-$name');
      await pump(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
      );
      expect(find.text("Reconnect your model's provider"), findsOneWidget);
      await shots.capture(tester, 'reconnect-card');

      await tester.tap(find.text('Reconnect'));
      await settle(tester);
      await shots.capture(tester, 'key-form');
      await letSocketsIdle(tester);
    });
  }

  testWidgets('another provider is ready, the default one lost its key', (
    tester,
  ) async {
    backend
      ..keys['ANTHROPIC_API_KEY'] = FakeProviderBackend.redact(
        'sk-ant-test-bbbb-9c1d',
      )
      ..defaultProvider = 'openrouter'
      ..defaultModel = 'example-model-a';
    final shots = ScreenshotRecorder('first-run-reconnect-other-ready');
    await pump(tester, shots, size: phoneSize, platform: TargetPlatform.iOS);
    expect(find.text("Reconnect your model's provider"), findsOneWidget);
    await shots.capture(tester, 'reconnect-card');
    await letSocketsIdle(tester);
  });

  for (final (name, size, platform, brightness) in [variants[0], variants[3]]) {
    testWidgets('$name: Hermes is loading your models', (tester) async {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_fakeKey)
        ..modelsWarm = false;
      final shots = ScreenshotRecorder('first-run-loading-$name');
      await pump(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
      );
      expect(find.text('Hermes is loading your models'), findsOneWidget);
      await shots.capture(tester, 'loading-card');

      backend
        ..modelsWarm = true
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
      await tester.tap(find.text('Check again'));
      await settle(tester);
      expect(find.text('What can you help me with?'), findsOneWidget);
      await shots.capture(tester, 'prompts-back');
      await letSocketsIdle(tester);
    });
  }

  for (final (name, size, platform, brightness) in [
    variants[0],
    variants[1],
    variants[2],
  ]) {
    testWidgets('$name: a failed reply leads to Model providers', (
      tester,
    ) async {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_fakeKey)
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
      final shots = ScreenshotRecorder('first-run-failed-reply-$name');
      await pump(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await tester.enterText(composerField, 'Summarise my open tasks');
      await tester.pump();
      await tester.tap(find.byType(HoldToRecordSend));
      await tester.pump();
      transport.sends.single
        ..emit(const ThreadBound('t-1'))
        ..emit(
          const ReplyCompleted(
            'HTTP 402: the account has no credit left.',
            failed: true,
          ),
        )
        ..finish();
      await settle(tester);
      expect(find.text('Check model providers'), findsOneWidget);
      await shots.capture(tester, 'failed-reply');

      await tester.tap(find.text('Check model providers'));
      await settle(tester);
      await shots.capture(tester, 'provider-detail');
      await letSocketsIdle(tester);
    });
  }

  for (final (name, size, platform, brightness) in [variants[0], variants[3]]) {
    testWidgets('$name: in German', (tester) async {
      final de = lookupAppLocalizations(const Locale('de'));
      final shots = ScreenshotRecorder('first-run-de-$name');
      await pump(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
        locale: const Locale('de'),
      );
      expect(find.text(de.providersCardConnectTitle), findsOneWidget);
      await shots.capture(tester, 'welcome-card');

      await tester.tap(find.text(de.providersCardConnect));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
      await settle(tester);
      await typeKey(tester);
      await tester.tap(find.text(de.providersFormSave));
      await settle(tester);
      await shots.capture(tester, 'default-model');
      await tester.tap(find.text(de.providersStepStartChatting));
      await settle(tester);
      await shots.capture(tester, 'back-in-chat');
      await letSocketsIdle(tester);
    });
  }
}
