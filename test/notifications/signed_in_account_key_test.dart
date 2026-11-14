import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/local_dashboard.dart';
import '../support/memory_token_store.dart';

void main() {
  group('signedInAccountKey', () {
    late LocalDashboard dashboard;
    late AuthController auth;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      dashboard = await LocalDashboard.start({
        '/api/status': {'version': '0.15.0', 'auth_required': false},
      });
      auth = AuthController(tokenStore: MemoryTokenStore());
    });

    tearDown(() async {
      auth.dispose();
      await dashboard.close();
    });

    test('is the account while connected and null otherwise', () async {
      expect(signedInAccountKey(null), isNull);
      expect(signedInAccountKey(auth), isNull);

      await auth.connect(dashboard.url);
      expect(auth.state, HermesConnectionState.ready);
      expect(signedInAccountKey(auth), auth.accountKey);
      expect(signedInAccountKey(auth), isNotNull);
    });

    test('is null while the server is set but nobody is signed in', () async {
      final locked = await LocalDashboard.start({
        '/api/status': {'version': '0.15.0', 'auth_required': true},
        '/api/auth/providers': {'providers': []},
      });
      addTearDown(locked.close);

      await auth.connect(locked.url);

      // The server is remembered, so the account key exists, but there is
      // no session.
      expect(auth.state, isNot(HermesConnectionState.ready));
      expect(auth.accountKey, isNotNull);
      expect(signedInAccountKey(auth), isNull);
    });
  });
}
