import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../chat/media/media_source.dart';
import '../chat/media/media_store.dart';
import '../settings/theme_controller.dart';
import '../theme/hermes_theme.dart';
import '../voice/dictation_settings.dart';
import '../voice/on_device_speech.dart';
import '../voice/voice_recorder.dart';
import '../windows/conversation_window_args.dart';
import '../windows/desktop_conversation_windows.dart';
import '../windows/window_api_client.dart';
import 'quick_panel_screen.dart';

/// Runs the quick panel's engine (macOS), which desktop_multi_window started
/// for [windowId]. Like a conversation window it starts no telemetry or
/// notifications and holds no session: requests get their auth headers from
/// the main window. Unlike one it dictates, with its own recognizer.
Future<void> runQuickPanel(String windowId, QuickPanelLaunch launch) async {
  final link = DesktopQuickPanelLink(windowId);
  final api = windowApiClient(launch.baseUrl, link.headers);
  final repositories = HermesRepositories(api);
  final transport = HermesGatewayTransport(
    connect: hermesGatewayConnect(
      baseUrl: launch.baseUrl,
      authRequired: launch.authRequired,
      api: api,
    ),
  );
  final dictationSettings = DictationSettings();
  unawaited(dictationSettings.load());
  // One per engine: the recognizer's event channel has a single sink.
  final onDevice = OnDeviceSpeech();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        Provider<MediaStore?>(
          lazy: false,
          create: (_) => MediaStore(
            source: HermesMediaSource(() => api),
            cacheDirectory: getApplicationCacheDirectory,
          ),
          dispose: (_, store) => store?.dispose(),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Hermes',
          debugShowCheckedModeBanner: false,
          theme: buildHermesLightTheme(),
          darkTheme: buildHermesDarkTheme(),
          themeMode: context.select<ThemeController, ThemeMode>((t) => t.mode),
          home: QuickPanelScreen(
            link: link,
            chat: repositories.chat,
            models: repositories.models,
            transport: transport,
            voiceRecorder: RecordVoiceRecorder(),
            transcribeConnect: hermesMixedSocketConnect(
              baseUrl: launch.baseUrl,
              authRequired: launch.authRequired,
              api: api,
              path: '/api/audio/transcribe-stream',
            ),
            dictationSettings: dictationSettings,
            onDevice: onDevice,
          ),
        ),
      ),
    ),
  );
}
