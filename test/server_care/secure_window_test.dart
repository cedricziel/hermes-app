import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/secure_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hermes_app/secure_window');
  final calls = <Object?>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.arguments);
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('sets the flag on hold and clears it after the last release', () async {
    final window = SecureWindow(platform: TargetPlatform.android);
    final a = window.hold();
    final b = window.hold();
    await pumpEventQueue();
    expect(calls, [true]);
    a();
    a();
    await pumpEventQueue();
    expect(calls, [true]);
    b();
    await pumpEventQueue();
    expect(calls, [true, false]);
  });

  test('does nothing off Android', () async {
    final window = SecureWindow(platform: TargetPlatform.iOS);
    window.hold()();
    await pumpEventQueue();
    expect(calls, isEmpty);
  });

  test('a missing handler is not an error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SecureWindow(platform: TargetPlatform.android).hold()();
    await pumpEventQueue();
  });
}
