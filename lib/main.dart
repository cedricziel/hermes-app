import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/auth/auth_controller.dart';
import 'src/settings/theme_controller.dart';
import 'src/share/share_controller.dart';
import 'src/share/share_inbox.dart';
import 'src/telemetry/telemetry.dart';
import 'src/telemetry/telemetry_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final telemetry = await Telemetry.initialize(
    TelemetryConfig.fromEnvironment(),
  );
  telemetry.logUncaughtErrors();
  final httpInterceptor = telemetry.dioInterceptor();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              AuthController(interceptors: [?httpInterceptor])..bootstrap(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(
          create: (_) => ShareController(createPlatformShareInbox())..start(),
        ),
      ],
      child: const HermesApp(),
    ),
  );
}
