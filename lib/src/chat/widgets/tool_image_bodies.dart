import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart' show wellFormedText;
import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import '../media/media_source.dart' show MediaFailure, MediaFetchException;
import '../media/media_store.dart';
import '../page_link.dart';
import '../tool_image_loader.dart';
import '../tool_result.dart';
import 'code_tool_body.dart' show CodeNote, CodeNoteTone, CodeNoteView;
import 'image_viewer.dart';
import 'link_tool_bodies.dart' show launchPage;
import 'tool_image_gallery.dart';
import 'tool_image_tile.dart';

/// Under this many pixels on a side an image is an icon or a tracking pixel.
const _smallestShown = 32;

/// One image a tool result named: a [path] on the Hermes server, which loads
/// through [MediaStore] with the app's own credentials at once, or an address
/// on another host ([uri]), which loads only after a tap.
typedef ToolImageItem = ({
  Uri? uri,
  String path,
  String alt,
  int width,
  int height,
});

/// What an opened `browser_get_images`, `image_generate` or `browser_vision`
/// call shows: the images as a gallery, and what the tool said about them.
/// Each parser answers null for a result that is not the shape it expects,
/// which leaves the card its generic input and result.
class ToolImagesBody extends StatefulWidget {
  const ToolImagesBody({
    super.key,
    required this.items,
    this.hidden = 0,
    this.single = false,
    this.generating = false,
    this.aspectRatio = 4 / 3,
    this.error,
    this.analysis = '',
  });

  final List<ToolImageItem> items;

  /// How many images under 32 px the parser left out.
  final int hidden;
  final bool single;

  /// `image_generate` while it runs: a skeleton in [aspectRatio].
  final bool generating;
  final double aspectRatio;

  /// The server's words when the tool made no image.
  final String? error;

  /// `browser_vision`: what Hermes saw in the screenshot.
  final String analysis;

  static Widget? getImages(ToolCall call) => _parsed(call, _getImages);
  static Widget? generate(ToolCall call) => _parsed(call, _generate);
  static Widget? vision(ToolCall call) => _parsed(call, _vision);

  @override
  State<ToolImagesBody> createState() => _ToolImagesBodyState();
}

class _ToolImagesBodyState extends State<ToolImagesBody> {
  var _states = <ToolImageState>[];
  final _fetched = <int, Uint8List>{};
  ToolImageLoader? _loader;

  /// Counts the times the items changed, so a load that was asked for the old
  /// items does not write into the new ones.
  var _epoch = 0;

  @override
  void initState() {
    super.initState();
    _loader = context.read<ToolImageLoader?>();
    _loader?.changes.addListener(_loaderChanged);
    _reset();
  }

  @override
  void didUpdateWidget(ToolImagesBody old) {
    super.didUpdateWidget(old);
    // A running call that finishes keeps this State with its new items.
    if (!listEquals(old.items, widget.items)) _reset();
  }

  @override
  void dispose() {
    _loader?.changes.removeListener(_loaderChanged);
    super.dispose();
  }

  void _reset() {
    _epoch++;
    _fetched.clear();
    final items = widget.items;
    _states = [
      for (final item in items)
        if (item.uri == null)
          ToolImageState.loading
        else if (item.uri!.scheme == 'https')
          ToolImageState.idle
        else
          ToolImageState.insecure,
    ];
    for (var i = 0; i < items.length; i++) {
      if (items[i].uri == null) _fetch(i);
    }
  }

  /// The loader dropped bytes (App Lock, sign-out, its memory budget): a tile
  /// that showed one waits for a tap again.
  void _loaderChanged() {
    final loader = _loader;
    if (loader == null) return;
    setState(() {
      for (var i = 0; i < _states.length; i++) {
        final uri = widget.items[i].uri;
        if (_states[i] == ToolImageState.loaded &&
            uri != null &&
            loader.bytesOf(uri) == null) {
          _states[i] = ToolImageState.idle;
        }
      }
    });
  }

  Future<void> _fetch(int i) async {
    final item = widget.items[i];
    final epoch = _epoch;
    final store = context.read<MediaStore?>();
    final loader = _loader;
    var next = ToolImageState.loaded;
    try {
      if (item.uri == null) {
        if (store == null) throw const MediaFetchException(MediaFailure.failed);
        _fetched[i] = await store.image(item.path);
      } else {
        if (loader == null) {
          throw const ToolImageException(ToolImageOutcome.failed);
        }
        await loader.load(item.uri!);
      }
    } on ToolImageException catch (e) {
      next = switch (e.outcome) {
        ToolImageOutcome.tooLarge => ToolImageState.tooLarge,
        ToolImageOutcome.insecure => ToolImageState.insecure,
        _ => ToolImageState.failed,
      };
    } on MediaFetchException {
      next = ToolImageState.failed;
    }
    if (mounted && epoch == _epoch) setState(() => _states[i] = next);
  }

  void _load(int i) {
    setState(() => _states[i] = ToolImageState.loading);
    _fetch(i);
  }

  void _open(int i, String name) {
    final item = widget.items[i];
    final store = context.read<MediaStore?>();
    final loader = _loader;
    final bytes = _fetched[i];
    final image = item.uri != null
        ? loader?.imageFor(item.uri!)
        : bytes == null
        ? null
        : MemoryImage(bytes);
    if (image == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImageViewerPage(
          image: image,
          name: name,
          // A remote image is never saved: it exists only in memory.
          onSave: bytes == null || store == null
              ? null
              : () => store.save(name, bytes),
        ),
      ),
    );
  }

  void Function()? _tapOf(int i, String name) {
    final item = widget.items[i];
    return switch (_states[i]) {
      ToolImageState.idle || ToolImageState.failed => () => _load(i),
      ToolImageState.loaded => () => _open(i, name),
      ToolImageState.insecure ||
      ToolImageState.tooLarge => () => launchPage(item.uri!),
      _ => null,
    };
  }

  ImageProvider Function(int)? _imageOf(int i) {
    final item = widget.items[i];
    if (_states[i] != ToolImageState.loaded) return null;
    final uri = item.uri;
    final bytes = uri == null ? _fetched[i] : _loader?.bytesOf(uri);
    if (bytes == null) return null;
    return (width) =>
        (uri == null ? null : _loader?.imageFor(uri, width: width)) ??
        ResizeImage.resizeIfNeeded(width, null, MemoryImage(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = widget.items;
    final tiles = <ToolImageTile>[
      if (widget.generating)
        ToolImageTile(
          state: ToolImageState.generating,
          aspectRatio: widget.aspectRatio,
        ),
      for (var i = 0; i < items.length; i++)
        () {
          final item = items[i];
          final link = item.uri == null ? null : PageLink.parse('${item.uri}');
          final name = item.alt.trim().isEmpty
              ? l10n.chatWidgetsImageNumbered(i + 1, items.length)
              : item.alt;
          return ToolImageTile(
            state: _states[i],
            alt: item.alt,
            name: name,
            size: item.width > 0 && item.height > 0
                ? '${item.width} × ${item.height}'
                : '',
            host: link?.host ?? '',
            image: _imageOf(i),
            aspectRatio: widget.aspectRatio,
            onTap: _tapOf(i, name),
          );
        }(),
    ];
    final idle = [
      for (var i = 0; i < items.length; i++)
        if (_states[i] == ToolImageState.idle) i,
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.error != null)
            CodeNoteView(
              CodeNote(
                CodeNoteTone.error,
                l10n.chatWidgetsImageFailed,
                detail: widget.error!,
              ),
            )
          else
            ToolImageGallery(
              tiles: tiles,
              hidden: widget.hidden,
              single: widget.single || widget.generating,
              onLoadAll: idle.isEmpty
                  ? null
                  : (shown) {
                      for (final i in idle.where((i) => i < shown)) {
                        _load(i);
                      }
                    },
            ),
          if (widget.analysis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.chatWidgetsImageSaw,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: context.hermesColors.subtleText,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              wellFormedText(widget.analysis),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// The parse of a call, kept: the card asks on every build, closed ones too.
Widget? _parsed(ToolCall call, ToolImagesBody? Function(ToolCall) parse) =>
    (_cache[call] ??= _Cached(parse(call))).body;

final _cache = Expando<_Cached>();

class _Cached {
  const _Cached(this.body);

  final ToolImagesBody? body;
}

String _string(Object? value) => value is String ? value.trim() : '';

/// A size of 0 is an image that has not loaded: kept.
bool _tooSmall(int side) => side > 0 && side < _smallestShown;

int _size(Object? value) => value is num ? value.toInt() : 0;

final _windowsPath = RegExp(r'^[A-Za-z]:[\\/]');

bool _isServerPath(String value) =>
    value.startsWith('/') || _windowsPath.hasMatch(value);

/// An address as an item, or null for one the app does not load: no web
/// address, or one with a user name or password in it.
ToolImageItem? _remote(
  Object? src, {
  String alt = '',
  int width = 0,
  int height = 0,
}) {
  final link = PageLink.parse(_string(src));
  return link.kind == PageLinkKind.web
      ? (uri: link.uri, path: '', alt: alt, width: width, height: height)
      : null;
}

ToolImagesBody? _getImages(ToolCall call) {
  if (call.preparing) return null;
  final result = toolResultMap(call);
  if (result == null || result['success'] != true) return null;
  final rows = result['images'];
  if (rows is! List) return null;
  final shown = <ToolImageItem>[];
  var hidden = 0;
  for (final row in rows) {
    if (row is! Map) continue;
    final (width, height) = (_size(row['width']), _size(row['height']));
    final item = _remote(
      row['src'],
      alt: _string(row['alt']),
      width: width,
      height: height,
    );
    if (item == null) continue;
    if (_tooSmall(width) || _tooSmall(height)) {
      hidden++;
    } else {
      shown.add(item);
    }
  }
  if (rows.isNotEmpty && shown.isEmpty && hidden == 0) return null;
  return ToolImagesBody(items: shown, hidden: hidden);
}

double _aspectOf(Object? asked) => switch (asked) {
  'portrait' => 3 / 4,
  'square' => 1,
  _ => 16 / 9,
};

ToolImagesBody? _generate(ToolCall call) {
  if (call.preparing) return null;
  final aspect = _aspectOf(call.args?['aspect_ratio']);
  final result = toolResultMap(call);
  if (result == null) {
    return call.resultData == null &&
            call.result.isEmpty &&
            call.status == ToolCallStatus.running
        ? ToolImagesBody(
            items: const [],
            generating: true,
            single: true,
            aspectRatio: aspect,
          )
        : null;
  }
  final image = _string(result['image']);
  final error = _string(result['error']);
  if (result['success'] == false || error.isNotEmpty) {
    return ToolImagesBody(items: const [], single: true, error: error);
  }
  final item = _isServerPath(image)
      ? (uri: null, path: image, alt: '', width: 0, height: 0)
      : _remote(image);
  return result['success'] == true && item != null
      ? ToolImagesBody(items: [item], single: true, aspectRatio: aspect)
      : null;
}

ToolImagesBody? _vision(ToolCall call) {
  if (call.preparing) return null;
  final result = toolResultMap(call);
  final path = _string(result?['screenshot_path']);
  if (result == null || result['success'] != true || !_isServerPath(path)) {
    return null;
  }
  return ToolImagesBody(
    items: [(uri: null, path: path, alt: '', width: 0, height: 0)],
    single: true,
    aspectRatio: 16 / 9,
    analysis: _string(result['analysis']),
  );
}
