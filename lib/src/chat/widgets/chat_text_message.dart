import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_markdown_theme.dart';
import '../../widgets/bounded_markdown.dart';

/// A text message as `FlyerChatTextMessage` draws it with no time, status or
/// link preview, except that its markdown is a [BoundedMarkdown]: that widget
/// has no hook for the code blocks, and an unbounded block can freeze the app.
///
/// [textStyle] is the paragraph style, [backgroundColor] fills the bubble and
/// [linksDecoration] underlines links, in the colour the chat theme gives text
/// on that surface.
class ChatTextMessage extends StatelessWidget {
  const ChatTextMessage({
    super.key,
    required this.message,
    required this.isSentByMe,
    required this.textStyle,
    required this.backgroundColor,
    required this.borderRadius,
    required this.padding,
    this.linksDecoration,
    this.onLinkTap,
  });

  final TextMessage message;
  final bool isSentByMe;
  final TextStyle textStyle;
  final Color backgroundColor;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry padding;
  final TextDecoration? linksDecoration;
  final void Function(String url, String title)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final decorationColor = context.select(
      (ChatTheme t) => isSentByMe ? t.colors.onPrimary : t.colors.onSurface,
    );
    final content = AppMarkdownTheme(
      child: BoundedMarkdown(
        message.text,
        style: textStyle,
        onLinkTap: onLinkTap,
        linkBuilder: (_, span, _, _) =>
            Text.rich(_styleLinks(span, decorationColor)),
      ),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(color: backgroundColor),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: padding,
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [content],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InlineSpan _styleLinks(InlineSpan original, Color decorationColor) {
    if (original is! TextSpan) return original;
    return TextSpan(
      text: original.text,
      children: original.children
          ?.map((child) => _styleLinks(child, decorationColor))
          .toList(),
      style: (original.style ?? textStyle).copyWith(
        decoration: linksDecoration,
        decorationColor: decorationColor,
      ),
    );
  }
}
