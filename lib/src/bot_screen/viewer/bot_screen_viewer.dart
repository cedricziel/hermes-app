import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../rfb/rfb_client.dart' show Framebuffer;
import '../widgets/bot_screen_viewer_view.dart';
import 'bot_screen_viewer_controller.dart';

/// [BotScreenViewerView] over [controller]: the picture of its framebuffer,
/// and the actions its phase offers.
///
/// Nothing here reacts to a tap or click on the picture; the viewer only zooms
/// and pans.
class BotScreenViewer extends StatelessWidget {
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final framebuffer = controller.framebuffer;
      return BotScreenViewerView(
        phase: controller.phase,
        profile: profile,
        presentation: presentation,
        picture: framebuffer == null
            ? null
            : FramebufferPicture(
                framebuffer: framebuffer,
                revision: controller.revision,
              ),
        aspectRatio: framebuffer == null
            ? 16 / 10
            : (framebuffer.width / framebuffer.height).clamp(0.5, 3.0),
        onClose: onClose,
        onRetry: controller.retry,
        onStart: () => controller.startScreen(),
      );
    },
  );
}

/// The full-window layer: the viewer over a barrier that keeps the window
/// below from taking clicks, closed by Escape.
class BotScreenViewerOverlay extends StatefulWidget {
  const BotScreenViewerOverlay({
    super.key,
    required this.controller,
    required this.profile,
    required this.onClose,
  });

  final BotScreenViewerController controller;
  final String profile;
  final VoidCallback onClose;

  @override
  State<BotScreenViewerOverlay> createState() => _BotScreenViewerOverlayState();
}

class _BotScreenViewerOverlayState extends State<BotScreenViewerOverlay> {
  final _focus = FocusNode(debugLabel: 'bot screen viewer');

  @override
  void initState() {
    super.initState();
    // Whatever the chat had focused must not keep the keys: Escape has to
    // reach this layer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    // Tab stays in the viewer, and a screen reader does not reach the chat
    // below it.
    child: BlockSemantics(
      child: Stack(
        key: const Key('bot-screen-viewer-overlay'),
        children: [
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
          Positioned.fill(
            // A widget handler, not a menu chord: no menu item owns Escape.
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape):
                    widget.onClose,
              },
              child: Focus(
                focusNode: _focus,
                child: BotScreenViewer(
                  controller: widget.controller,
                  profile: widget.profile,
                  presentation: BotScreenViewerPresentation.overlay,
                  onClose: widget.onClose,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The framebuffer as an image. Each change is turned into an image at most
/// once per frame, and the previous image is disposed once the next is ready.
class FramebufferPicture extends StatefulWidget {
  const FramebufferPicture({
    super.key,
    required this.framebuffer,
    required this.revision,
  });

  final Framebuffer framebuffer;

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
    ui.decodeImageFromPixels(
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
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }
}
