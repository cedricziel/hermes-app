import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../files/code_highlight.dart';
import '../../files/widgets/files_metrics.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_code_colors.dart';
import '../../theme/hermes_theme.dart';
import '../../files/widgets/safe_path_text.dart' show wellFormedText;
import '../json_tree_parser.dart';
import '../tool_value_language.dart';
import 'tool_hidden_chars.dart';
import 'tool_json_tree.dart';

const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  height: 1.4,
);

/// Which part of a call a section is, for the words a screen reader hears
/// ("Copy result", "Show input as").
enum ToolValueSection { input, result, error }

/// A tool call's input or output as monospace text, exactly as it was sent:
/// never reformatted, only coloured. Colour follows the code palette through
/// [codeTokenStyle] and the Files guards (size and span caps, a killable
/// worker for a large text, plain text for anything it will not colour). A
/// character that hides or reorders text is drawn as a boxed `U+202E`
/// ([HiddenCharBox]); the text itself is not changed.
///
/// A call that is still running ([settled] false) is shown plain: its text
/// grows with every delta, and colouring it would start over each time.
/// [language] is a grammar name from [toolValueLanguage]; null is plain.
///
/// Selecting copies what is shown: a box copies as its escape text.
/// [ToolValuePanel] has the button that copies the original.
class ToolValueView extends StatefulWidget {
  const ToolValueView({
    super.key,
    required this.text,
    this.language,
    this.settled = true,
    this.selectable = true,
  });

  final String text;
  final String? language;
  final bool settled;
  final bool selectable;

  @override
  State<ToolValueView> createState() => _ToolValueViewState();
}

class _ToolValueViewState extends State<ToolValueView> {
  late List<CodeRun> _runs;
  late bool _hasHidden;
  CodeHighlightWorker? _worker;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _colour();
  }

  @override
  void didUpdateWidget(ToolValueView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.language != widget.language ||
        oldWidget.settled != widget.settled) {
      _colour();
    }
  }

  @override
  void dispose() {
    _generation++;
    _worker?.kill();
    _worker = null;
    super.dispose();
  }

  void _colour() {
    final generation = ++_generation;
    _worker?.kill();
    _worker = null;
    final display = withoutCrlfReturns(wellFormedText(widget.text));
    _hasHidden = hasHiddenToolText(display);
    _runs = [(display, null)];
    final language = widget.language;
    if (!widget.settled ||
        !hasCodeGrammar(language) ||
        !isColourable(display)) {
      return;
    }
    if (isInlineSafe(display)) {
      _runs = highlightCode(display, language);
    } else {
      final worker = _worker = CodeHighlightWorker();
      unawaited(
        worker.highlight(display, language).then((runs) {
          if (mounted && generation == _generation && runs != null) {
            setState(() => _runs = runs);
          }
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _mono.copyWith(color: Theme.of(context).colorScheme.onSurface);
    final palette = context.codeColors;
    final budget = HiddenBoxBudget();
    final children = <InlineSpan>[
      for (final (text, token) in _runs)
        if (_hasHidden)
          ...hiddenCharSpans(
            context,
            text,
            codeTokenStyle(token, palette),
            budget,
            boxStyle: base,
          )
        else
          TextSpan(text: text, style: codeTokenStyle(token, palette)),
    ];
    final span = TextSpan(style: base, children: children);
    final text = Text.rich(span);
    // A selection copies the text of a box too (its escape, `U+202E`), which
    // SelectableText cannot: it turns each box into U+FFFC. Inside a
    // SelectionArea (the chat's) the text just joins that.
    if (!widget.selectable || SelectionContainer.maybeOf(context) != null) {
      return text;
    }
    return SelectionArea(child: text);
  }
}

/// The label of a section and the controls beside it. The controls wrap under
/// the label at large text sizes instead of squeezing it.
class ToolValueHeader extends StatelessWidget {
  const ToolValueHeader({super.key, this.label, this.actions = const []});

  final Widget? label;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // Full width, so the controls are at the trailing edge (in both text
    // directions) and, when they wrap at large text sizes, go under the
    // label at the leading edge.
    final row = SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ?label,
          if (actions.isNotEmpty)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
        ],
      ),
    );
    // A label alone has no control to give the row its height.
    return actions.isEmpty
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: row)
        : row;
  }
}

/// The section's label, then a muted tag naming its content ("JSON",
/// "Python"); no tag for plain text.
class ToolValueLabel extends StatelessWidget {
  const ToolValueLabel({super.key, required this.label, this.language});

  final String label;

  /// A grammar name from [toolValueLanguage], named in the tag; null for none.
  final String? language;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final tag = language == null ? null : toolValueTagName(context, language!);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: subtle,
            ),
          ),
        ),
        if (tag != null) ...[
          const SizedBox(width: 8),
          Text(
            tag,
            key: const ValueKey('tool-value-tag'),
            style: TextStyle(fontSize: 11, color: subtle),
          ),
        ],
      ],
    );
  }
}

const _tagNames = <String, String>{
  'javascript': 'JavaScript',
  'typescript': 'TypeScript',
  'bash': 'Shell',
  'xml': 'HTML/XML',
  'yaml': 'YAML',
  'sql': 'SQL',
  'css': 'CSS',
  'scss': 'SCSS',
  'php': 'PHP',
  'cpp': 'C++',
  'ini': 'TOML',
};

/// The name a tag shows for [language]. JSON and Python are in the ARB files;
/// the other names are proper names and stay as they are in every language.
String toolValueTagName(BuildContext context, String language) {
  final l10n = context.l10n;
  if (language == 'json') return l10n.chatWidgetsToolValueTagJson;
  if (language == 'python') return l10n.chatWidgetsToolValueTagPython;
  return _tagNames[language] ??
      '${language[0].toUpperCase()}${language.substring(1)}';
}

/// The Copy button of a section: a pill 28 pt high (22 pt on a Mac) inside a
/// tappable area of 44 pt on iOS, 48 dp on other touch and desktop platforms
/// and 28 pt on a Mac. With [copied] it shows a check and "Copied".
///
/// A plain model: the panel owns the clipboard, the timer and the
/// announcement.
class ToolValueCopyButton extends StatelessWidget {
  const ToolValueCopyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.copied = false,
  });

  /// What a screen reader says, such as "Copy result".
  final String label;
  final VoidCallback onPressed;
  final bool copied;

  @override
  Widget build(BuildContext context) {
    final metrics = FilesMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final height = metrics.pointer ? 22.0 : 28.0;
    return Semantics(
      button: true,
      label: copied ? context.l10n.chatWidgetsToolValueCopied : label,
      excludeSemantics: true,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: metrics.target,
          minHeight: metrics.target,
        ),
        child: InkWell(
          key: const ValueKey('tool-value-copy'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(metrics.target / 2),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              height: height,
              // A circle for the icon alone, a pill once it says "Copied".
              width: copied ? null : height,
              alignment: copied ? null : Alignment.center,
              padding: copied
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    copied ? AppIcons.check : AppIcons.copy,
                    size: 14,
                    color: subtle,
                  ),
                  if (copied) ...[
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.chatWidgetsToolValueCopied,
                      style: TextStyle(fontSize: 11.5, color: subtle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The switch between the text and the tree of a JSON section. Interim: a
/// plain text button reading "Text | Tree" with the view that shows in bold
/// and underlined, so it is not colour alone. The shared segmented control
/// replaces it when the sections are wired into the card.
class ToolViewSwitch extends StatelessWidget {
  const ToolViewSwitch({
    super.key,
    required this.tree,
    required this.onToggle,
    this.section = ToolValueSection.result,
  });

  /// Whether the tree shows.
  final bool tree;
  final VoidCallback onToggle;
  final ToolValueSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final group = switch (section) {
      ToolValueSection.input => l10n.chatWidgetsToolValueShowInputAs,
      ToolValueSection.result => l10n.chatWidgetsToolValueShowResultAs,
      ToolValueSection.error => l10n.chatWidgetsToolValueShowErrorAs,
    };
    TextSpan option(String text, {required bool active}) => TextSpan(
      text: text,
      style: active
          ? TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            )
          : TextStyle(color: subtle),
    );
    final metrics = FilesMetrics.of(context);
    return Semantics(
      container: true,
      label: group,
      child: Semantics(
        button: true,
        toggled: tree,
        label: tree
            ? l10n.chatWidgetsToolValueShowAsText
            : l10n.chatWidgetsToolValueShowAsTree,
        excludeSemantics: true,
        onTap: onToggle,
        child: TextButton(
          key: const ValueKey('tool-json-toggle'),
          style: metrics.buttonStyle().merge(
            TextButton.styleFrom(
              foregroundColor: subtle,
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 12),
            ),
          ),
          onPressed: onToggle,
          child: Text.rich(
            TextSpan(
              children: [
                option(l10n.chatWidgetsToolValueViewText, active: !tree),
                TextSpan(
                  text: ' | ',
                  style: TextStyle(color: subtle),
                ),
                option(l10n.chatWidgetsToolValueViewTree, active: tree),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// JSON text with a switch between the text as sent (the default, coloured)
/// and a collapsible tree. [header] and [actions] sit on the row of the
/// switch, so the section keeps one header line.
///
/// Which view shows is state of this widget: it survives a rebuild of its
/// parent, and ends with the widget.
class ToolJsonView extends StatefulWidget {
  const ToolJsonView({
    super.key,
    required this.text,
    this.nodes,
    this.header,
    this.actions = const [],
    this.initiallyTree = false,
    this.bodyMaxHeight,
    this.section = ToolValueSection.result,
  });

  final String text;

  /// [text] already decoded (an object or array within the depth the tree is
  /// offered for), so the tree does not parse it again.
  final List<JsonTreeNode>? nodes;

  /// The most height the body (text or tree) takes before it scrolls; the
  /// header row is outside it.
  final double? bodyMaxHeight;

  /// The section's label, at the start of the header row.
  final Widget? header;

  /// Buttons after the switch, such as copy.
  final List<Widget> actions;

  /// Starts on the tree; the catalog uses it to show that view.
  final bool initiallyTree;

  final ToolValueSection section;

  @override
  State<ToolJsonView> createState() => _ToolJsonViewState();
}

class _ToolJsonViewState extends State<ToolJsonView> {
  late bool _tree = widget.initiallyTree;

  void _toggle() => setState(() => _tree = !_tree);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ToolValueHeader(
        label: widget.header,
        actions: [
          ToolViewSwitch(
            tree: _tree,
            onToggle: _toggle,
            section: widget.section,
          ),
          ...widget.actions,
        ],
      ),
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: widget.bodyMaxHeight ?? double.infinity,
        ),
        child: _tree
            ? ToolJsonTree(text: widget.text, nodes: widget.nodes)
            : SingleChildScrollView(
                child: ToolValueView(text: widget.text, language: 'json'),
              ),
      ),
    ],
  );
}

/// One section of a tool call card: a label row (label, a tag naming the
/// content, the view switch, Copy), the value in [ToolValueView] capped at
/// [maxHeight] and scrolling inside it, and a muted line when the text is
/// shown plainer than its content could be.
///
/// A settled JSON object or array within the limits gets the Tree switch;
/// code, other text, invalid JSON, a running call and JSON over the limits
/// have none ([toolValueShape]). Copy copies [text] as it was sent in either
/// view, hidden characters included, shows "Copied" for two seconds and
/// announces it; [showCopy] false leaves it out, for an Input that a section
/// below ("Raw arguments") already copies.
class ToolValuePanel extends StatefulWidget {
  const ToolValuePanel({
    super.key,
    required this.label,
    required this.text,
    this.language,
    this.settled = true,
    this.initiallyTree = false,
    this.section = ToolValueSection.result,
    this.showCopy = true,
  });

  final String label;
  final String text;

  /// From [toolValueLanguage]; `json` offers the Tree switch when the text
  /// parses within the limits.
  final String? language;
  final bool settled;
  final bool initiallyTree;
  final ToolValueSection section;
  final bool showCopy;

  static const double maxHeight = 220;

  /// How long the Copy button says "Copied".
  static const Duration copiedFor = Duration(seconds: 2);

  @override
  State<ToolValuePanel> createState() => _ToolValuePanelState();
}

class _ToolValuePanelState extends State<ToolValuePanel> {
  late ToolValueShape _shape = _decide();
  Timer? _copiedTimer;
  var _copied = false;

  ToolValueShape _decide() => toolValueShape(
    widget.text,
    language: widget.language,
    settled: widget.settled,
  );

  @override
  void didUpdateWidget(ToolValuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.language != widget.language ||
        oldWidget.settled != widget.settled) {
      _shape = _decide();
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final l10n = context.l10n;
    final view = View.of(context);
    final direction = Directionality.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
    } on Object {
      return;
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(ToolValuePanel.copiedFor, () {
      if (mounted) setState(() => _copied = false);
    });
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        l10n.chatWidgetsToolValueCopied,
        direction,
      ).catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = ToolValueLabel(
      label: widget.label,
      language: _shape.language,
    );
    final copy = widget.showCopy
        ? ToolValueCopyButton(
            label: switch (widget.section) {
              ToolValueSection.input => l10n.chatWidgetsToolValueCopyInput,
              ToolValueSection.result => l10n.chatWidgetsToolValueCopyResult,
              ToolValueSection.error => l10n.chatWidgetsToolValueCopyError,
            },
            copied: _copied,
            onPressed: _copy,
          )
        : null;
    final notice = switch (_shape.notice) {
      ToolValueNotice.none => null,
      ToolValueNotice.tooLongToColour =>
        l10n.chatWidgetsToolValueNoticeTooLongToColour,
      ToolValueNotice.tooLongForTree =>
        l10n.chatWidgetsToolValueNoticeTooLongForTree,
      ToolValueNotice.tooDeepForTree =>
        l10n.chatWidgetsToolValueNoticeTooDeepForTree,
    };
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_shape.offersTree)
            ToolJsonView(
              text: widget.text,
              nodes: _shape.tree,
              header: label,
              actions: [?copy],
              initiallyTree: widget.initiallyTree,
              bodyMaxHeight: ToolValuePanel.maxHeight,
              section: widget.section,
            )
          else ...[
            ToolValueHeader(label: label, actions: [?copy]),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: ToolValuePanel.maxHeight,
              ),
              child: SingleChildScrollView(
                child: ToolValueView(
                  text: widget.text,
                  language: _shape.language,
                  settled: widget.settled,
                ),
              ),
            ),
          ],
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                notice,
                key: const ValueKey('tool-value-notice'),
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.hermesColors.subtleText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
