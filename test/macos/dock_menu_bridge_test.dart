import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/dock/dock_menu_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hermes_app/app');
  final calls = <MethodCall>[];
  Exception? failure;

  setUp(() {
    calls.clear();
    failure = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (failure != null) throw failure!;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  });

  Future<void> fromRunner(String method, [Object? arguments]) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'hermes_app/app',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            (_) {},
          );

  test('update sends the state and the chats to the runner', () async {
    await DockMenuBridge(
      enabled: true,
    ).update(DockMenuState.ready, [(id: 'a', profile: 'work', title: 'One')]);

    expect(calls.single.method, 'dockMenu');
    expect(calls.single.arguments, {
      'state': 'ready',
      'chats': [
        {'id': 'a', 'profile': 'work', 'title': 'One'},
      ],
    });
  });

  test('update swallows what a missing or failing runner throws', () async {
    final bridge = DockMenuBridge(enabled: true);

    failure = PlatformException(code: 'x');
    await bridge.update(DockMenuState.off, const []);
    failure = MissingPluginException();
    await bridge.update(DockMenuState.off, const []);
  });

  test('does nothing where it is not enabled', () async {
    final bridge = DockMenuBridge(enabled: false);

    await bridge.update(DockMenuState.ready, const []);

    expect(calls, isEmpty);
    expect(await bridge.actions.toList(), isEmpty);
  });

  test(
    'actions pass on the runner\'s choices and skip malformed ones',
    () async {
      final seen = <DockMenuAction>[];
      final sub = DockMenuBridge(enabled: true).actions.listen(seen.add);
      addTearDown(sub.cancel);

      await fromRunner('dockNewChat');
      await fromRunner('dockOpenChat', {'id': 'a', 'profile': 'work'});
      await fromRunner('dockOpenChat', {'id': 'a'});
      await fromRunner('dockOpenChat', 'nonsense');
      await fromRunner('windowless', true);
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(2));
      expect(seen[0], isA<DockNewChat>());
      expect(seen[1], isA<DockOpenChat>());
      expect((seen[1] as DockOpenChat).id, 'a');
      expect((seen[1] as DockOpenChat).profile, 'work');
    },
  );
}
