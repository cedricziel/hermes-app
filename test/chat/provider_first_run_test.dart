import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';
import 'package:hermes_app/src/providers/providers_screen.dart';
import 'package:hermes_app/src/providers/widgets/connect_model_card.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/voice/widgets/voice_recording_controls.dart';
import 'package:provider/provider.dart';

import '../providers/fake_provider_backend.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';

const _key = 'sk-or-v1-test-aaaa-4f2a';

/// A profile with no usable model: the welcome card, the composer's pill and
/// a failed reply lead to Model providers, and the chat follows what the
/// screen did.
void main() {
  late FakeProviderBackend backend;
  late BreadcrumbTrail trail;
  late FakeChatTransport transport;

  setUp(() {
    backend = FakeProviderBackend();
    backend.server.on('GET', '/api/sessions', sessionListBody([]));
    trail = BreadcrumbTrail();
    transport = FakeChatTransport();
  });

  Future<void> pump(WidgetTester tester) => pumpChatScreen(
    tester,
    server: backend.server,
    transport: transport,
    models: HermesModelsRepository(backend.server.client().raw),
    providersRepository: ProvidersRepository(
      backend.server.client().raw,
      checkBudget: const Duration(milliseconds: 300),
      recommendBudget: const Duration(milliseconds: 300),
    ),
    providers: [Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail))],
  );

  List<Object?> opened() => [
    for (final c in trail.recent)
      if (c.name == 'providers.opened') c.attributes['source'],
  ];

  int chatOptionReads() => backend.server
      .requestsTo('GET', '/api/model/options')
      .where((r) => r.queryParameters['include_unconfigured'] != true)
      .length;

  bool canSend(WidgetTester tester) =>
      tester.widget<HoldToRecordSend>(find.byType(HoldToRecordSend)).onSend !=
      null;

  Future<void> typeIntoComposer(WidgetTester tester) async {
    await tester.enterText(composerField, 'hello');
    await tester.pump();
  }

  Future<void> connectKey(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), _key);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  group('a fresh server', () {
    testWidgets('the welcome view asks to connect a model', (tester) async {
      await pump(tester);

      expect(find.text('Connect a model to start chatting'), findsOneWidget);
      expect(
        find.text('Your Hermes server has no model provider yet.'),
        findsOneWidget,
      );
      expect(find.text('What can you help me with?'), findsNothing);
      await typeIntoComposer(tester);
      expect(canSend(tester), isFalse);
    });

    testWidgets('Connect a model opens the screen at "Add a provider"', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Connect a model'));
      await tester.pumpAndSettle();

      expect(find.byType(ProvidersScreen), findsOneWidget);
      expect(opened(), ['welcome']);
    });

    testWidgets('the composer pill opens the same screen', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Set up a model'));
      await tester.pumpAndSettle();

      expect(find.byType(ProvidersScreen), findsOneWidget);
      expect(opened(), ['composer']);
    });

    testWidgets('the chat reads its models again as the screen changes them', (
      tester,
    ) async {
      await pump(tester);
      final before = chatOptionReads();
      await tester.tap(find.text('Connect a model'));
      await tester.pumpAndSettle();
      await connectKey(tester);

      // The screen is still open; the key and the default model are saved.
      expect(find.byType(ProvidersScreen), findsOneWidget);
      expect(backend.defaultModel, 'example-model-a');
      expect(chatOptionReads(), greaterThan(before));
    });

    testWidgets('back from setup the prompts return and sending works', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Connect a model'));
      await tester.pumpAndSettle();
      await connectKey(tester);
      await tester.tap(find.text('Start chatting'));
      await tester.pumpAndSettle();

      expect(find.byType(ProvidersScreen), findsNothing);
      expect(find.byType(ConnectModelCard), findsNothing);
      expect(find.text('What can you help me with?'), findsOneWidget);
      expect(find.text('Set up a model'), findsNothing);
      expect(find.text('example-model-a'), findsWidgets);
      await typeIntoComposer(tester);
      expect(canSend(tester), isTrue);
    });

    testWidgets('closing the screen reads the options again too', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Connect a model'));
      await tester.pumpAndSettle();
      // Something changes on the server without the screen noticing.
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_key)
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
      final before = chatOptionReads();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(chatOptionReads(), greaterThan(before));
      expect(find.byType(ConnectModelCard), findsNothing);
      expect(find.text('What can you help me with?'), findsOneWidget);
    });
  });

  group('a provider that lost its key', () {
    setUp(() {
      backend
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
    });

    testWidgets('the card reads Reconnect and sending stays off', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text("Reconnect your model's provider"), findsOneWidget);
      expect(
        find.text(
          'New chats use example-model-a, but its provider\'s key '
          'is missing or no longer works.',
        ),
        findsOneWidget,
      );
      await typeIntoComposer(tester);
      expect(canSend(tester), isFalse);
    });

    testWidgets('Reconnect opens the key form of that provider', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();

      expect(opened(), ['welcome']);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('it shows even while another provider is ready', (
      tester,
    ) async {
      backend.keys['ANTHROPIC_API_KEY'] = FakeProviderBackend.redact(
        'sk-ant-test-bbbb-9c1d',
      );
      await pump(tester);

      expect(find.text("Reconnect your model's provider"), findsOneWidget);
      expect(find.text('What can you help me with?'), findsNothing);
    });

    testWidgets('the composer pill opens the lost provider', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Set up a model'));
      await tester.pumpAndSettle();

      expect(opened(), ['composer']);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('models still loading', () {
    setUp(() {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_key)
        ..modelsWarm = false;
    });

    testWidgets('the card says so and Check again reads the options', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Hermes is loading your models'), findsOneWidget);
      expect(find.text('Connect a model'), findsNothing);

      backend.modelsWarm = true;
      backend
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
      final before = chatOptionReads();
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(chatOptionReads(), greaterThan(before));
      expect(find.byType(ProvidersScreen), findsNothing);
      expect(opened(), isEmpty);
      expect(find.text('What can you help me with?'), findsOneWidget);
    });
  });

  group('while the options are read again', () {
    testWidgets('the card stays and the starter prompts never show', (
      tester,
    ) async {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_key)
        ..modelsWarm = false;
      await pump(tester);
      expect(find.text('Hermes is loading your models'), findsOneWidget);

      final held = Completer<FakeResponse>();
      backend.server.onRequest('GET', '/api/model/options', (_) => held.future);
      await tester.tap(find.text('Check again'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('What can you help me with?'), findsNothing);
        expect(find.byType(ConnectModelCard), findsOneWidget);
      }

      held.complete((
        status: 200,
        body: {
          'provider': '',
          'model': '',
          'providers': [
            {'slug': 'openrouter', 'authenticated': true, 'models': []},
          ],
        },
      ));
      await tester.pumpAndSettle();
      // Still warming after "Check again": the card stops waiting.
      expect(find.text('Connect a model to start chatting'), findsOneWidget);
      expect(find.text('What can you help me with?'), findsNothing);
    });

    testWidgets('an unchanged answer to Check again asks to connect', (
      tester,
    ) async {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_key)
        ..modelsWarm = false;
      await pump(tester);
      expect(find.text('Hermes is loading your models'), findsOneWidget);

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(find.text('Connect a model to start chatting'), findsOneWidget);
      expect(find.text('Hermes is loading your models'), findsNothing);
    });
  });

  group('a failed reply', () {
    Future<void> failWith(WidgetTester tester, String message) async {
      await tester.enterText(composerField, 'hello');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      transport.sends.single
        ..emit(const ThreadBound('t-1'))
        ..emit(ReplyCompleted(message, failed: true))
        ..finish();
      await tester.pumpAndSettle();
    }

    setUp(() {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_key)
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
    });

    testWidgets('from the provider offers Check model providers', (
      tester,
    ) async {
      await pump(tester);
      await failWith(tester, 'HTTP 402: the account has no credit left.');

      expect(find.text('Check model providers'), findsOneWidget);
      expect(
        find.textContaining('the account has no credit left'),
        findsOneWidget,
      );

      await tester.tap(find.text('Check model providers'));
      await tester.pumpAndSettle();

      expect(opened(), ['reply']);
      expect(find.byType(ProvidersScreen), findsOneWidget);
      // The default model's provider is shown (its key can be replaced).
      expect(find.text('Remove key'), findsWidgets);
    });

    testWidgets('of another kind shows the error alone', (tester) async {
      await pump(tester);
      await failWith(tester, 'The connection was lost.');

      expect(find.text('The connection was lost.'), findsOneWidget);
      expect(find.text('Check model providers'), findsNothing);
    });
  });

  group('a server without model providers', () {
    testWidgets('keeps the terminal command behind the pill', (tester) async {
      backend.server.on('GET', '/api/model/options', {
        'detail': 'Not Found',
      }, status: 404);
      await pump(tester);

      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.byType(ConnectModelCard), findsNothing);
      await tester.tap(find.text('Profile default'));
      await tester.pumpAndSettle();

      expect(find.byType(ProvidersScreen), findsNothing);
      expect(find.text('hermes model'), findsOneWidget);
      expect(opened(), isEmpty);
    });
  });
}
