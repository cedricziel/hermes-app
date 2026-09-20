import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../share/shared_item.dart';
import 'attachment_source.dart';

const _cameraUnavailable =
    'The camera is not available. Check that Hermes may use it in Settings.';

/// The real thing: `file_picker` for files, `image_picker` for the photo
/// library and the camera, `desktop_drop` for drops and `pasteboard` for the
/// clipboard.
class PluginAttachmentSource implements AttachmentSource {
  /// The optional arguments stand in for the plugins and the platform, so the
  /// logic around them can be tested.
  PluginAttachmentSource({
    TargetPlatform? platform,
    Future<Uint8List?> Function()? clipboardImage,
    Future<List<String>> Function()? clipboardFiles,
    this._pasteDirectory,
    DateTime Function()? clock,
    ImagePicker? images,
  }) : _platform = platform ?? defaultTargetPlatform,
       _clipboardImage = clipboardImage ?? (() => Pasteboard.image),
       _clipboardFiles = clipboardFiles ?? Pasteboard.files,
       _clock = clock ?? DateTime.now,
       _images = images ?? ImagePicker();

  final TargetPlatform _platform;
  final Future<Uint8List?> Function() _clipboardImage;
  final Future<List<String>> Function() _clipboardFiles;
  final Directory? _pasteDirectory;
  final DateTime Function() _clock;
  final ImagePicker _images;

  bool get _isPhone =>
      _platform == TargetPlatform.iOS || _platform == TargetPlatform.android;

  @override
  List<AttachOrigin> get origins => [
    AttachOrigin.files,
    if (_isPhone) ...[AttachOrigin.photos, AttachOrigin.camera],
  ];

  @override
  bool get acceptsDropAndPaste => !_isPhone && !kIsWeb;

  @override
  Future<List<SharedFile>> pick(AttachOrigin origin) async {
    switch (origin) {
      case AttachOrigin.files:
        final result = await FilePicker.pickFiles(allowMultiple: true);
        return [
          for (final file in result?.files ?? const <PlatformFile>[])
            if (file.path != null)
              sharedFileFromPath(file.path!, name: file.name),
        ];
      case AttachOrigin.photos:
        final photos = await _images.pickMultiImage();
        return photos.map(_fromPicked).toList();
      case AttachOrigin.camera:
        try {
          final photo = await _images.pickImage(source: ImageSource.camera);
          return photo == null ? const [] : [_fromPicked(photo)];
        } on PlatformException {
          throw const AttachmentUnavailable(_cameraUnavailable);
        }
    }
  }

  @override
  Future<List<SharedFile>> pasted() async {
    try {
      final image = await _clipboardImage();
      if (image != null && image.isNotEmpty) return [await _pastedImage(image)];
      return [
        for (final path in await _clipboardFiles())
          if (!FileSystemEntity.isDirectorySync(path)) sharedFileFromPath(path),
      ];
    } on Object {
      return const [];
    }
  }

  Future<SharedFile> _pastedImage(Uint8List bytes) async {
    final dir = _pasteDirectory ?? Directory.systemTemp;
    final file = File('${dir.path}/${pastedImageName(_clock())}');
    await file.writeAsBytes(bytes, flush: true);
    return sharedFileFromPath(file.path);
  }

  @override
  Widget dropTarget({
    required Widget child,
    required ValueChanged<bool> onHover,
    required ValueChanged<List<SharedFile>> onDrop,
  }) {
    if (!acceptsDropAndPaste) return child;
    return DropTarget(
      onDragEntered: (_) => onHover(true),
      onDragExited: (_) => onHover(false),
      onDragDone: (details) => onDrop([
        for (final item in details.files)
          if (item is! DropItemDirectory &&
              !FileSystemEntity.isDirectorySync(item.path))
            _fromPicked(item),
      ]),
      child: child,
    );
  }
}

/// `pasted-20260920-153012-034.png`: sortable, and unique per paste.
String pastedImageName(DateTime at) {
  String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
  return 'pasted-${pad(at.year, 4)}${pad(at.month)}${pad(at.day)}'
      '-${pad(at.hour)}${pad(at.minute)}${pad(at.second)}'
      '-${pad(at.millisecond, 3)}.png';
}

SharedFile _fromPicked(XFile file) => sharedFileFromPath(
  file.path,
  name: file.name.isEmpty ? null : file.name,
  mimeType: file.mimeType,
);

final _separator = RegExp(r'[/\\]');

const _imageTypes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'bmp': 'image/bmp',
  'tif': 'image/tiff',
  'tiff': 'image/tiff',
};

/// A [SharedFile] for a path a plugin handed back. [name] defaults to the last
/// path segment; the type comes from [mimeType] or, for images, the extension.
SharedFile sharedFileFromPath(String path, {String? name, String? mimeType}) {
  final displayName = name ?? path.split(_separator).last;
  final dot = displayName.lastIndexOf('.');
  final extension = dot < 0 ? '' : displayName.substring(dot + 1).toLowerCase();
  final type = mimeType ?? _imageTypes[extension];
  return SharedFile(
    path: path,
    name: displayName,
    mimeType: type,
    isImage: type != null && type.startsWith('image/'),
  );
}
