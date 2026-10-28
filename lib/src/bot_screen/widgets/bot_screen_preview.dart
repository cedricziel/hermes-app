import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../bot_screen_preview_model.dart';
import 'bot_screen_card.dart' show BotScreenCaption;

/// The widest the picture grows in the transcript.
const double kBotScreenPreviewMaxWidth = 320;

/// The tallest the picture grows, so a portrait screen does not fill the chat.
const double kBotScreenPreviewMaxHeight = 200;

const _hermesInControl = 'Hermes is in control';

/// The still preview of the bot's screen under a `computer_use` tool call: the
/// latest picture with a Live badge, and who is in control. Tapping it calls
/// [onTap].
///
/// It draws [model] and nothing else, so it needs no controller. A hidden
/// model draws nothing. It leaves room below itself but none above, which is
/// for the place that holds it to give.
class BotScreenPreview extends StatelessWidget {
  const BotScreenPreview({super.key, required this.model, this.onTap});

  final BotScreenPreviewModel model;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => switch (model) {
    BotScreenPreviewHidden() => const SizedBox.shrink(),
    final BotScreenPreviewFrame frame => _spaced(_frame(context, frame)),
    final BotScreenPreviewSuppressed suppressed => _spaced(
      _suppressed(context, suppressed),
    ),
  };

  /// The room the preview keeps below itself, so a hidden one takes none.
  static Widget _spaced(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: child);

  Widget _frame(BuildContext context, BotScreenPreviewFrame frame) {
    final theme = Theme.of(context);
    final bytes = frame.bytes;
    final width = math.min(
      kBotScreenPreviewMaxWidth,
      kBotScreenPreviewMaxHeight * frame.aspectRatio,
    );
    const caption = BotScreenCaption(_hermesInControl);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Labeled(
              label: "Hermes's screen, live. $_hermesInControl",
              onTap: onTap,
              image: true,
              child: AspectRatio(
                aspectRatio: frame.aspectRatio,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (bytes != null)
                          _FramePicture(
                            bytes: bytes,
                            width:
                                width * MediaQuery.devicePixelRatioOf(context),
                          )
                        else
                          const Center(
                            child: BotScreenCaption(
                              'Waiting for the first picture…',
                            ),
                          ),
                        const Positioned(top: 6, left: 6, child: _LiveBadge()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // A tappable picture already says it.
            if (onTap == null)
              caption
            else
              const ExcludeSemantics(child: caption),
          ],
        ),
      ),
    );
  }

  Widget _suppressed(
    BuildContext context,
    BotScreenPreviewSuppressed suppressed,
  ) {
    final theme = Theme.of(context);
    final text = suppressed.byYou
        ? "You're in control"
        : 'Someone else is in control';
    return Align(
      alignment: Alignment.centerLeft,
      child: _Labeled(
        label: "Hermes's screen. $text",
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: platformChromeOf(context) == PlatformChrome.ios
                ? kAppleMinTapTarget
                : 0,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    AppIcons.lock,
                    size: 16,
                    color: context.hermesColors.subtleText,
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(text, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The picture of one frame, decoded no wider than it is drawn (never
/// upscaled), and taken out of the image cache again once a newer frame or the
/// end of the preview replaces it: the cache would otherwise hold a decoded
/// frame of the screen long after it was dropped.
class _FramePicture extends StatefulWidget {
  const _FramePicture({required this.bytes, required this.width});

  final Uint8List bytes;

  /// The width to decode at, in device pixels.
  final double width;

  @override
  State<_FramePicture> createState() => _FramePictureState();
}

class _FramePictureState extends State<_FramePicture> {
  late ResizeImage _provider = _make();

  ResizeImage _make() => ResizeImage(
    MemoryImage(widget.bytes),
    width: widget.width.ceil(),
    allowUpscaling: false,
  );

  @override
  void didUpdateWidget(_FramePicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.width != widget.width) {
      final old = _provider;
      _provider = _make();
      unawaited(old.evict());
    }
  }

  @override
  void dispose() {
    unawaited(_provider.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: _provider,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) =>
        const Center(child: BotScreenCaption('Picture unavailable')),
  );
}

/// Names [child] for assistive technology as [label]: a button that calls
/// [onTap] when there is one, otherwise an image or plain text.
class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.label,
    required this.child,
    this.onTap,
    this.image = false,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool image;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Semantics(
        image: image,
        label: label,
        excludeSemantics: true,
        child: child,
      );
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xffff453a),
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 6, height: 6),
          ),
          SizedBox(width: 5),
          Text(
            'Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}
