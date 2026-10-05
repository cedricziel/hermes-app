import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/handoff/handoff_activity.dart';
import 'package:hermes_app/src/handoff/handoff_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final payload = <String, Object?>{
    'version': 1,
    'serverUrl': 'https://example.test/hermes/',
    'profile': 'work',
    'threadId': 'same-id',
  };
  test('canonicalizes dashboard identity without losing its base path', () {
    final activity = HandoffActivity.parse(payload)!;
    expect(activity.serverUrl, 'https://example.test/hermes');
    expect(
      HandoffActivity.server('HTTPS://EXAMPLE.TEST:443/hermes/'),
      activity.serverUrl,
    );
    expect(
      HandoffActivity.server('https://example.test/other'),
      isNot(activity.serverUrl),
    );
    expect(activity.profile, 'work');
  });
  test('refuses ambiguous profile ownership', () {
    expect(HandoffActivity.parse({...payload, 'profile': ''}), isNull);
  });
  test('refuses credentials and non-dashboard URL components', () {
    expect(
      HandoffActivity.parse({
        ...payload,
        'serverUrl': 'https://user:secret@example.test',
      }),
      isNull,
    );
    expect(HandoffActivity.server('https://example.test?token=secret'), isNull);
    expect(HandoffActivity.server('https://example.test#chat'), isNull);
    expect(HandoffActivity.server('file:///tmp/chat'), isNull);
  });
  test('rejects unknown versions and oversized activities', () {
    expect(HandoffActivity.parse({...payload, 'version': 2}), isNull);
    expect(HandoffActivity.parse({...payload, 'threadId': 'x' * 3100}), isNull);
  });
  test('unsupported platforms never invoke a native channel', () async {
    final bridge = HandoffBridge(enabled: false);
    expect(await bridge.take(), isNull);
    await bridge.publish(HandoffActivity.parse(payload));
    bridge.dispose();
  });
  test(
    'drains launch and runtime receipts through the same native inbox',
    () async {
      const channel = MethodChannel('hermes_app/handoff');
      Object? pending = payload;
      final published = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'take') {
              final value = pending;
              pending = null;
              return value;
            }
            published.add(call.arguments);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final bridge = HandoffBridge(enabled: true);
      addTearDown(bridge.dispose);
      expect(HandoffActivity.parse(await bridge.take())?.threadId, 'same-id');
      expect(await bridge.take(), isNull);
      pending = {...payload, 'threadId': 'new-id'};
      final received = <Object?>[];
      bridge.onIncoming = received.add;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'hermes_app/handoff',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('incoming'),
            ),
            (_) {},
          );
      expect(HandoffActivity.parse(received.single)?.threadId, 'new-id');
      await bridge.publish(HandoffActivity.parse(payload));
      await bridge.publish(null);
      expect(
        published.first,
        payload..['serverUrl'] = 'https://example.test/hermes',
      );
      expect(published.last, isNull);
    },
  );
}
