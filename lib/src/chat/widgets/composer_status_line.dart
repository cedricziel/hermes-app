import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';

/// A muted line directly above the composer that says why Send is off
/// ("Restoring files…", [busy]) or what just happened to the draft ("Your
/// last message is back in the box.", with [icon]). It takes the finished
/// sentence; the caller reads it from the localizations. The words carry the
/// meaning, not the colour, and a screen reader hears them once as they
/// appear. The line wraps at any text size.
class ComposerStatusLine extends StatelessWidget {
  const ComposerStatusLine({
    super.key,
    required this.text,
    this.busy = false,
    this.icon,
  });

  final String text;

  /// Shows a small spinner before the text, or nothing with reduced motion.
  final bool busy;
  final AppIconSet? icon;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final still = MediaQuery.disableAnimationsOf(context);
    // The mark grows with the text beside it.
    final mark = MediaQuery.textScalerOf(context).scale(13);
    final leading = busy
        ? still
              ? null
              : SizedBox.square(
                  dimension: mark * 0.9,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(subtle),
                  ),
                )
        : icon == null
        ? null
        : AppIcon(icon!, size: mark * 1.1, color: subtle);
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 13, color: subtle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
