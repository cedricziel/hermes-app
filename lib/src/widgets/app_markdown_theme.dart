import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../theme/hermes_theme.dart';

/// [child] (a markdown view) under a markdown theme from the app's: headings in
/// the on-surface colour (the package takes them from its own light or dark
/// text theme, which is near-invisible on a dark page) and links in the app's
/// link colour.
class AppMarkdownTheme extends StatelessWidget {
  const AppMarkdownTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    TextStyle heading(double size, FontWeight weight) =>
        TextStyle(fontSize: size, fontWeight: weight, color: ink, height: 1.3);
    final link = context.hermesColors.link;
    return GptMarkdownTheme(
      gptThemeData: GptMarkdownThemeData(
        brightness: theme.brightness,
        h1: heading(26, FontWeight.w700),
        h2: heading(22, FontWeight.w700),
        h3: heading(19, FontWeight.w600),
        h4: heading(17, FontWeight.w600),
        h5: heading(15, FontWeight.w600),
        h6: heading(14, FontWeight.w600),
        hrLineColor: theme.colorScheme.outline,
        linkColor: link,
        linkHoverColor: link,
      ),
      child: child,
    );
  }
}
