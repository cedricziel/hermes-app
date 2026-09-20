import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/attachments/plugin_attachment_source.dart';
import 'package:hermes_app/src/share/shared_item.dart';

class _FakeImagePicker implements ImagePicker {
  _FakeImagePicker({this.camera, this.cameraError, this.library = const []});

  final XFile? camera;
  final Object? cameraError;
  final List<XFile> library;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.camera);
    final error = cameraError;
    if (error != null) throw error;
    return camera;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => library;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);

void main() {
  group('platform capabilities', () {
    test('phones offer files, the photo library and the camera', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        final source = PluginAttachmentSource(platform: platform);
        expect(source.origins, [
          AttachOrigin.files,
          AttachOrigin.photos,
          AttachOrigin.camera,
        ], reason: '$platform');
        expect(source.acceptsDropAndPaste, isFalse, reason: '$platform');
      }
    });

    test('desktops offer files only, without the camera', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        final source = PluginAttachmentSource(platform: platform);
        expect(source.origins, [AttachOrigin.files], reason: '$platform');
        expect(source.acceptsDropAndPaste, isTrue, reason: '$platform');
      }
    });
  });

  group('sharedFileFromPath', () {
    test('names the file after its last path segment', () {
      final file = sharedFileFromPath('/tmp/a/report.pdf');
      expect(file.name, 'report.pdf');
      expect(file.path, '/tmp/a/report.pdf');
      expect(file.isImage, isFalse);
    });

    test('knows Windows separators', () {
      expect(sharedFileFromPath(r'C:\Users\me\notes.txt').name, 'notes.txt');
    });

    test('marks images by extension and gives them a type', () {
      final file = sharedFileFromPath('/tmp/a/Photo.JPG');
      expect(file.isImage, isTrue);
      expect(file.mimeType, 'image/jpeg');
    });

    test('marks images by the type the plugin reports', () {
      final file = sharedFileFromPath(
        '/tmp/a/scan',
        name: 'scan',
        mimeType: 'image/tiff',
      );
      expect(file.isImage, isTrue);
      expect(file.mimeType, 'image/tiff');
    });

    test('prefers the display name the plugin reports', () {
      expect(
        sharedFileFromPath('/cache/1234', name: 'Holiday.pdf').name,
        'Holiday.pdf',
      );
    });
  });

  group('pasting', () {
    test('an image on the clipboard becomes a timestamped png file', () async {
      final dir = await Directory.systemTemp.createTemp('hermes-paste-test');
      addTearDown(() => dir.delete(recursive: true));
      final source = PluginAttachmentSource(
        platform: TargetPlatform.macOS,
        clipboardImage: () async => _png,
        clipboardFiles: () async => const [],
        pasteDirectory: dir,
        clock: () => DateTime(2026, 9, 20, 15, 30, 12, 34),
      );

      final pasted = await source.pasted();

      expect(pasted, hasLength(1));
      expect(pasted.single.name, 'pasted-20260920-153012-034.png');
      expect(pasted.single.mimeType, 'image/png');
      expect(pasted.single.isImage, isTrue);
      expect(File(pasted.single.path).readAsBytesSync(), _png);
      expect(pasted.single.path.startsWith(dir.path), isTrue);
    });

    test('files on the clipboard are attached by path', () async {
      final source = PluginAttachmentSource(
        platform: TargetPlatform.linux,
        clipboardImage: () async => null,
        clipboardFiles: () async => ['/home/me/a.pdf', '/home/me/b.png'],
      );

      final pasted = await source.pasted();

      expect(pasted.map((f) => f.name), ['a.pdf', 'b.png']);
      expect(pasted.map((f) => f.isImage), [false, true]);
    });

    test('an image wins over files', () async {
      final dir = await Directory.systemTemp.createTemp('hermes-paste-test');
      addTearDown(() => dir.delete(recursive: true));
      final source = PluginAttachmentSource(
        platform: TargetPlatform.macOS,
        clipboardImage: () async => _png,
        clipboardFiles: () async => ['/home/me/a.pdf'],
        pasteDirectory: dir,
      );

      final pasted = await source.pasted();

      expect(pasted.single.name, endsWith('.png'));
    });

    test('an empty clipboard yields nothing', () async {
      final source = PluginAttachmentSource(
        platform: TargetPlatform.macOS,
        clipboardImage: () async => Uint8List(0),
        clipboardFiles: () async => const [],
      );

      expect(await source.pasted(), isEmpty);
    });

    test('a clipboard the plugin cannot read yields nothing', () async {
      final source = PluginAttachmentSource(
        platform: TargetPlatform.macOS,
        clipboardImage: () async => throw StateError('no pasteboard'),
        clipboardFiles: () async => throw StateError('no pasteboard'),
      );

      expect(await source.pasted(), isEmpty);
    });

    test('paths that are folders are skipped', () async {
      final dir = await Directory.systemTemp.createTemp('hermes-paste-test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/note.txt')..writeAsStringSync('hi');
      final source = PluginAttachmentSource(
        platform: TargetPlatform.macOS,
        clipboardImage: () async => null,
        clipboardFiles: () async => [dir.path, file.path],
      );

      final pasted = await source.pasted();

      expect(pasted, [SharedFile(path: file.path, name: 'note.txt')]);
    });
  });

  group('the camera and the photo library', () {
    PluginAttachmentSource on(ImagePicker images) =>
        PluginAttachmentSource(platform: TargetPlatform.iOS, images: images);

    test('a photo from the library becomes an image attachment', () async {
      final source = on(
        _FakeImagePicker(
          library: [XFile('/cache/IMG_1.heic'), XFile('/cache/IMG_2.jpg')],
        ),
      );

      final photos = await source.pick(AttachOrigin.photos);

      expect(photos.map((f) => f.name), ['IMG_1.heic', 'IMG_2.jpg']);
      expect(photos.every((f) => f.isImage), isTrue);
    });

    test('a photo from the camera becomes an image attachment', () async {
      final source = on(_FakeImagePicker(camera: XFile('/cache/scaled_1.jpg')));

      final photos = await source.pick(AttachOrigin.camera);

      expect(photos.single.name, 'scaled_1.jpg');
      expect(photos.single.isImage, isTrue);
    });

    test('cancelling the camera attaches nothing', () async {
      expect(await on(_FakeImagePicker()).pick(AttachOrigin.camera), isEmpty);
    });

    test('a denied camera says it is not available', () async {
      final source = on(
        _FakeImagePicker(
          cameraError: PlatformException(code: 'camera_access_denied'),
        ),
      );

      await expectLater(
        source.pick(AttachOrigin.camera),
        throwsA(
          isA<AttachmentUnavailable>().having(
            (e) => e.message,
            'message',
            contains('camera is not available'),
          ),
        ),
      );
    });
  });

  group('dropping', () {
    /// Delivers a drag the way the macOS side of `desktop_drop` reports it.
    Future<void> deliver(WidgetTester tester, String method, Object? args) {
      const codec = StandardMethodCodec();
      return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'desktop_drop',
        codec.encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
    }

    testWidgets('files dropped on the chat are reported, folders are not', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('hermes-drop-test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/report.pdf')..writeAsStringSync('%PDF');
      final hover = <bool>[];
      final dropped = <List<SharedFile>>[];
      final source = PluginAttachmentSource(platform: TargetPlatform.macOS);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: source.dropTarget(
            onHover: hover.add,
            onDrop: dropped.add,
            child: const SizedBox.expand(),
          ),
        ),
      );

      await deliver(tester, 'entered', [1.0, 1.0]);
      expect(hover, [true]);

      await deliver(tester, 'exited', null);
      expect(hover, [true, false]);

      await deliver(tester, 'entered', [1.0, 1.0]);
      await deliver(tester, 'performOperation_macos', [
        {'path': file.path, 'isDirectory': false},
        {'path': dir.path, 'isDirectory': true},
      ]);
      expect(dropped, [
        [SharedFile(path: file.path, name: 'report.pdf')],
      ]);
    });

    testWidgets('a phone has no drop target', (tester) async {
      final source = PluginAttachmentSource(platform: TargetPlatform.iOS);
      const child = SizedBox();

      final wrapped = source.dropTarget(
        onHover: (_) {},
        onDrop: (_) {},
        child: child,
      );

      expect(identical(wrapped, child), isTrue);
    });
  });
}
