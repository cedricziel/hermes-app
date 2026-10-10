import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:hermes_app/src/voice/on_device_speech.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_share_inbox.dart';
import 'support/fake_speech_channel.dart';

void main() {
  late DictationSettings settings;
  late FakeSpeechChannel speech;
  late BreadcrumbTrail trail;
  final device = find.byKey(const Key('dictation-device'));

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = DictationSettings();
    speech = FakeSpeechChannel()..status = 'missing';
    trail = BreadcrumbTrail();
  });
  tearDown(() => speech.dispose());

  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

  Future<void> openAccountMenu(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ChangeNotifierProvider(create: (_) => NotificationSettings()),
          ChangeNotifierProvider.value(value: settings),
          Provider(create: (_) => OnDeviceSpeech()),
          Provider.value(value: Breadcrumbs.of(trail)),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: const ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await openAccountMenu(tester);
    await tester.tap(find.text('Dictation'));
    await tester.pumpAndSettle();
  }

  testWidgets('Android has no Dictation setting', (tester) async {
    await openAccountMenu(tester);

    expect(find.text('Dictation'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('picking On this device downloads the model', (tester) async {
    await tester.runAsync(() => settings.setEngine(DictationEngine.hermes));
    await openDialog(tester);
    expect(find.text('Downloads a speech model once'), findsOneWidget);

    await tester.tap(device);
    await tester.pump();
    await tester.runAsync(() => speech.progress(0.4));
    await tester.pump();
    await tester.pump();
    expect(find.text('Downloading… 40%'), findsOneWidget);
    expect(settings.engine, DictationEngine.device);

    speech.completeInstall();
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(speech.calls.where((c) => c.method == 'install'), hasLength(1));
    expect(speech.calls.last.arguments, {
      'locale': OnDeviceSpeech.deviceLocale(),
    });
    expect(trail.recent.last.name, 'voice.model.install');
    expect(trail.recent.last.attributes, {'outcome': 'installed'});
  }, variant: iOS);

  testWidgets('with On this device chosen, a missing model downloads', (
    tester,
  ) async {
    await tester.runAsync(() => settings.setEngine(DictationEngine.device));
    await openDialog(tester);

    expect(speech.calls.where((c) => c.method == 'install'), hasLength(1));
    speech.completeInstall();
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
  }, variant: iOS);

  testWidgets('a tap before the model is known is kept', (tester) async {
    await tester.runAsync(() => settings.setEngine(DictationEngine.hermes));
    final gate = speech.statusGate = Completer();
    await openAccountMenu(tester);
    await tester.tap(find.text('Dictation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(device);
    await tester.pump();
    expect(settings.engine, DictationEngine.device);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(speech.calls.where((c) => c.method == 'install'), hasLength(1));
  }, variant: iOS);

  testWidgets('an unsupported device shows Hermes as the engine in use', (
    tester,
  ) async {
    speech.status = 'unsupported';
    await tester.runAsync(() => settings.setEngine(DictationEngine.device));
    await openDialog(tester);

    expect(
      tester
          .widget<RadioGroup<DictationEngine>>(
            find.byType(RadioGroup<DictationEngine>),
          )
          .groupValue,
      DictationEngine.hermes,
    );
  }, variant: iOS);

  testWidgets('a failed download offers to try again', (tester) async {
    await openDialog(tester);
    await tester.tap(device);
    await tester.pump();

    speech.failInstall('failed');
    await tester.pumpAndSettle();

    expect(find.text('The speech model didn’t download.'), findsOneWidget);
    expect(trail.recent.last.attributes, {'outcome': 'failed'});

    await tester.tap(find.byKey(const Key('dictation-retry-download')));
    await tester.pump();
    speech.completeInstall();
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(speech.calls.where((c) => c.method == 'install'), hasLength(2));
  }, variant: iOS);

  testWidgets('reopening during a download shows it going on', (tester) async {
    speech.status = 'downloading';
    await tester.runAsync(() => settings.setEngine(DictationEngine.device));
    await openDialog(tester);

    await tester.runAsync(() => speech.progress(0.7));
    await tester.pump();
    await tester.pump();

    expect(find.text('Downloading… 70%'), findsOneWidget);
  }, variant: iOS);

  testWidgets('an unsupported language keeps dictation on Hermes', (
    tester,
  ) async {
    speech.status = 'unsupported';
    await openDialog(tester);

    await tester.tap(device);
    await tester.pumpAndSettle();

    expect(find.text('Not available for your language'), findsOneWidget);
    expect(settings.engine, DictationEngine.hermes);
    expect(speech.calls.where((c) => c.method == 'install'), isEmpty);
  }, variant: iOS);
}
