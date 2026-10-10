import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_model.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_menu.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_tray.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hermes_app/menu_bar_extra');
  final calls = <MethodCall>[];
  late ChannelMenuBarTray tray;

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
    tray = ChannelMenuBarTray();
  });

  Future<void> fromRunner(String method, [Object? arguments]) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            (_) {},
          );

  test('sends the icon state and the whole menu in one call', () async {
    await tray.update(
      visible: true,
      state: MenuBarIconState.attention,
      items: const [
        MenuBarItem('Needs you', enabled: false),
        MenuBarItem(
          'rm -rf build',
          children: [MenuBarItem('Deny', key: 'item-0')],
        ),
        MenuBarItem.separator(),
        MenuBarItem('Quit Hermes', key: 'item-1'),
      ],
    );

    expect(calls.single.method, 'update');
    expect(calls.single.arguments, {
      'visible': true,
      'urgent': false,
      'state': 'attention',
      'items': [
        {
          'title': 'Needs you',
          'key': null,
          'enabled': false,
          'separator': false,
        },
        {
          'title': 'rm -rf build',
          'key': null,
          'enabled': true,
          'separator': false,
          'children': [
            {
              'title': 'Deny',
              'key': 'item-0',
              'enabled': true,
              'separator': false,
            },
          ],
        },
        {'title': '', 'key': null, 'enabled': false, 'separator': true},
        {
          'title': 'Quit Hermes',
          'key': 'item-1',
          'enabled': true,
          'separator': false,
        },
      ],
    });
  });

  test('marks an update the open menu must not outlast', () async {
    await tray.update(
      visible: true,
      state: MenuBarIconState.idle,
      items: const [],
      urgent: true,
    );

    expect((calls.single.arguments as Map)['urgent'], isTrue);
  });

  test('passes on the picks and openings the runner reports', () async {
    final picks = <String>[];
    var opened = 0;
    final subscriptions = [
      tray.selections.listen(picks.add),
      tray.opened.listen((_) => opened++),
    ];
    addTearDown(() {
      for (final s in subscriptions) {
        s.cancel();
      }
    });

    await fromRunner('opened');
    await fromRunner('selected', 'item-3');
    await Future<void>.delayed(Duration.zero);

    expect(opened, 1);
    expect(picks, ['item-3']);
  });
}
