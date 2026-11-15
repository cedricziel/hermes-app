import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gpt_markdown/custom_widgets/markdown_text_scaling.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show CodeBlockStyle;
import 'package:material_ui/material_ui.dart' as mui;

import '../files/code_highlight.dart';
import '../theme/hermes_code_colors.dart';

/// A fenced code block of a markdown message: the language label, a copy
/// button and the code, coloured by the shared code palette
/// ([HermesCodeColors]) like the Files preview.
///
/// It draws what `gpt_markdown`'s `CodeField` draws, except for the colours:
/// that widget colours through fixed `val_highlight` themes and takes no
/// palette, so a block of a chat reply and one of a file would differ.
class HermesCodeBlock extends StatefulWidget {
  const HermesCodeBlock({
    super.key,
    required this.name,
    required this.codes,
    required this.style,
    this.highlightCode = true,
    this.scalesItsOwnText = false,
  });

  /// The language written after the opening fence.
  final String name;

  /// The code itself.
  final String codes;

  /// Resolved appearance; every field is filled in.
  final CodeBlockStyle style;

  /// Whether to colour the code. The caller decides: the highlighter is
  /// quadratic on some inputs.
  final bool highlightCode;

  /// Whether this block scales from MediaQuery rather than an enclosing
  /// paragraph.
  final bool scalesItsOwnText;

  @override
  State<HermesCodeBlock> createState() => _HermesCodeBlockState();
}

/// Fence tags `val_highlight` has no alias for.
const _aliases = {'python3': 'python', 'shellscript': 'bash'};

class _HermesCodeBlockState extends State<HermesCodeBlock> {
  static const double _copyButtonSize = 32;
  static const double _copyIconSize = 17;

  bool _copied = false;
  bool _copying = false;
  String? _cachedCode;
  String? _cachedLanguage;
  List<CodeRun>? _cachedRuns;

  List<CodeRun> _runs() {
    var language = widget.highlightCode ? widget.name.trim().toLowerCase() : '';
    language = _aliases[language] ?? language;
    if (_cachedRuns != null &&
        _cachedCode == widget.codes &&
        _cachedLanguage == language) {
      return _cachedRuns!;
    }
    _cachedCode = widget.codes;
    _cachedLanguage = language;
    return _cachedRuns = language.isEmpty
        ? [(widget.codes, null)]
        : highlightCode(widget.codes, language);
  }

  Future<void> _copyCode() async {
    if (_copying || _copied) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: widget.codes));
    } on Object {
      if (mounted) setState(() => _copying = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _copying = false;
      _copied = true;
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  Widget _copyButton(BuildContext context) {
    final label = _copied
        ? (widget.style.copiedLabel ?? 'Copied!')
        : (widget.style.copyLabel ?? 'Copy code');
    final icon = _copied
        ? mui.Icons.check_rounded
        : mui.Icons.content_copy_rounded;
    final scheme = mui.Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      button: true,
      child: mui.Tooltip(
        message: label,
        child: Container(
          width: _copyButtonSize,
          height: _copyButtonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: mui.Material(
            type: mui.MaterialType.transparency,
            shape: const CircleBorder(),
            child: mui.InkWell(
              customBorder: const CircleBorder(),
              hoverColor: scheme.onSurface.withValues(alpha: 0.08),
              highlightColor: scheme.onSurface.withValues(alpha: 0.12),
              onTap: _copyCode,
              child: Center(
                child: Icon(
                  icon,
                  key: ValueKey(_copied),
                  size: _copyIconSize,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = mui.Theme.of(context);
    final scheme = theme.colorScheme;
    final borderColor = widget.style.borderColor;
    final showLabel = widget.style.showLanguageLabel ?? true;
    final showCopy = widget.style.showCopyButton ?? true;
    final displayName = widget.name.trim().isEmpty ? 'Code' : widget.name;
    final family = widget.style.fontFamily;
    final palette = context.codeColors;
    final codeStyle = TextStyle(
      fontFamily: family ?? 'JetBrainsMono',
      package: family == null ? 'gpt_markdown' : widget.style.fontFamilyPackage,
      fontSize: widget.style.fontSize,
      color: widget.style.textColor,
    );
    final panelRadius = BorderRadius.all(
      widget.style.borderRadius ?? const Radius.circular(12),
    );
    final body = DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium,
      child: ClipRRect(
        borderRadius: panelRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.style.backgroundColor ?? scheme.surfaceContainer,
            borderRadius: panelRadius,
            border: borderColor == null
                ? null
                : Border.all(
                    color: borderColor,
                    width: widget.style.borderWidth ?? 1,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLabel || showCopy)
                Padding(
                  padding:
                      widget.style.headerPadding ??
                      const EdgeInsets.fromLTRB(10, 8, 8, 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showLabel)
                        Flexible(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      mui.Icons.terminal_rounded,
                                      size: 13,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: widget.style.languageStyle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showLabel && showCopy) const SizedBox(width: 8),
                      if (!showLabel) const Spacer(),
                      if (showCopy) _copyButton(context),
                    ],
                  ),
                ),
              // Source code and its scroll origin keep their LTR order inside
              // right-to-left markdown.
              Directionality(
                textDirection: TextDirection.ltr,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      widget.style.padding ??
                      const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Text.rich(
                    TextSpan(
                      style: codeStyle,
                      children: [
                        for (final (text, token) in _runs())
                          TextSpan(
                            text: text,
                            style: codeTokenStyle(token, palette),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return MarkdownTextScaling.wrap(body, enabled: widget.scalesItsOwnText);
  }
}
