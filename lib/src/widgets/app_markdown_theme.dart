import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../theme/hermes_theme.dart';

/// [child] (a markdown view) under a markdown theme from the app's: headings in
/// the on-surface colour, the rule in the outline colour and links in the app's
/// link colour (the package's own link colour is `Colors.blue`, 3.1:1 on white).
class AppMarkdownTheme extends StatelessWidget {
  const AppMarkdownTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GptMarkdownTheme(
      gptThemeData: _themeData(
        theme.brightness,
        theme.colorScheme.onSurface,
        theme.colorScheme.outline,
        context.hermesColors.link,
      ),
      child: child,
    );
  }
}

/// The package compares theme data by identity, so a fresh object on every
/// build would make each markdown block of a streaming reply rebuild on every
/// delta. The last one is kept and handed out while its inputs are unchanged.
({Brightness brightness, Color ink, Color outline, Color link})? _key;
GptMarkdownThemeData? _data;

GptMarkdownThemeData _themeData(
  Brightness brightness,
  Color ink,
  Color outline,
  Color link,
) {
  final key = (brightness: brightness, ink: ink, outline: outline, link: link);
  final cached = _data;
  if (cached != null && key == _key) return cached;
  TextStyle heading(double size, FontWeight weight) =>
      TextStyle(fontSize: size, fontWeight: weight, color: ink, height: 1.3);
  _key = key;
  return _data = GptMarkdownThemeData(
    brightness: brightness,
    h1: heading(26, FontWeight.w700),
    h2: heading(22, FontWeight.w700),
    h3: heading(19, FontWeight.w600),
    h4: heading(17, FontWeight.w600),
    h5: heading(15, FontWeight.w600),
    h6: heading(14, FontWeight.w600),
    hrLineColor: outline,
    linkColor: link,
    linkHoverColor: link,
  );
}
