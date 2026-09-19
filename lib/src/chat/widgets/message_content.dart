import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/hermes_theme.dart';

/// Renders message text with just enough markdown-lite support to make
/// agent output legible — fenced code blocks as their own surface, `inline
/// code` as a chip, **bold** as emphasis — without pulling in a full
/// markdown package for a design preview.
class MessageContent extends StatelessWidget {
  const MessageContent({
    super.key,
    required this.text,
    required this.baseStyle,
  });

  final String text;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final blocks = _splitCodeBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final block in blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: block.isCode
                ? _CodeBlock(code: block.text, language: block.language)
                : _InlineRichText(text: block.text, baseStyle: baseStyle),
          ),
      ],
    );
  }
}

class _TextBlock {
  _TextBlock(this.text, {this.isCode = false, this.language});
  final String text;
  final bool isCode;
  final String? language;
}

List<_TextBlock> _splitCodeBlocks(String text) {
  final fence = RegExp(r'```([a-zA-Z0-9_+-]*)\n([\s\S]*?)```');
  final blocks = <_TextBlock>[];
  var last = 0;
  for (final match in fence.allMatches(text)) {
    if (match.start > last) {
      final chunk = text.substring(last, match.start).trim();
      if (chunk.isNotEmpty) blocks.add(_TextBlock(chunk));
    }
    final lang = match.group(1) ?? '';
    final code = match.group(2) ?? '';
    blocks.add(_TextBlock(code.trimRight(), isCode: true, language: lang));
    last = match.end;
  }
  if (last < text.length) {
    final chunk = text.substring(last).trim();
    if (chunk.isNotEmpty) blocks.add(_TextBlock(chunk));
  }
  if (blocks.isEmpty) blocks.add(_TextBlock(text));
  return blocks;
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Text(
                  (language == null || language!.isEmpty) ? 'code' : language!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: context.hermesColors.subtleText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: 'Copy code',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineRichText extends StatelessWidget {
  const _InlineRichText({required this.text, required this.baseStyle});

  final String text;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = text.split('\n');
    return SelectableText.rich(
      TextSpan(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            ..._parseInline(lines[i], baseStyle, scheme),
            if (i != lines.length - 1) const TextSpan(text: '\n'),
          ],
        ],
      ),
      style: baseStyle,
    );
  }

  List<InlineSpan> _parseInline(
    String line,
    TextStyle base,
    ColorScheme scheme,
  ) {
    final pattern = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    final spans = <InlineSpan>[];
    var last = 0;
    final bulletMatch = RegExp(r'^(\s*)-\s+').firstMatch(line);
    var effectiveLine = line;
    if (bulletMatch != null) {
      spans.add(TextSpan(text: '${bulletMatch.group(1)}•  ', style: base));
      effectiveLine = line.substring(bulletMatch.end);
    }
    for (final match in pattern.allMatches(effectiveLine)) {
      if (match.start > last) {
        spans.add(
          TextSpan(
            text: effectiveLine.substring(last, match.start),
            style: base,
          ),
        );
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(
              fontFamily: 'monospace',
              fontSize: (base.fontSize ?? 14) - 1,
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
            ),
          ),
        );
      }
      last = match.end;
    }
    if (last < effectiveLine.length) {
      spans.add(TextSpan(text: effectiveLine.substring(last), style: base));
    }
    return spans;
  }
}
