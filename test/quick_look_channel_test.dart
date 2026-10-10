import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/media/quick_look.dart';

import 'support/fake_quick_look.dart';

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

  test('the double-click interval comes from the system in seconds', () async {
    answer((_) => 0.35);
    expect(
      await quickLook.doubleClickInterval(),
      const Duration(milliseconds: 350),
    );
    answer((_) => null);
    expect(await quickLook.doubleClickInterval(), isNull);
  });

  group('readDoubleClickInterval', () {
    tearDown(() => doubleClickInterval = const Duration(milliseconds: 500));

    test('keeps what the system says', () async {
      await readDoubleClickInterval(
        FakeQuickLook()..interval = const Duration(milliseconds: 250),
      );
      expect(doubleClickInterval, const Duration(milliseconds: 250));
    });

    test('keeps half a second when it cannot say', () async {
      await readDoubleClickInterval(FakeQuickLook());
      await readDoubleClickInterval(const NoQuickLook());
      expect(doubleClickInterval, const Duration(milliseconds: 500));
    });
  });

  test('NoQuickLook shows nothing', () async {
    const none = NoQuickLook();
    expect(await none.preview('/a'), isFalse);
    expect(await none.toggle('/a'), QuickLookToggle.failed);
  });

  // The main window and every conversation window ask for it the same way.
  group('platformQuickLook', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is the panel on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(platformQuickLook(), isA<MethodChannelQuickLook>());
    });

    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      test('is none on $platform', () {
        debugDefaultTargetPlatformOverride = platform;
        expect(platformQuickLook(), isA<NoQuickLook>());
      });
    }
  });
}
