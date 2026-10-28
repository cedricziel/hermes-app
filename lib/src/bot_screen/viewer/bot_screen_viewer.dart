import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../rfb/rfb_client.dart' show Framebuffer;
import '../widgets/bot_screen_viewer_view.dart';
import 'bot_screen_viewer_controller.dart';

/// [BotScreenViewerView] over [controller]: the picture of its framebuffer,
/// and the actions its phase offers.
///
/// It tells the controller whether the route it is on is on screen (a route
/// above it that covers it pauses the stream), and closes on Escape and the
/// system's dismiss action. Nothing here reacts to a tap or click on the
/// picture; the viewer only zooms and pans.
class BotScreenViewer extends StatefulWidget {
  const BotScreenViewer({
    super.key,
    required this.controller,
    required this.profile,
    required this.presentation,
    required this.onClose,
  });

  final BotScreenViewerController controller;

  /// The profile's name for the header.
  final String profile;
  final BotScreenViewerPresentation presentation;
  final VoidCallback onClose;

  @override
  State<BotScreenViewer> createState() => _BotScreenViewerState();
}

class _BotScreenViewerState extends State<BotScreenViewer> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route above that covers this one turns its tickers off, as for
    // `BotScreenDemand`. The setter tells its listeners a microtask later, so
    // it is safe while the tree builds.
    widget.controller.visible = TickerMode.valuesOf(context).enabled;
  }

  @override
  Widget build(BuildContext context) => Actions(
    // Escape is `DismissIntent` in the app's default shortcuts, and a widget
    // handler, not a menu chord: no menu item owns it.
    actions: {
      DismissIntent: CallbackAction<DismissIntent>(
        onInvoke: (_) {
          widget.onClose();
          return null;
        },
      ),
    },
    child: Focus(
      autofocus: true,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final framebuffer = controller.framebuffer;
          return BotScreenViewerView(
            phase: controller.phase,
            profile: widget.profile,
            presentation: widget.presentation,
            picture: framebuffer == null
                ? null
                : FramebufferPicture(
                    framebuffer: framebuffer,
                    revision: controller.revision,
                  ),
            aspectRatio: framebuffer == null
                ? 16 / 10
                : (framebuffer.width / framebuffer.height).clamp(0.5, 3.0),
            onClose: widget.onClose,
            onRetry: controller.retry,
            onStart: () => controller.startScreen(),
          );
        },
      ),
    ),
  );
}

/// What turns RGBA pixels into an image; `dart:ui`'s, unless a test says
/// otherwise.
typedef PixelDecoder = void Function(
  Uint8List pixels,
  int width,
  int height,
  ui.PixelFormat format,
  ui.ImageDecoderCallback callback,
);

/// The framebuffer as an image. Each change is turned into an image at most
/// once per frame, and the previous image is disposed once the next is ready.
class FramebufferPicture extends StatefulWidget {
  const FramebufferPicture({
    super.key,
    required this.framebuffer,
    required this.revision,
    this.decode = ui.decodeImageFromPixels,
  });

  final Framebuffer framebuffer;

  /// Makes the image; the engine's unless a test says otherwise.
  final PixelDecoder decode;

  /// Changes whenever the framebuffer's pixels do.
  final int revision;

  @override
  State<FramebufferPicture> createState() => _FramebufferPictureState();
}

class _FramebufferPictureState extends State<FramebufferPicture> {
  ui.Image? _image;
  Object? _shown;
  var _scheduled = false;
  var _decoding = false;

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(FramebufferPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    _request();
  }

  /// Asks for an image of the pixels as they are in the next frame.
  void _request() {
    if (_scheduled || _decoding) return;
    final latest = (widget.framebuffer, widget.revision);
    if (_shown == latest) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scheduled = false;
      if (mounted) _decode();
    });
  }

  void _decode() {
    final framebuffer = widget.framebuffer;
    final revision = widget.revision;
    _decoding = true;
    // The engine copies the pixels at once, so the client may paint into the
    // buffer again straight away.
    widget.decode(
      framebuffer.rgba,
      framebuffer.width,
      framebuffer.height,
      ui.PixelFormat.rgba8888,
      (image) {
        _decoding = false;
        if (!mounted) {
          image.dispose();
          return;
        }
        final previous = _image;
        setState(() {
          _image = image;
          _shown = (framebuffer, revision);
        });
        previous?.dispose();
        _request();
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const ColoredBox(color: Colors.black);
    return RawImage(
      image: image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
