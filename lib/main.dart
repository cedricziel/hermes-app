import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/auth/auth_controller.dart';
import 'src/share/share_controller.dart';
import 'src/share/share_inbox.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()..bootstrap()),
        ChangeNotifierProvider(
          create: (_) => ShareController(createPlatformShareInbox())..start(),
        ),
      ],
      child: const HermesApp(),
    ),
  );
}
