import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hermes_app/app');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  });

  test('terminate asks the runner to quit the app', () async {
    await MacApp.terminate();

    expect([for (final c in calls) c.method], ['terminate']);
  });

  test('windowlessChanges passes on what the runner reports', () async {
    final seen = <bool>[];
    final sub = MacApp.windowlessChanges.listen(seen.add);
    addTearDown(sub.cancel);

    for (final value in [true, false]) {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'hermes_app/app',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('windowless', value),
            ),
            (_) {},
          );
    }
    await Future<void>.delayed(Duration.zero);

    expect(seen, [true, false]);
  });
}
