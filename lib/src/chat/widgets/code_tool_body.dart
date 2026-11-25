import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart'
    show safePathText, wellFormedText;
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/busy_bar.dart';
import '../read_file_result.dart' show CodeRow;
import 'tool_value_view.dart';

/// Where the call stands: Hermes is working ([running]) or it answered
/// ([done]). While the model still writes the call there is no body at all:
/// the card's own header says "Preparing…".
enum CodeToolState { running, done }

/// How a note under or above the code reads. Each tone has an icon, so it is
/// never told by colour alone.
enum CodeNoteTone { info, success, warning, error }

/// One note of the code view: a worded line with an icon, then the server's
/// own text ([detail]) and plain text rows ([items], such as similar paths).
class CodeNote {
  const CodeNote(
    this.tone,
    this.text, {
    this.detail = '',
    this.items = const [],
  });

  final CodeNoteTone tone;
  final String text;
  final String detail;
  final List<String> items;
}

/// A file's text in a tool call card: the path (its start elided, the name
/// kept), the language, the rows with a line gutter that is not selectable, a
/// Copy button and the notes about what happened. A plain model: the parsers
/// of `read_file` and `write_file` fill it, and it holds no controller.
class CodeToolBody extends StatefulWidget {
  const CodeToolBody({
    super.key,
    this.path = '',
    this.language,
    this.rows = const [],
    this.copyText,
    this.state = CodeToolState.done,
    this.statusLabel = '',
    this.heading = '',
    this.leading = const [],
    this.meta = '',
    this.trailing = const [],
  });

  final String path;

  /// A grammar name from `toolValueLanguage`; null draws plain with no tag.
  final String? language;
  final List<CodeRow> rows;

  /// What Copy copies; the rows' text, line by line, when null.
  final String? copyText;
  final CodeToolState state;

  /// "Reading…" or "Writing…", for a call that has not answered.
  final String statusLabel;

  /// A label above the code ("What Hermes tried to write").
  final String heading;

  /// Notes above the code, for a failure.
  final List<CodeNote> leading;

  /// The line under the code ("Lines 1–9 of 400").
  final String meta;

  /// Notes under the code.
  final List<CodeNote> trailing;

  @override
  State<CodeToolBody> createState() => _CodeToolBodyState();
}

class _CodeToolBodyState extends State<CodeToolBody> {
  Timer? _copiedTimer;
  var _copied = false;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  String get _text =>
      widget.copyText ?? widget.rows.map((row) => row.text).join('\n');

  Future<void> _copy() async {
    final l10n = context.l10n;
    final view = View.of(context);
    final direction = Directionality.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: _text));
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
    final subtle = context.hermesColors.subtleText;
    final widget = this.widget;
    final language = widget.language;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Flexible(child: _StartElidedPath(path: widget.path)),
                      if (language != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          toolValueTagName(context, language),
                          key: const ValueKey('tool-value-tag'),
                          style: _caption(context).copyWith(color: subtle),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.rows.isNotEmpty)
                ToolValueCopyButton(
                  label: l10n.chatWidgetsCodeCopy,
                  copied: _copied,
                  onPressed: _copy,
                ),
            ],
          ),
          if (widget.state == CodeToolState.running)
            _RunningLine(label: widget.statusLabel),
          for (final note in widget.leading) _CodeNoteView(note),
          if (widget.heading.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                widget.heading,
                style: _caption(context)
                    .copyWith(fontWeight: FontWeight.w600, color: subtle),
              ),
            ),
          if (widget.rows.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: ToolValuePanel.maxHeight,
              ),
              child: SingleChildScrollView(
                child: ToolValueView(
                  text: widget.rows.map((row) => row.text).join('\n'),
                  lineNumbers: [for (final row in widget.rows) row.number],
                  language: language,
                ),
              ),
            ),
          if (widget.meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.meta,
                style: _caption(context).copyWith(color: subtle),
              ),
            ),
          for (final note in widget.trailing) _CodeNoteView(note),
        ],
      ),
    );
  }
}

/// The caption role at the weight of running text.
TextStyle _caption(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall!
        .copyWith(fontWeight: FontWeight.w400);

class _RunningLine extends StatelessWidget {
  const _RunningLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _caption(context)
              .copyWith(color: context.hermesColors.subtleText),
        ),
        const SizedBox(height: 4),
        const BusyBar(minHeight: 2),
      ],
    ),
  );
}

class _CodeNoteView extends StatelessWidget {
  const _CodeNoteView(this.note);

  final CodeNote note;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (note.tone) {
      CodeNoteTone.info => colors.subtleText,
      CodeNoteTone.success => colors.success,
      CodeNoteTone.warning => colors.warning,
      CodeNoteTone.error => scheme.error,
    };
    final icon = switch (note.tone) {
      CodeNoteTone.info => AppIcons.info,
      CodeNoteTone.success => AppIcons.checkCircle,
      CodeNoteTone.warning => AppIcons.warning,
      CodeNoteTone.error => AppIcons.error,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: AppIcon(icon, size: 14, color: color)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wellFormedText(note.text),
                  style: _caption(context).copyWith(color: color),
                ),
                if (note.detail.isNotEmpty)
                  Text(
                    wellFormedText(note.detail),
                    style: _caption(context).copyWith(color: colors.subtleText),
                  ),
                for (final item in note.items)
                  Text(
                    safePathText(item),
                    style: kToolMonoStyle.copyWith(color: scheme.onSurface),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A path on one line with its start cut off to fit ("…/src/chat/main.dart"),
/// so the file name stays.
class _StartElidedPath extends StatelessWidget {
  const _StartElidedPath({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final style = kToolMonoStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final safe = safePathText(path);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        );
        bool fits(String text) {
          painter
            ..text = TextSpan(text: text, style: style)
            ..layout();
          return painter.width <= constraints.maxWidth;
        }

        final chars = safe.characters.toList();
        var shown = safe;
        if (!fits(safe) && chars.length > 1) {
          var low = 1;
          var high = chars.length - 1;
          while (low < high) {
            final mid = (low + high + 1) ~/ 2;
            if (fits('…${chars.sublist(chars.length - mid).join()}')) {
              low = mid;
            } else {
              high = mid - 1;
            }
          }
          shown = '…${chars.sublist(chars.length - low).join()}';
        }
        painter.dispose();
        return Semantics(
          label: safe,
          child: ExcludeSemantics(
            child: Text(
              shown,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: style,
            ),
          ),
        );
      },
    );
  }
}
