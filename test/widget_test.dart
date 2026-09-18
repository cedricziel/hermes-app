import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/app.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';

void main() {
  testWidgets('shows the server setup screen with no saved server', (
    WidgetTester tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController()..bootstrap(),
        child: const HermesApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect to Hermes'), findsOneWidget);
  });
}
