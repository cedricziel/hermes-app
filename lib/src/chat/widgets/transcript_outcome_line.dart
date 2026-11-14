import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// A muted, centred line with a hairline on each side, between messages of the
/// transcript: "Conversation compressed · 42 → 9 messages". It takes the
/// finished sentence; the caller reads it from the localizations. It holds
/// counts only, never message text or a file name. A screen reader hears the
/// sentence once, and the line wraps at any text size instead of being cut.
class TranscriptOutcomeLine extends StatelessWidget {
  const TranscriptOutcomeLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    // At large text sizes the hairlines go: the sentence gets the whole width
    // instead of breaking inside a word.
    final large = MediaQuery.textScalerOf(context).scale(13) > 20;
    final hairline = Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              if (!large) Expanded(child: hairline),
              Flexible(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: large ? 0 : 12),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: subtle),
                  ),
                ),
              ),
              if (!large) Expanded(child: hairline),
            ],
          ),
        ),
      ),
    );
  }
}
