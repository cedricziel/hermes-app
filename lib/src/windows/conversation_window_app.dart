import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../api/hermes_api_client.dart';
import '../api/hermes_repositories.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../chat/media/media_source.dart';
import '../chat/media/media_store.dart';
import '../macos/mac_window.dart';
import '../settings/theme_controller.dart';
import '../theme/hermes_theme.dart';
import 'conversation_window_args.dart';
import 'conversation_window_screen.dart';
import 'desktop_conversation_windows.dart';
import 'window_auth_interceptor.dart';

/// Runs the engine of conversation window [windowId], which
/// desktop_multi_window started with [arguments]. Unlike the main engine it
/// starts no telemetry, notifications, app lock or share inbox, and holds no
/// session: every request gets its auth headers from the main window.
Future<void> runConversationWindow(String windowId, String arguments) async {
  final link = DesktopConversationWindowLink(windowId);
  final args = ConversationWindowArgs.decode(arguments);
  if (args == null) return link.close();
  await MacWindow.initializeConversationWindow();

  final dio = Dio(
    BaseOptions(
      baseUrl: args.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(WindowAuthInterceptor(dio, link.headers));
  final api = HermesApiClient(dio);
  final repositories = HermesRepositories(api);
  final transport = HermesGatewayTransport(
    connect: hermesGatewayConnect(
      baseUrl: args.baseUrl,
      authRequired: args.authRequired,
      api: api,
    ),
  );

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
          title: args.title,
          debugShowCheckedModeBanner: false,
          theme: buildHermesLightTheme(),
          darkTheme: buildHermesDarkTheme(),
          themeMode: context.select<ThemeController, ThemeMode>((t) => t.mode),
          builder: (context, child) => MacWindowChrome(child: child!),
          home: ConversationWindowScreen(
            args: args,
            link: link,
            chat: repositories.chat,
            models: repositories.models,
            transport: transport,
          ),
        ),
      ),
    ),
  );
}
