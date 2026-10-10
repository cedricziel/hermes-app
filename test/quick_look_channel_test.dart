import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/media/quick_look.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(quickLookChannelName);
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply(call);
        });
  }

  setUp(calls.clear);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  const quickLook = MethodChannelQuickLook();

  test('preview sends the path and returns the native answer', () async {
    answer((_) => true);
    expect(await quickLook.preview('/cache/a.pdf'), isTrue);
    expect(calls.single.method, 'preview');
    expect(calls.single.arguments, {'path': '/cache/a.pdf'});

    answer((_) => false);
    expect(await quickLook.preview('/cache/gone.pdf'), isFalse);
  });

  test(
    'toggle maps shown and closed, and anything else is a failure',
    () async {
      answer((_) => 'shown');
      expect(await quickLook.toggle('/a'), QuickLookToggle.shown);
      answer((_) => 'closed');
      expect(await quickLook.toggle('/a'), QuickLookToggle.closed);
      answer((_) => false);
      expect(await quickLook.toggle('/a'), QuickLookToggle.failed);
      answer((_) => null);
      expect(await quickLook.toggle('/a'), QuickLookToggle.failed);
    },
  );

  test('a platform error is a failure, not an exception', () async {
    answer((_) => throw PlatformException(code: 'boom'));
    expect(await quickLook.preview('/a'), isFalse);
    expect(await quickLook.toggle('/a'), QuickLookToggle.failed);
    await quickLook.close();
  });

  test('a missing handler is a failure and close is safe', () async {
    // No handler is registered, as in an engine that never installed it.
    expect(await quickLook.preview('/a'), isFalse);
    expect(await quickLook.toggle('/a'), QuickLookToggle.failed);
    await quickLook.close();
  });

  test('close tells the panel', () async {
    answer((_) => null);
    await quickLook.close();
    expect(calls.single.method, 'close');
  });

  test('NoQuickLook shows nothing', () async {
    const none = NoQuickLook();
    expect(none.available, isFalse);
    expect(await none.preview('/a'), isFalse);
    expect(await none.toggle('/a'), QuickLookToggle.failed);
  });
}
