import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../l10n/l10n.dart';
import '../../settings/report_bug_link.dart' show LinkOpener;
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/adaptive_tab_bar.dart';
import '../../widgets/markdown_links.dart';
import '../../theme/platform_chrome.dart';
import 'files_metrics.dart';
import 'files_notes.dart';
import 'files_questions.dart';
import 'markdown_inert.dart';

/// A text file the server cut short: how much came and how much there is.
class FileTruncation {
  const FileTruncation({required this.shownBytes, required this.totalBytes});

  final int shownBytes;
  final int totalBytes;
}

/// What a preview shows.
sealed class FilePreviewContent {
  const FilePreviewContent();
}

/// A plain text file.
class TextContent extends FilePreviewContent {
  const TextContent(this.text, {this.truncation});

  final String text;
  final FileTruncation? truncation;
}

/// A code file. Plain monospace until the code colours arrive.
class CodeContent extends FilePreviewContent {
  const CodeContent(this.text, {this.truncation});

  final String text;
  final FileTruncation? truncation;
}

/// A Markdown file, rendered or as its source.
class MarkdownContent extends FilePreviewContent {
  const MarkdownContent(this.text, {this.showSource = false, this.truncation});

  final String text;
  final bool showSource;
  final FileTruncation? truncation;
}

/// A picture, already on this device.
class ImageContent extends FilePreviewContent {
  const ImageContent(this.image, {required this.label});

  final ImageProvider image;

  /// The accessible name of the picture, its file name.
  final String label;
}

/// The content of a preview, whatever its kind: text, code, Markdown or an
/// image. A PDF or other file has no inline preview (see `FileDetailsView`).
class FilePreviewView extends StatelessWidget {
  const FilePreviewView({
    super.key,
    required this.content,
    this.onDownloadFull,
    this.openLink,
    this.confirmLink,
  });

  final FilePreviewContent content;
  final VoidCallback? onDownloadFull;

  /// How a confirmed Markdown link is opened; the system browser by default.
  final LinkOpener? openLink;

  /// Asks before a Markdown link opens; the standard question by default.
  final Future<bool> Function(BuildContext context, String host)? confirmLink;

  @override
  Widget build(BuildContext context) => switch (content) {
    TextContent(:final text, :final truncation) => TextPreview(
      text: text,
      truncation: truncation,
      onDownloadFull: onDownloadFull,
    ),
    CodeContent(:final text, :final truncation) => CodePreview(
      text: text,
      truncation: truncation,
      onDownloadFull: onDownloadFull,
    ),
    MarkdownContent(:final text, :final showSource, :final truncation) =>
      MarkdownPreview(
        text: text,
        showSource: showSource,
        truncation: truncation,
        onDownloadFull: onDownloadFull,
        openLink: openLink,
        confirmLink: confirmLink,
      ),
    ImageContent(:final image, :final label) => ImagePreview(
      image: image,
      label: label,
    ),
  };
}

/// The note above a text that was cut short, when there is one: a bar above
/// the text, which at a large text size scrolls with it so it cannot take the
/// whole screen. [body] builds the scrolling content from an optional leading
/// note.
Widget _withNote(
  BuildContext context, {
  required FileTruncation? truncation,
  required VoidCallback? onDownloadFull,
  required Widget Function(Widget? inlineNote) body,
}) {
  if (truncation == null) return body(null);
  final note = FilesTruncatedNote(
    shownBytes: truncation.shownBytes,
    totalBytes: truncation.totalBytes,
    onDownloadFull: onDownloadFull ?? () {},
  );
  if (isLargeText(context)) return body(note);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: note),
      Expanded(child: body(null)),
    ],
  );
}

/// The text style of text and code: 13 pt monospace (12 pt on a Mac) on 20 pt
/// lines, wrapping without a hanging indent.
TextStyle filesCodeStyle(BuildContext context) {
  final size = FilesMetrics.of(context).codeSize;
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    height: 20 / size,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

class _Scrolling extends StatelessWidget {
  const _Scrolling({required this.note, required this.child});

  final Widget? note;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null) ...[note!, const SizedBox(height: 12)],
          child,
        ],
      ),
    ),
  );
}

class _TextBody extends StatelessWidget {
  const _TextBody({required this.text, this.note});

  final String text;
  final Widget? note;

  @override
  Widget build(BuildContext context) => _Scrolling(
    note: note,
    child: SelectableText(text, style: filesCodeStyle(context)),
  );
}

/// A text file: monospace, selectable and wrapped, with no line numbers.
class TextPreview extends StatelessWidget {
  const TextPreview({
    super.key,
    required this.text,
    this.truncation,
    this.onDownloadFull,
  });

  final String text;
  final FileTruncation? truncation;
  final VoidCallback? onDownloadFull;

  @override
  Widget build(BuildContext context) => _withNote(
    context,
    truncation: truncation,
    onDownloadFull: onDownloadFull,
    body: (note) => _TextBody(text: text, note: note),
  );
}

/// A code file. It is plain monospace for now; the colours of the code
/// palette come with the highlighter.
class CodePreview extends StatelessWidget {
  const CodePreview({
    super.key,
    required this.text,
    this.truncation,
    this.onDownloadFull,
  });

  final String text;
  final FileTruncation? truncation;
  final VoidCallback? onDownloadFull;

  @override
  Widget build(BuildContext context) => _withNote(
    context,
    truncation: truncation,
    onDownloadFull: onDownloadFull,
    body: (note) => _TextBody(text: text, note: note),
  );
}

/// A Markdown file, rendered or as source. Rendering is inert: an image shows
/// its alt text or "Image not loaded" and nothing is requested, a link asks
/// "Open example.com?" first, and a relative link or image does nothing. HTML
/// is text.
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.text,
    this.showSource = false,
    this.truncation,
    this.onDownloadFull,
    this.openLink,
    this.confirmLink,
  });

  final String text;
  final bool showSource;
  final FileTruncation? truncation;
  final VoidCallback? onDownloadFull;
  final LinkOpener? openLink;
  final Future<bool> Function(BuildContext context, String host)? confirmLink;

  Future<void> _tap(BuildContext context, String url) async {
    final host = markdownLinkHost(url);
    if (host == null) return;
    final ask = confirmLink ?? confirmOpenLink;
    if (!await ask(context, host) || !context.mounted) return;
    markdownLinkHandler(open: openLink)(url, '');
  }

  @override
  Widget build(BuildContext context) {
    if (showSource) {
      return _withNote(
        context,
        truncation: truncation,
        onDownloadFull: onDownloadFull,
        body: (note) => _TextBody(text: text, note: note),
      );
    }
    final notLoaded = context.l10n.filesMarkdownImageNotLoaded;
    return _withNote(
      context,
      truncation: truncation,
      onDownloadFull: onDownloadFull,
      body: (note) => _Scrolling(
        note: note,
        child: SelectionArea(
          // The headings take their colour from the text theme, which is not
          // light on dark by itself.
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Theme.of(context).colorScheme.onSurface,
                displayColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            child: GptMarkdown(
              inertMarkdown(text, notLoaded: notLoaded),
              onLinkTap: (url, _) => unawaited(_tap(context, url)),
              imageBuilder: (context, url, width, height) => Text(notLoaded),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Rendered / Source switch of a Markdown file, for the preview pane. On
/// phones the page's own tabs do this job.
class MarkdownModeControl extends StatelessWidget {
  const MarkdownModeControl({
    super.key,
    required this.showSource,
    required this.onChanged,
  });

  final bool showSource;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final labels = {
      false: l10n.filesMarkdownRendered,
      true: l10n.filesMarkdownSource,
    };
    final files = FilesMetrics.of(context);
    final control = platformChromeOf(context).isApple
        ? CupertinoSlidingSegmentedControl<bool>(
            groupValue: showSource,
            backgroundColor: scheme.surfaceContainerHighest,
            thumbColor: scheme.surface,
            padding: const EdgeInsets.all(2),
            children: {
              for (final MapEntry(:key, :value) in labels.entries)
                key: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: files.pointer ? 12 : null,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            },
            onValueChanged: (value) {
              if (value != null) onChanged(value);
            },
          )
        : PillSegmentedControl<bool>(
            value: showSource,
            segments: labels,
            onChanged: onChanged,
          );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: control,
        ),
      ),
    );
  }
}

/// A picture fitted to the room with a 16 pt margin, never enlarged past its
/// own size, with pinch, pan and double tap to zoom. A checkerboard shows
/// through transparency, drawn only inside the picture's bounds, on a page
/// background that follows the theme.
class ImagePreview extends StatefulWidget {
  const ImagePreview({super.key, required this.image, required this.label});

  final ImageProvider image;

  /// The accessible name of the picture, its file name.
  final String label;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  static const _margin = 16.0;

  final _transform = TransformationController();
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (!mounted) return;
      setState(
        () => _size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ),
      );
    },
    onError: (_, _) {
      if (mounted) setState(() => _failed = true);
    },
  );
  Size? _size;
  bool _failed = false;
  Offset _tapAt = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _size = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final next = widget.image.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = next..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    _transform.value = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-_tapAt.dx * 1.5, -_tapAt.dy * 1.5, 0, 1)
            ..scaleByDouble(2.5, 2.5, 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final size = _size;
    Widget body;
    if (_failed) {
      body = Center(
        child: AppIcon(
          AppIcons.brokenImage,
          size: 40,
          color: context.hermesColors.subtleText,
        ),
      );
    } else if (size == null) {
      body = const Center(child: CircularProgressIndicator.adaptive());
    } else {
      body = LayoutBuilder(
        builder: (context, box) {
          final room = Size(
            (box.maxWidth - 2 * _margin).clamp(1, double.infinity),
            (box.maxHeight - 2 * _margin).clamp(1, double.infinity),
          );
          final natural = Size(size.width / ratio, size.height / ratio);
          final scale = [
            room.width / natural.width,
            room.height / natural.height,
            1.0,
          ].reduce((a, b) => a < b ? a : b);
          final fitted = Size(natural.width * scale, natural.height * scale);
          return GestureDetector(
            onDoubleTapDown: (d) => _tapAt = d.localPosition,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _transform,
              maxScale: 8,
              child: SizedBox(
                width: box.maxWidth,
                height: box.maxHeight,
                child: Center(
                  child: SizedBox.fromSize(
                    size: fitted,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: _Checkerboard(dark: dark)),
                        Image(
                          image: widget.image,
                          fit: BoxFit.fill,
                          semanticLabel: widget.label,
                          filterQuality: FilterQuality.medium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    return ColoredBox(color: scheme.surface, child: body);
  }
}

class _Checkerboard extends CustomPainter {
  const _Checkerboard({required this.dark});

  final bool dark;

  static const _cell = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()
      ..color = dark ? const Color(0xFF2E2E31) : Colors.white;
    final shade = Paint()
      ..color = dark ? const Color(0xFF3F3F44) : const Color(0xFFE4E4E7);
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, light);
    for (var y = 0.0; y < size.height; y += _cell) {
      for (var x = 0.0; x < size.width; x += _cell) {
        if (((x / _cell).floor() + (y / _cell).floor()).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, _cell, _cell), shade);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Checkerboard oldDelegate) => oldDelegate.dark != dark;
}
