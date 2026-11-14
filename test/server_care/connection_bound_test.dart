import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/server_care/connection_bound.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Auth extends AuthController {
  var _state = HermesConnectionState.ready;
  @override
  HermesConnectionState get state => _state;
  @override
  bool get protectedRequestsAllowed => true;

  void leave() {
    _state = HermesConnectionState.needsLogin;
    notifyListeners();
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('a page pushed over the shell goes when the session ends', (
    tester,
  ) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ConnectionBound(
                    child: Scaffold(body: Text('private page')),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('private page'), findsOneWidget);
    auth.leave();
    await tester.pumpAndSettle();
    expect(find.text('private page'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('without an auth controller the page just stays', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ConnectionBound(child: Scaffold(body: Text('page'))),
      ),
    );
    expect(find.text('page'), findsOneWidget);
  });
}
