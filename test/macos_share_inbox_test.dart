import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/share/macos_share_inbox.dart';
import 'package:hermes_app/src/share/shared_item.dart';

const _channel = MethodChannel('hermes_app/share');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Object?> pending;
  var takeCalls = 0;

  setUp(() {
    pending = [];
    takeCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method != 'take') return null;
          takeCalls++;
          final result = List<Object?>.of(pending);
          pending = [];
          return result;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test(
    'initialItems maps text and file entries from the native side',
    () async {
      pending = [
        {'type': 'text', 'text': 'https://example.com'},
        {
          'type': 'file',
          'path': '/group/share/photo.png',
          'name': 'photo.png',
          'mimeType': 'image/png',
          'isImage': true,
        },
        {'type': 'file', 'path': '/group/share/notes.pdf', 'name': 'notes.pdf'},
      ];

      final items = await MacosShareInbox().initialItems();

      expect(items, const [
        SharedText('https://example.com'),
        SharedFile(
          path: '/group/share/photo.png',
          name: 'photo.png',
          mimeType: 'image/png',
          isImage: true,
        ),
        SharedFile(path: '/group/share/notes.pdf', name: 'notes.pdf'),
      ]);
    },
  );

  test('initialItems ignores entries it does not understand', () async {
    pending = [
      {'type': 'video-call'},
      {'type': 'text'},
      'nonsense',
      {'type': 'text', 'text': 'kept'},
    ];

    expect(await MacosShareInbox().initialItems(), const [SharedText('kept')]);
  });

  test(
    'a native "shared" call pulls the pending items into the stream',
    () async {
      final inbox = MacosShareInbox();
      final received = <List<SharedItem>>[];
      final subscription = inbox.items.listen(received.add);

      pending = [
        {'type': 'text', 'text': 'shared while running'},
      ];
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('shared'),
            ),
            (_) {},
          );
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        const [SharedText('shared while running')],
      ]);
      expect(takeCalls, 1);
      await subscription.cancel();
    },
  );

  test('a "shared" call with nothing pending emits nothing', () async {
    final inbox = MacosShareInbox();
    final received = <List<SharedItem>>[];
    final subscription = inbox.items.listen(received.add);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('shared'),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(received, isEmpty);
    await subscription.cancel();
  });

  test('initialItems is empty when the native side is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);

    expect(await MacosShareInbox().initialItems(), isEmpty);
  });
}
