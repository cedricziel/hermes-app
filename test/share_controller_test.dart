import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/share/plugin_share_inbox.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'support/fake_share_inbox.dart';

void main() {
  group('ShareController', () {
    test('starts empty', () {
      final controller = ShareController(FakeShareInbox());
      expect(controller.hasPending, isFalse);
      expect(controller.take(), isEmpty);
    });

    test('loads items that launched the app and resets the inbox', () async {
      final inbox = FakeShareInbox([const SharedText('hello')]);
      final controller = ShareController(inbox);

      await controller.start();

      expect(controller.hasPending, isTrue);
      expect(inbox.resetCount, 1);
    });

    test('collects items shared while the app is running', () async {
      final inbox = FakeShareInbox();
      final controller = ShareController(inbox);
      await controller.start();

      var notified = 0;
      controller.addListener(() => notified++);
      inbox.emit([const SharedText('a')]);
      inbox.emit([const SharedText('b')]);
      await Future<void>.delayed(Duration.zero);

      expect(notified, 2);
      expect(controller.take(), const [SharedText('a'), SharedText('b')]);
    });

    test('take hands items over once and clears them', () async {
      final controller = ShareController(
        FakeShareInbox([const SharedText('once')]),
      );
      await controller.start();

      expect(controller.take(), const [SharedText('once')]);
      expect(controller.hasPending, isFalse);
      expect(controller.take(), isEmpty);
    });

    test('the latest of several quotes wins', () async {
      final inbox = FakeShareInbox([
        const SharedQuote('first'),
        const SharedText('plain'),
      ]);
      final controller = ShareController(inbox);
      await controller.start();

      inbox.emit([const SharedQuote('second'), const SharedQuote('third')]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.take(), const [
        SharedText('plain'),
        SharedQuote('third'),
      ]);
    });

    test('a quote waits through setup and login like other items', () async {
      final inbox = FakeShareInbox();
      final controller = ShareController(inbox);
      await controller.start();

      inbox.emit([const SharedQuote('held')]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasPending, isTrue);
      expect(controller.take(), const [SharedQuote('held')]);
    });

    test('discardQuotes drops quotes and keeps other items', () async {
      final controller = ShareController(
        FakeShareInbox([const SharedQuote('private'), const SharedText('url')]),
      );
      await controller.start();

      controller.discardQuotes();

      expect(controller.take(), const [SharedText('url')]);
    });

    test('a quote waiting at sign-out is gone for the next user', () async {
      final signedOut = StreamController<void>.broadcast(sync: true);
      addTearDown(signedOut.close);
      final inbox = FakeShareInbox();
      final controller = ShareController(inbox, signedOut: signedOut.stream);
      await controller.start();
      inbox.emit([const SharedQuote('private')]);
      await Future<void>.delayed(Duration.zero);

      signedOut.add(null);

      expect(controller.hasPending, isFalse);
      expect(controller.take(), isEmpty);
    });

    test('keeps items pending until taken', () async {
      final inbox = FakeShareInbox();
      final controller = ShareController(inbox);
      await controller.start();

      inbox.emit([const SharedText('early')]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasPending, isTrue);
    });
  });

  group('sharedItemsFromMedia', () {
    test('maps text and url to SharedText', () {
      final items = sharedItemsFromMedia([
        SharedMediaFile(path: 'some note', type: SharedMediaType.text),
        SharedMediaFile(path: 'https://example.com', type: SharedMediaType.url),
      ]);

      expect(items, const [
        SharedText('some note'),
        SharedText('https://example.com'),
      ]);
    });

    test('maps images and files to SharedFile with a display name', () {
      final items = sharedItemsFromMedia([
        SharedMediaFile(
          path: '/tmp/share/photo.png',
          type: SharedMediaType.image,
          mimeType: 'image/png',
        ),
        SharedMediaFile(
          path: '/tmp/share/report.pdf',
          type: SharedMediaType.file,
        ),
      ]);

      expect(items, const [
        SharedFile(
          path: '/tmp/share/photo.png',
          name: 'photo.png',
          mimeType: 'image/png',
          isImage: true,
        ),
        SharedFile(path: '/tmp/share/report.pdf', name: 'report.pdf'),
      ]);
    });
  });
}
