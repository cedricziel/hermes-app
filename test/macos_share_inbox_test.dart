import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/share/macos_share_inbox.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

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

  group('Ask Hermes quotes', () {
    test('an entry with the ask intent becomes a SharedQuote', () async {
      pending = [
        {'type': 'text', 'text': 'an error', 'intent': 'ask'},
        {'type': 'text', 'text': 'cut', 'intent': 'ask', 'truncated': true},
      ];

      expect(await MacosShareInbox().initialItems(), const [
        SharedQuote('an error'),
        SharedQuote('cut', truncated: true),
      ]);
    });

    test('an unknown intent stays plain shared text', () async {
      pending = [
        {'type': 'text', 'text': 'later format', 'intent': 'summon'},
      ];

      expect(await MacosShareInbox().initialItems(), const [
        SharedText('later format'),
      ]);
    });

    test('a quote with no usable text yields no item', () async {
      pending = [
        {'type': 'text', 'text': '', 'intent': 'ask'},
        {'type': 'text', 'text': '  \n ', 'intent': 'ask'},
        {'type': 'text', 'intent': 'ask'},
      ];

      expect(await MacosShareInbox().initialItems(), isEmpty);
    });

    test('a dropped entry yields no item', () async {
      pending = [
        {'type': 'dropped', 'reason': 'empty'},
      ];

      expect(await MacosShareInbox().initialItems(), isEmpty);
    });

    test('a quote delivered while running reaches the stream', () async {
      final inbox = MacosShareInbox();
      final received = <List<SharedItem>>[];
      final subscription = inbox.items.listen(received.add);

      pending = [
        {'type': 'text', 'text': 'selected', 'intent': 'ask'},
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
        const [SharedQuote('selected')],
      ]);
      await subscription.cancel();
    });

    group('breadcrumbs', () {
      late BreadcrumbTrail trail;
      late MacosShareInbox inbox;

      setUp(() {
        trail = BreadcrumbTrail(capacity: 20);
        inbox = MacosShareInbox(breadcrumbs: Breadcrumbs.of(trail));
      });

      test('a quote that launched the app is recorded as launched', () async {
        pending = [
          {'type': 'text', 'text': 'secret words', 'intent': 'ask'},
        ];

        await inbox.initialItems();

        final crumb = trail.recent.single;
        expect(crumb.name, 'service.ask.received');
        expect(crumb.attributes, {'launched': true, 'truncated': false});
      });

      test('a quote delivered to a running app is not launched', () async {
        final subscription = inbox.items.listen((_) {});
        pending = [
          {
            'type': 'text',
            'text': 'secret words',
            'intent': 'ask',
            'truncated': true,
          },
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

        expect(trail.recent.single.attributes, {
          'launched': false,
          'truncated': true,
        });
        await subscription.cancel();
      });

      test('a drop records only its reason', () async {
        pending = [
          {'type': 'dropped', 'reason': 'no_text'},
          {'type': 'dropped', 'reason': 'My Secret Document.pdf'},
        ];

        await inbox.initialItems();

        expect(
          trail.recent.map((c) => c.name),
          everyElement('service.ask.dropped'),
        );
        expect(trail.recent.map((c) => c.attributes['reason']), [
          'no_text',
          'unknown',
        ]);
      });

      test('no crumb holds the text', () async {
        pending = [
          {'type': 'text', 'text': 'secret words', 'intent': 'ask'},
        ];

        await inbox.initialItems();

        for (final crumb in trail.recent) {
          expect(crumb.toString(), isNot(contains('secret')));
        }
      });
    });
  });
}
