import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../bot_screen_preview_model.dart';
import 'bot_screen_card.dart' show BotScreenCaption;

/// The widest the picture grows in the transcript.
const double kBotScreenPreviewMaxWidth = 320;

/// The tallest the picture grows, so a portrait screen does not fill the chat.
const double kBotScreenPreviewMaxHeight = 200;

/// The still preview of the bot's screen under a `computer_use` tool call: the
/// latest picture with a Live badge, and who is in control. Tapping it calls
/// [onTap].
///
/// It draws [model] and nothing else, so it needs no controller. A hidden
/// model draws nothing.
class BotScreenPreview extends StatelessWidget {
  const BotScreenPreview({super.key, required this.model, this.onTap});

  final BotScreenPreviewModel model;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => switch (model) {
    BotScreenPreviewHidden() => const SizedBox.shrink(),
    final BotScreenPreviewFrame frame => _frame(context, frame),
    final BotScreenPreviewSuppressed suppressed => _suppressed(
      context,
      suppressed,
    ),
  };

  Widget _frame(BuildContext context, BotScreenPreviewFrame frame) {
    final theme = Theme.of(context);
    final bytes = frame.bytes;
    final width = math.min(
      kBotScreenPreviewMaxWidth,
      kBotScreenPreviewMaxHeight * frame.aspectRatio,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Tappable(
              onTap: onTap,
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
                          Semantics(
                            image: true,
                            label: "Hermes's screen",
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              // Frames are drawn at most this wide, whatever
                              // size the screen has.
                              cacheWidth:
                                  (width *
                                          MediaQuery.devicePixelRatioOf(
                                            context,
                                          ))
                                      .ceil(),
                              gaplessPlayback: true,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) => const Center(
                                child: BotScreenCaption('Picture unavailable'),
                              ),
                            ),
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
            const BotScreenCaption('Hermes is in control'),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: _Tappable(
        onTap: onTap,
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
                Flexible(
                  child: Text(
                    suppressed.byYou
                        ? "You're in control"
                        : 'Someone else is in control',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Makes [child] a button that calls [onTap], when there is one.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: "Open Hermes's screen",
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
