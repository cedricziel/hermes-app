import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';
import 'support/unreadable_prefs.dart';

void main() {
  test('asks for the server address when the saved one cannot be read, '
      'instead of staying on initializing', () async {
    SharedPreferencesAsyncPlatform.instance = UnreadablePrefs();
    final controller = AuthController(tokenStore: MemoryTokenStore());
    addTearDown(controller.dispose);

    final reported = await reportedErrors(controller.bootstrap);

    expect(controller.state, HermesConnectionState.needsServerUrl);
    expect(reported.single.exception, isA<PlatformException>());
  });
}
