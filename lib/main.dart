import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/auth/auth_controller.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController()..bootstrap(),
      child: const HermesApp(),
    ),
  );
}
