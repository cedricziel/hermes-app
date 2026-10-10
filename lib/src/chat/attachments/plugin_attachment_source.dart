import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show KeyboardInsertedContent, MethodChannel, PlatformException;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../share/shared_item.dart';
import 'attachment_source.dart';

const _cameraUnavailable =
    'The camera is not available. Check that Hermes may use it in Settings.';
const _clipboardChannel = MethodChannel('hermes_app/clipboard');

Future<List<String>> _macosClipboardFiles() async =>
    await _clipboardChannel.invokeListMethod<String>('files') ?? const [];

Future<bool> _phoneClipboardHasFiles() async =>
    await _clipboardChannel.invokeMethod<bool>('hasFiles') ?? false;

/// Each file the iOS or Android runner copied off the clipboard: `path`, and
/// `name` and `mimeType` when it knows them.
Future<List<Map<String, Object?>>> _phoneClipboardRead() async => [
  for (final entry
      in await _clipboardChannel.invokeListMethod<Map<Object?, Object?>>(
            'read',
          ) ??
          const <Map<Object?, Object?>>[])
    entry.cast<String, Object?>(),
];

/// The real thing: `file_picker` for files, `image_picker` for the photo
/// library and the camera, `desktop_drop` for drops, and platform clipboard
/// readers for paste.
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
       _clipboardFiles =
           clipboardFiles ??
           ((platform ?? defaultTargetPlatform) == TargetPlatform.macOS
               ? _macosClipboardFiles
               : Pasteboard.files),
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
  bool get acceptsDrops => !_isPhone && !kIsWeb;

  @override
  Future<bool> hasFilesToPaste() async {
    if (kIsWeb) return false;
    try {
      if (_isPhone) return await _phoneClipboardHasFiles();
      // Desktops read the clipboard without asking, so a read is the check.
      final (image, paths) = await _desktopClipboard();
      return image != null || paths.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<List<SharedFile>> inserted(KeyboardInsertedContent content) async {
    final bytes = content.data;
    if (bytes == null || bytes.isEmpty) return const [];
    final extension = content.mimeType.split('/').last;
    return [await _pastedImage(bytes, extension: extension)];
  }

  @override
  Future<List<SharedFile>> pick(AttachOrigin origin) async {
    switch (origin) {
      case AttachOrigin.files:
        final files = await FilePicker.pickFiles();
        return [
          for (final file in files)
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
      if (_isPhone) {
        // Reading asks the user on iOS, so only when there is something.
        if (!await _phoneClipboardHasFiles()) return const [];
        return [
          for (final entry in await _phoneClipboardRead())
            if (entry['path'] case final String path) _phoneFile(entry, path),
        ];
      }
      final (image, paths) = await _desktopClipboard();
      if (image != null) return [await _pastedImage(image)];
      return paths.map(sharedFileFromPath).toList();
    } on Object {
      return const [];
    }
  }

  /// The clipboard's image, or else its paths that are files: a stale path
  /// falls through to text paste.
  Future<(Uint8List?, List<String>)> _desktopClipboard() async {
    final image = await _clipboardImage();
    if (image != null && image.isNotEmpty) return (image, const <String>[]);
    return (null, (await _clipboardFiles()).where(_isFile).toList());
  }

  SharedFile _phoneFile(Map<String, Object?> entry, String path) {
    final mimeType = entry['mimeType'] as String?;
    final name =
        entry['name'] as String? ??
        (mimeType?.startsWith('image/') == true
            ? pastedImageName(
                _clock(),
                extension: switch (_extension(path)) {
                  '' => 'png',
                  final ext => ext,
                },
              )
            : null);
    return sharedFileFromPath(path, name: name, mimeType: mimeType);
  }

  Future<SharedFile> _pastedImage(
    Uint8List bytes, {
    String extension = 'png',
  }) async {
    final dir = _pasteDirectory ?? Directory.systemTemp;
    final name = pastedImageName(_clock(), extension: extension);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return sharedFileFromPath(file.path);
  }

  @override
  Widget dropTarget({
    required Widget child,
    required ValueChanged<bool> onHover,
    required ValueChanged<List<SharedFile>> onDrop,
  }) {
    if (!acceptsDrops) return child;
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
String pastedImageName(DateTime at, {String extension = 'png'}) {
  String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
  return 'pasted-${pad(at.year, 4)}${pad(at.month)}${pad(at.day)}'
      '-${pad(at.hour)}${pad(at.minute)}${pad(at.second)}'
      '-${pad(at.millisecond, 3)}.$extension';
}

bool _isFile(String path) =>
    !FileSystemEntity.isDirectorySync(path) &&
    FileSystemEntity.isFileSync(path);

/// The lowercase extension of [path]'s last segment, or empty.
String _extension(String path) {
  final name = path.split(_separator).last;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
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
  final type = mimeType ?? _imageTypes[_extension(displayName)];
  return SharedFile(
    path: path,
    name: displayName,
    mimeType: type,
    isImage: type != null && type.startsWith('image/'),
  );
}
