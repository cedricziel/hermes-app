import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/file_previews.dart' show HighlightedCode;
import '../../files/widgets/files_metrics.dart';
import '../../files/widgets/safe_path_text.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/named_icon_button.dart';
import '../tool_value_language.dart';

const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  height: 1.4,
);

/// A tool call's input or output as monospace text, exactly as it was sent:
/// never reformatted, only coloured. Colour follows the Files code palette
/// and its guards ([HighlightedCode]: size and span caps, a killable worker
/// for a large text, plain text for anything it will not colour), and the
/// characters that reorder or hide text are drawn as `<U+202E>` placeholders.
///
/// A call that is still running ([settled] false) is shown plain: its text
/// grows with every delta, and colouring it would start over each time.
/// [language] is a grammar name from [toolValueLanguage]; null is plain.
///
/// Selecting copies what is shown, placeholders included. [ToolValuePanel]
/// has the button that copies the original.
class ToolValueView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final style = _mono.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    if (!settled) {
      final shown = safeContentText(text);
      return selectable
          ? SelectableText(shown, style: style)
          : Text(shown, style: style);
    }
    return HighlightedCode(
      text: text,
      language: language,
      selectable: selectable,
      style: style,
    );
  }
}

/// JSON text with a labelled switch between the text as sent (the default,
/// coloured) and a collapsible tree. [header] and [actions] sit on the row of
/// the switch, so the section keeps one header line.
///
/// Which view shows is state of this widget: it survives a rebuild of its
/// parent, and ends with the widget.
class ToolJsonView extends StatefulWidget {
  const ToolJsonView({
    super.key,
    required this.text,
    this.header,
    this.actions = const [],
    this.initiallyTree = false,
    this.bodyMaxHeight,
  });

  final String text;

  /// The most height the body (text or tree) takes before it scrolls; the
  /// header row is outside it.
  final double? bodyMaxHeight;

  /// The section's label, at the start of the header row.
  final Widget? header;

  /// Buttons after the switch, such as copy.
  final List<Widget> actions;

  /// Starts on the tree; the catalog uses it to show that view.
  final bool initiallyTree;

  @override
  State<ToolJsonView> createState() => _ToolJsonViewState();
}

class _ToolJsonViewState extends State<ToolJsonView> {
  late bool _tree = widget.initiallyTree;

  @override
  Widget build(BuildContext context) {
    final metrics = FilesMetrics.of(context);
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final label = _tree
        ? l10n.chatWidgetsToolValueShowText
        : l10n.chatWidgetsToolValueShowTree;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToolValueHeader(
          label: widget.header,
          actions: [
            TextButton.icon(
              key: const ValueKey('tool-json-toggle'),
              style: metrics.buttonStyle().merge(
                TextButton.styleFrom(
                  foregroundColor: subtle,
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 12),
                ),
              ),
              onPressed: () => setState(() => _tree = !_tree),
              icon: AppIcon(
                _tree ? AppIcons.transcript : AppIcons.tree,
                size: 16,
              ),
              label: Text(label),
            ),
            ...widget.actions,
          ],
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.bodyMaxHeight ?? double.infinity,
          ),
          child: _tree
              ? ToolJsonTree(text: widget.text)
              : SingleChildScrollView(
                  child: ToolValueView(text: widget.text, language: 'json'),
                ),
        ),
      ],
    );
  }
}

/// Today's collapsible JSON tree, in the card's colours.
class ToolJsonTree extends StatelessWidget {
  const ToolJsonTree({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    return JsonView.string(
      text,
      theme: JsonViewTheme(
        backgroundColor: Colors.transparent,
        defaultTextStyle: _mono.copyWith(color: scheme.onSurface),
        keyStyle: TextStyle(color: subtle),
        stringStyle: TextStyle(color: scheme.onSurface),
        intStyle: TextStyle(color: scheme.secondary),
        doubleStyle: TextStyle(color: scheme.secondary),
        boolStyle: TextStyle(
          color: scheme.secondary,
          fontWeight: FontWeight.w600,
        ),
        openIcon: AppIcon(AppIcons.dropDown, size: 18, color: subtle),
        closeIcon: AppIcon(AppIcons.dropRight, size: 18, color: subtle),
      ),
    );
  }
}

/// The label of a section and the buttons beside it; the buttons wrap under
/// the label at large text sizes instead of squeezing it.
class ToolValueHeader extends StatelessWidget {
  const ToolValueHeader({super.key, this.label, this.actions = const []});

  final Widget? label;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ?label,
      if (actions.isNotEmpty)
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: actions),
    ],
  );
}

/// One section of a tool call card: a label, a copy button and the value in
/// [ToolValueView], capped at [maxHeight] and scrolling inside it. A settled
/// JSON object or array gets [ToolJsonView]'s Tree switch; any other text,
/// and invalid JSON, is the plain or coloured text with no switch.
///
/// The copy button copies [text] as it was sent, with no placeholder in it.
class ToolValuePanel extends StatefulWidget {
  const ToolValuePanel({
    super.key,
    required this.label,
    required this.text,
    this.language,
    this.settled = true,
    this.initiallyTree = false,
  });

  final String label;
  final String text;

  /// From [toolValueLanguage]; `json` offers the Tree switch when the text
  /// parses.
  final String? language;
  final bool settled;
  final bool initiallyTree;

  static const double maxHeight = 220;

  @override
  State<ToolValuePanel> createState() => _ToolValuePanelState();
}

class _ToolValuePanelState extends State<ToolValuePanel> {
  late bool _json = _sniff();

  bool _sniff() =>
      widget.settled &&
      widget.language == 'json' &&
      isJsonContainerText(widget.text);

  @override
  void didUpdateWidget(ToolValuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.language != widget.language ||
        oldWidget.settled != widget.settled) {
      _json = _sniff();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Text(
      widget.label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: context.hermesColors.subtleText,
      ),
    );
    final copy = NamedIconButton(
      label: context.l10n.chatWidgetsToolValueCopy(widget.label),
      icon: AppIcons.copy,
      iconSize: 16,
      style: FilesMetrics.of(context).iconButtonStyle(),
      onPressed: () => Clipboard.setData(ClipboardData(text: widget.text)),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: _json
          ? ToolJsonView(
              text: widget.text,
              header: label,
              actions: [copy],
              initiallyTree: widget.initiallyTree,
              bodyMaxHeight: ToolValuePanel.maxHeight,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToolValueHeader(label: label, actions: [copy]),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: ToolValuePanel.maxHeight,
                  ),
                  child: SingleChildScrollView(
                    child: ToolValueView(
                      text: widget.text,
                      language: widget.language,
                      settled: widget.settled,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
