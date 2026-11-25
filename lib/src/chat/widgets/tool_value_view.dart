import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../files/code_highlight.dart';
import '../../files/widgets/files_metrics.dart';
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
import '../../theme/hermes_code_colors.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/adaptive_segmented_control.dart';
import '../../files/widgets/safe_path_text.dart' show wellFormedText;
import '../json_tree_parser.dart';
import '../tool_value_budget.dart';
import '../tool_value_language.dart';
import 'tool_hidden_chars.dart';
import 'tool_json_tree.dart';
import '../../macos/menu_selection_area.dart';

/// The code style of a tool value. Ligatures and contextual alternates are
/// off, so `->` and `!=` stay the characters that were sent.
const TextStyle kToolMonoStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  height: 1.4,
  fontFeatures: [FontFeature.disable('liga'), FontFeature.disable('calt')],
);
const TextStyle _mono = kToolMonoStyle;

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
    this.lineNumbers,
  });

  final String text;
  final String? language;
  final bool settled;
  final bool selectable;

  /// A number per line of [text], drawn in a gutter that is not selectable.
  /// Each line is its own row, so a wrapped line keeps its number on its
  /// first row. Null draws the text alone.
  final List<int>? lineNumbers;

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
    final numbers = widget.lineNumbers;
    final text = numbers == null || numbers.isEmpty
        ? Text.rich(
            TextSpan(
              style: base,
              children: _spansFor(_runs, base, palette, budget, context),
            ),
          )
        : _numberedLines(context, base, palette, budget, numbers);
    // A selection copies the text of a box too (its escape, `U+202E`), which
    // SelectableText cannot: it turns each box into U+FFFC. Inside a
    // SelectionArea (the chat's) the text just joins that.
    if (!widget.selectable || SelectionContainer.maybeOf(context) != null) {
      return text;
    }
    return MenuSelectionArea(child: text);
  }

  List<InlineSpan> _spansFor(
    List<CodeRun> runs,
    TextStyle base,
    HermesCodeColors palette,
    HiddenBoxBudget budget,
    BuildContext context,
  ) => [
    for (final (text, token) in runs)
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

  /// [_runs] cut at their line feeds, one row per line with its number.
  Widget _numberedLines(
    BuildContext context,
    TextStyle base,
    HermesCodeColors palette,
    HiddenBoxBudget budget,
    List<int> numbers,
  ) {
    final lines = <List<CodeRun>>[[]];
    for (final (text, token) in _runs) {
      final parts = text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) lines.add([]);
        if (parts[i].isNotEmpty) lines.last.add((parts[i], token));
      }
    }
    final digits = '${numbers.reduce((a, b) => a > b ? a : b)}'.length;
    final gutter = TextPainter(
      text: TextSpan(text: '0' * digits, style: base),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = gutter.width.ceilToDouble() + 12;
    gutter.dispose();
    final muted = base.copyWith(color: context.hermesColors.subtleText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: SelectionContainer.disabled(
                  child: SizedBox(
                    width: width,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        i < numbers.length ? '${numbers[i]}' : '',
                        textAlign: TextAlign.end,
                        softWrap: false,
                        style: muted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: base,
                    children: _spansFor(
                      lines[i],
                      base,
                      palette,
                      budget,
                      context,
                    ),
                  ),
                ),
              ),
              // A selection across rows copies what the rows hold with
              // nothing between them; this line feed, which has no size and
              // is not read out, ends each line but the last.
              if (i < lines.length - 1)
                const ExcludeSemantics(
                  child: Text('\n', style: TextStyle(height: 0)),
                ),
            ],
          ),
      ],
    );
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
        // The ring is 2 px outside the round tap area, which nothing clips.
        child: FocusRing.outside(
          radius: metrics.target / 2,
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
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The switch between the text and the tree of a JSON section: the shared
/// [AdaptiveSegmentedControl] in its compact size, "Text" and "Tree", named
/// for a screen reader "Show input/result/error as". The segment that shows is
/// told by its shape (thumb, check, weight), not by colour.
class ToolViewSwitch extends StatelessWidget {
  const ToolViewSwitch({
    super.key,
    required this.tree,
    required this.onChanged,
    this.section = ToolValueSection.result,
  });

  /// Whether the tree shows.
  final bool tree;
  final ValueChanged<bool> onChanged;
  final ToolValueSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdaptiveSegmentedControl<bool>(
      key: const ValueKey('tool-json-toggle'),
      value: tree,
      semanticLabel: switch (section) {
        ToolValueSection.input => l10n.chatWidgetsToolValueShowInputAs,
        ToolValueSection.result => l10n.chatWidgetsToolValueShowResultAs,
        ToolValueSection.error => l10n.chatWidgetsToolValueShowErrorAs,
      },
      segments: {
        false: l10n.chatWidgetsToolValueViewText,
        true: l10n.chatWidgetsToolValueViewTree,
      },
      onChanged: onChanged,
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
    this.colour = true,
    this.notice,
  });

  final String text;

  /// Whether the flat text is coloured; false shows it plain.
  final bool colour;

  /// A [ToolValueNoticeLine] between the header row and the body.
  final Widget? notice;

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

  void _set(bool tree) => setState(() => _tree = tree);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ToolValueHeader(
        label: widget.header,
        actions: [
          ToolViewSwitch(tree: _tree, onChanged: _set, section: widget.section),
          ...widget.actions,
        ],
      ),
      ?widget.notice,
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: widget.bodyMaxHeight ?? double.infinity,
        ),
        child: _tree
            ? ToolJsonTree(text: widget.text, nodes: widget.nodes)
            : SingleChildScrollView(
                child: ToolValueView(
                  text: widget.text,
                  language: widget.colour ? 'json' : null,
                ),
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

/// [shape] judged against the open cards' colouring [budget]: unchanged when
/// the text takes its share (or there is no budget, or nothing would be
/// coloured), otherwise plain with no tag, the tree kept, and the budget line.
/// [owner] holds the share until it calls [ToolValueBudget.release].
({ToolValueShape shape, bool colour}) judgeToolValueColour(
  ToolValueShape shape, {
  required ToolValueBudget? budget,
  required Object owner,
  required int chars,
}) {
  if (budget == null) return (shape: shape, colour: true);
  if (shape.language == null ||
      shape.notice == ToolValueNotice.tooLongToColour) {
    budget.release(owner);
    return (shape: shape, colour: true);
  }
  if (budget.admit(owner, chars)) return (shape: shape, colour: true);
  return (
    shape: ToolValueShape(
      tree: shape.tree,
      notice: ToolValueNotice.colourBudgetSpent,
    ),
    colour: false,
  );
}

class _ToolValuePanelState extends State<ToolValuePanel> {
  late ToolValueShape _shape = _decide();
  Timer? _copiedTimer;
  var _copied = false;
  ToolValueBudget? _budget;

  /// Whether the flat text is coloured: false when the chat's budget refused.
  var _colour = true;

  ToolValueShape _decide() {
    final shape = toolValueShape(
      widget.text,
      language: widget.language,
      settled: widget.settled,
    );
    final judged = judgeToolValueColour(
      shape,
      budget: _budget ??= ToolValueBudgetScope.maybeOf(context),
      owner: this,
      chars: widget.text.length,
    );
    _colour = judged.colour;
    return judged.shape;
  }

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
    _budget?.release(this);
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
      ToolValueNotice.colourBudgetSpent =>
        l10n.chatWidgetsToolValueNoticeColourBudget,
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
              colour: _colour,
              notice: notice == null ? null : ToolValueNoticeLine(text: notice),
            )
          else ...[
            ToolValueHeader(label: label, actions: [?copy]),
            if (notice != null) ToolValueNoticeLine(text: notice),
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
        ],
      ),
    );
  }
}

/// A muted line between the label row and the body saying why the text is shown plainer than its
/// content could be: an info mark and the words. The mark is decoration; the
/// text is what a screen reader reads.
class ToolValueNoticeLine extends StatelessWidget {
  const ToolValueNoticeLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: AppIcon(AppIcons.info, size: 14, color: subtle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('tool-value-notice'),
              style: TextStyle(fontSize: 11.5, color: subtle),
            ),
          ),
        ],
      ),
    );
  }
}
