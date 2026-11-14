import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_widget_parts.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// Where the output read stands.
enum AgentOutputStatus { loading, ready, none, never }

/// What [AgentOutputView] draws.
class AgentOutputModel {
  const AgentOutputModel({
    this.text = '',
    this.status = AgentOutputStatus.ready,
    this.truncated = false,
    this.refreshFailed = false,
    this.paused = false,
    this.last = false,
  });

  final String text;
  final AgentOutputStatus status;

  /// Hermes sent only the latest part.
  final bool truncated;

  /// The last refresh failed; [text] is what the last good read held.
  final bool refreshFailed;

  /// The reader holds the shown text, so a refresh does not move it.
  final bool paused;

  /// The agent ended: the title says so and nothing refreshes.
  final bool last;
}

/// The output prefix is `HH:MM:SS role     | `, 19 characters.
const _prefixColumns = 19;
final _prefixPattern = RegExp(r'^\d{2}:\d{2}:\d{2} [^|]{0,12}\| ?');

/// The agent's recent output as selectable plain text in a bounded,
/// monospaced box that follows the end.
///
/// Lines wrap with a hanging indent under the message column (none at the
/// accessibility text sizes, where the size follows the user with no cap).
/// Nothing in the text is a link or is interpreted. The area is not a live
/// region and never takes focus. [onHolding] reports whether the reader holds
/// the text (a selection, or scrolled away from the end); the caller then
/// pauses its refresh and shows [AgentOutputModel.paused].
class AgentOutputView extends StatelessWidget {
  const AgentOutputView({
    super.key,
    required this.model,
    required this.onJumpToLatest,
    this.onHolding,
    this.maxHeight,
  });

  final AgentOutputModel model;
  final VoidCallback onJumpToLatest;
  final ValueChanged<bool>? onHolding;

  /// The box's height limit; by default 290 pt at phone widths and 230 pt
  /// in a wider layout.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgentSectionTitle(
          model.last
              ? l10n.chatSubagentsOutputTitleLast
              : l10n.chatSubagentsOutputTitle,
        ),
        if (model.truncated && model.status == AgentOutputStatus.ready)
          AgentSubtleText(l10n.chatSubagentsOutputTruncated),
        const SizedBox(height: 8),
        switch (model.status) {
          AgentOutputStatus.loading => _loading(context),
          AgentOutputStatus.none => AgentSubtleText(
            l10n.chatSubagentsOutputNone,
          ),
          AgentOutputStatus.never => AgentSubtleText(
            l10n.chatSubagentsOutputNever,
          ),
          AgentOutputStatus.ready => _OutputBox(
            model: model,
            onJumpToLatest: onJumpToLatest,
            onHolding: onHolding,
            maxHeight: maxHeight,
          ),
        },
        if (model.refreshFailed && model.status == AgentOutputStatus.ready)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AgentSubtleText(l10n.chatSubagentsOutputRefreshFailed),
          ),
      ],
    );
  }

  Widget _loading(BuildContext context) => Row(
    children: [
      const ExcludeSemantics(
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: AgentSubtleText(context.l10n.chatSubagentsOutputLoading)),
    ],
  );
}

class _OutputBox extends StatefulWidget {
  const _OutputBox({
    required this.model,
    required this.onJumpToLatest,
    required this.onHolding,
    required this.maxHeight,
  });

  final AgentOutputModel model;
  final VoidCallback onJumpToLatest;
  final ValueChanged<bool>? onHolding;
  final double? maxHeight;

  @override
  State<_OutputBox> createState() => _OutputBoxState();
}

class _OutputBoxState extends State<_OutputBox> {
  final _scroll = ScrollController();
  var _selected = false;
  final _selection = GlobalKey<SelectionAreaState>();
  var _away = false;
  var _faded = false;
  var _holding = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrolled);
    WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd());
  }

  @override
  void didUpdateWidget(_OutputBox old) {
    super.didUpdateWidget(old);
    final m = widget.model;
    if (old.model.text != m.text && !m.paused && !_away) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd());
    }
    if (old.model.paused && !m.paused) {
      _away = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _scrolled() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final away = p.maxScrollExtent - p.pixels > 24;
    final faded = p.pixels > 1;
    if (away != _away || faded != _faded) {
      setState(() {
        _away = away;
        _faded = faded;
      });
    }
    _report();
  }

  void _report() {
    final holding = _selected || _away;
    if (holding == _holding) return;
    _holding = holding;
    widget.onHolding?.call(holding);
  }

  void _jump() {
    // Jump to latest clears the selection and resumes following.
    _selection.currentState?.selectableRegion.clearSelection();
    setState(() {
      _away = false;
      _selected = false;
    });
    _report();
    widget.onJumpToLatest();
    _toEnd();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final apple = Theme.of(context).platform == TargetPlatform.iOS;
    final large = agentLargeText(context);
    final scaler = MediaQuery.textScalerOf(context);
    final style = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier New'],
      fontSize: apple ? 12 : 13,
      height: 1.4,
      color: scheme.onSurface,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final base = widget.maxHeight ?? (box.maxWidth < 480 ? 290.0 : 230.0);
        // Five lines stay visible however large the text gets.
        final fiveLines = 5 * scaler.scale(style.fontSize! * style.height!);
        final height = large && fiveLines + 24 > base ? fiveLines + 24 : base;
        final lines = widget.model.text.split('\n');
        final indent = large ? 0.0 : _indent(lines, style, scaler, context);
        return Semantics(
          container: true,
          label: context.l10n.chatSubagentsOutputLabel,
          child: Stack(
            children: [
              Container(
                constraints: BoxConstraints(maxHeight: height),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _faded ? Colors.transparent : Colors.black,
                      Colors.black,
                    ],
                    stops: [0, (24 / rect.height).clamp(0.0, 1.0)],
                  ).createShader(rect),
                  child: SelectionArea(
                    key: _selection,
                    onSelectionChanged: (content) {
                      _selected = content != null && content.plainText != '';
                      _report();
                    },
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        12,
                        12,
                        widget.model.paused ? 56 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final line in lines)
                            _Line(line: line, style: style, indent: indent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.model.paused)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _PausedPill(onJump: _jump),
                ),
            ],
          ),
        );
      },
    );
  }

  double _indent(
    List<String> lines,
    TextStyle style,
    TextScaler scaler,
    BuildContext context,
  ) {
    var columns = _prefixColumns;
    for (final line in lines) {
      final m = _prefixPattern.firstMatch(line);
      if (m != null && m.end > columns) columns = m.end;
    }
    final painter = TextPainter(
      text: TextSpan(text: '0' * columns, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line, required this.style, required this.indent});

  final String line;
  final TextStyle style;
  final double indent;

  @override
  Widget build(BuildContext context) {
    if (indent == 0) return Text(line.isEmpty ? ' ' : line, style: style);
    final m = _prefixPattern.firstMatch(line);
    final prefix = m?.group(0) ?? '';
    final body = line.substring(prefix.length);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: indent,
          child: Text(prefix, style: style, softWrap: false, maxLines: 1),
        ),
        Expanded(child: Text(body.isEmpty ? ' ' : body, style: style)),
      ],
    );
  }
}

class _PausedPill extends StatelessWidget {
  const _PausedPill({required this.onJump});

  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            ExcludeSemantics(
              child: AppIcon(
                AppIcons.pause,
                size: 16,
                color: context.hermesColors.subtleText,
              ),
            ),
            Text(l10n.chatSubagentsOutputPaused),
            TextButton(
              onPressed: onJump,
              style: TextButton.styleFrom(
                minimumSize: Size(0, agentTargetHeight(context)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              child: Text(l10n.chatSubagentsOutputJump),
            ),
          ],
        ),
      ),
    );
  }
}
