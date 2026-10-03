import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/share/macos_share_inbox.dart';
import 'package:hermes_app/src/share/plugin_share_inbox.dart';
import 'package:hermes_app/src/share/share_inbox.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  group('createPlatformShareInbox', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    ShareInbox inboxFor(TargetPlatform platform) {
      debugDefaultTargetPlatformOverride = platform;
      return createPlatformShareInbox();
    }

    test('uses the share intent plugin on iOS', () {
      expect(inboxFor(TargetPlatform.iOS), isA<PluginShareInbox>());
    });

    test('uses the share intent plugin on Android', () {
      expect(inboxFor(TargetPlatform.android), isA<PluginShareInbox>());
    });

    test('uses the share extension handoff on macOS', () {
      expect(inboxFor(TargetPlatform.macOS), isA<MacosShareInbox>());
    });

    test('has no share target on Linux', () {
      expect(inboxFor(TargetPlatform.linux), isA<NoopShareInbox>());
    });

    test('has no share target on Windows', () {
      expect(inboxFor(TargetPlatform.windows), isA<NoopShareInbox>());
    });
  });

  group('NoopShareInbox', () {
    test('never delivers anything', () async {
      const inbox = NoopShareInbox();

      expect(await inbox.initialItems(), isEmpty);
      expect(await inbox.items.toList(), isEmpty);
    });
  });

  group('PluginShareInbox', () {
    late ReceiveSharingIntent original;
    late StreamController<List<SharedMediaFile>> shares;

    setUp(() {
      original = ReceiveSharingIntent.instance;
      shares = StreamController.broadcast();
    });

    tearDown(() async {
      await shares.close();
      ReceiveSharingIntent.instance = original;
    });

    void launchedWith(List<SharedMediaFile> media) {
      ReceiveSharingIntent.setMockValues(
        initialMedia: media,
        mediaStream: shares.stream,
      );
    }

    test('maps the media that launched the app', () async {
      launchedWith([
        SharedMediaFile(path: 'hello', type: SharedMediaType.text),
        SharedMediaFile(path: '/tmp/a.png', type: SharedMediaType.image),
      ]);

      final items = await PluginShareInbox().initialItems();

      expect(items, const [
        SharedText('hello'),
        SharedFile(path: '/tmp/a.png', name: 'a.png', isImage: true),
      ]);
    });

    test('maps media shared while the app runs', () async {
      launchedWith(const []);
      final received = <List<SharedItem>>[];
      final sub = PluginShareInbox().items.listen(received.add);

      shares.add([
        SharedMediaFile(path: 'https://example.com', type: SharedMediaType.url),
      ]);
      await pumpEventQueue();
      await sub.cancel();

      expect(received, [
        const [SharedText('https://example.com')],
      ]);
    });

    test('reset keeps launch media from being delivered again', () async {
      launchedWith([SharedMediaFile(path: 'once', type: SharedMediaType.text)]);
      final inbox = PluginShareInbox();

      await inbox.reset();

      expect(await inbox.initialItems(), isEmpty);
    });
  });
}
