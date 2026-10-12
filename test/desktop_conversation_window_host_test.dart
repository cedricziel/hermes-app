import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const plugin = MethodChannel('mixin.one/desktop_multi_window');
  const native = MethodChannel('hermes_app/window');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> changed() => messenger.handlePlatformMessage(
    plugin.name,
    plugin.codec.encodeMethodCall(const MethodCall('onWindowsChanged')),
    (_) {},
  );

  tearDown(() {
    messenger.setMockMethodCallHandler(plugin, null);
    messenger.setMockMethodCallHandler(native, null);
  });

  test('native close failures reach the session teardown barrier', () async {
    messenger.setMockMethodCallHandler(native, (call) async {
      throw PlatformException(code: 'close_failed');
    });
    final host = DesktopConversationWindowHost();
    await expectLater(host.closeAll(), throwsA(isA<PlatformException>()));
    await expectLater(host.close('w1'), throwsA(isA<PlatformException>()));
  });

  test('held inventory cannot remove a newly created native window', () async {
    final started = Completer<void>();
    final oldInventory = Completer<void>();
    var queries = 0;
    messenger.setMockMethodCallHandler(plugin, (call) async {
      switch (call.method) {
        case 'getAllWindows':
          if (++queries == 1) {
            started.complete();
            await oldInventory.future;
            return <Object>[];
          }
          return [
            {'windowId': 'fresh', 'windowArgument': ''},
          ];
        case 'createWindow':
          return 'fresh';
      }
      return null;
    });
    final host = DesktopConversationWindowHost();
    final observed = <Set<String>>[];
    final subscription = host.liveWindows.listen(observed.add);
    addTearDown(subscription.cancel);
    await changed();
    await started.future;
    await host.create(
      const ConversationWindowArgs(
        threadId: 's1',
        profile: null,
        title: 'Test',
        baseUrl: 'https://hermes.test',
        authRequired: true,
      ),
    );
    await changed();
    oldInventory.complete();
    await pumpEventQueue();
    expect(observed, isNotEmpty);
    expect(observed.every((ids) => ids.contains('fresh')), isTrue);
  });
}
