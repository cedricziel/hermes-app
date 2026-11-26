import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/files_metrics.dart';
import '../../files/widgets/safe_path_text.dart' show safePathText;
import '../../theme/focus_ring.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../../widgets/focusable_tap.dart';
import '../report_chat_bug.dart';
import '../rows_result.dart' show RowsUnit;
import 'code_tool_body.dart';
import 'tool_value_view.dart';

/// Where the call stands: Hermes is working ([running]) or it answered
/// ([done]).
enum ToolRowsState { running, done }

/// A list of flat rows in a tool call card: a header that stays while the
/// rows scroll, rows of one line, numbers on the right, 50 rows and Show 50
/// more up to 500, and Copy row (as JSON) on a long press or a secondary
/// click. A plain model: the parser of the result fills it, and it holds no
/// controller.
class ToolRowsTable extends StatefulWidget {
  const ToolRowsTable({
    super.key,
    this.columns = const [],
    this.rows = const [],
    this.moreColumns = 0,
    this.unit = RowsUnit.rows,
    this.total,
    this.summary = '',
    this.notes = const [],
    this.emptyLabel = '',
    this.state = ToolRowsState.done,
    this.statusLabel = '',
  });

  /// The columns shown, in order.
  final List<String> columns;

  /// Every row with all its keys; Copy row copies all of them.
  final List<Map<String, Object?>> rows;

  /// Columns that exist but are not shown.
  final int moreColumns;
  final RowsUnit unit;

  /// How many Hermes found, when that is more than [rows] holds.
  final int? total;

  /// "12 matches · 3 columns".
  final String summary;

  /// Notes under the summary, above the table.
  final List<CodeNote> notes;

  /// The line that stands for no rows ("No matches").
  final String emptyLabel;
  final ToolRowsState state;

  /// "Searching…", for a call that has not answered.
  final String statusLabel;

  /// Rows shown at first and added by each Show more.
  static const pageSize = 50;

  /// The most rows that ever show.
  static const rowCap = 500;

  @override
  State<ToolRowsTable> createState() => _ToolRowsTableState();
}

const _cellPadding = 8.0;
const _minColumn = 64.0;
const _maxColumn = 220.0;
const _measuredRows = 20;

final _numberStyle = kToolMonoStyle.copyWith(
  fontFeatures: [
    ...?kToolMonoStyle.fontFeatures,
    const FontFeature.tabularFigures(),
  ],
);

String _cellText(Object? value) => switch (value) {
  null => '—',
  String text => safePathText(text),
  _ => '$value',
};

class _ToolRowsTableState extends State<ToolRowsTable> {
  var _shown = ToolRowsTable.pageSize;
  var _copied = false;
  Timer? _copiedTimer;
  ({List<Map<String, Object?>> rows, List<String> columns, TextScaler scaler})?
  _measuredFor;
  List<double> _widths = const [];
  List<bool> _numericColumns = const [];

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  bool _numeric(String column) {
    var any = false;
    for (final row in widget.rows) {
      final value = row[column];
      if (value == null) continue;
      if (value is! num) return false;
      any = true;
    }
    return any;
  }

  /// Each column as wide as its longest cell of the first rows, between the
  /// smallest and the largest width.
  List<double> _measure(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final measured = _measuredFor;
    if (measured != null &&
        identical(measured.rows, widget.rows) &&
        identical(measured.columns, widget.columns) &&
        measured.scaler == scaler) {
      return _widths;
    }
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    );
    double of(String text, TextStyle style) {
      painter
        ..text = TextSpan(text: text, style: style)
        ..layout();
      return painter.width;
    }

    final head = _headStyle(context);
    _widths = [
      for (final column in widget.columns)
        (widget.rows
                    .take(_measuredRows)
                    .map((row) => of(_cellText(row[column]), kToolMonoStyle))
                    .fold(of(column, head), math.max) +
                2 * _cellPadding)
            .clamp(_minColumn * scaler.scale(1), _maxColumn * scaler.scale(1)),
    ];
    painter.dispose();
    _numericColumns = [for (final column in widget.columns) _numeric(column)];
    _measuredFor = (rows: widget.rows, columns: widget.columns, scaler: scaler);
    return _widths;
  }

  TextStyle _headStyle(BuildContext context) => codeCaption(context).copyWith(
    fontWeight: FontWeight.w600,
    color: context.hermesColors.subtleText,
  );

  Future<void> _copyRow(Map<String, Object?> row) async {
    final l10n = context.l10n;
    final view = View.of(context);
    final direction = Directionality.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: jsonEncode(row)));
    } on Object catch (error, stack) {
      reportChatBug(error, stack, 'a rows table copy');
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

  Future<void> _showMenu(Map<String, Object?> row, Offset at) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final copy = await showRingMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
        at & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: true,
          child: Text(context.l10n.chatWidgetsRowsCopyRow),
        ),
      ],
    );
    if (copy ?? false) await _copyRow(row);
  }

  String _rowLabel(int index) {
    final l10n = context.l10n;
    final row = widget.rows[index];
    return [
      l10n.chatWidgetsRowsRowLabel(index + 1, widget.rows.length),
      for (final column in widget.columns)
        '$column ${switch (row[column]) {
          null || '' => l10n.chatWidgetsRowsEmptyCell,
          final value => _cellText(value),
        }}',
    ].join(', ');
  }

  Widget _row(
    int index,
    List<double> widths,
    List<bool> numeric,
    double height,
  ) {
    final row = widget.rows[index];
    final divider = Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      key: ValueKey('rows-table-row-$index'),
      container: true,
      excludeSemantics: true,
      label: _rowLabel(index),
      customSemanticsActions: {
        CustomSemanticsAction(label: context.l10n.chatWidgetsRowsCopyRow): () =>
            _copyRow(row),
      },
      // Enter and Space on a focused row open the same menu as a long press or
      // a secondary click.
      child: Builder(
        builder: (rowContext) => FocusRing(
          radius: 4,
          child: FocusableTap(
            mouseCursor: SystemMouseCursors.basic,
            onActivate: () {
              final box = rowContext.findRenderObject()! as RenderBox;
              _showMenu(row, box.localToGlobal(box.size.center(Offset.zero)));
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (details) =>
                  _showMenu(row, details.globalPosition),
              onSecondaryTapUp: (details) =>
                  _showMenu(row, details.globalPosition),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: divider)),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < widths.length; i++)
                      _cell(
                        widths[i],
                        numeric[i],
                        height,
                        Text(
                          _cellText(row[widget.columns[i]]),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: (numeric[i] ? _numberStyle : kToolMonoStyle)
                              .copyWith(
                                color: row[widget.columns[i]] == null
                                    ? context.hermesColors.subtleText
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(double width, bool numeric, double height, Widget child) =>
      SizedBox(
        width: width,
        height: height,
        child: Align(
          alignment: numeric
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _cellPadding),
            child: child,
          ),
        ),
      );

  Widget _grid(BuildContext context, double available, int visible) {
    final scaler = MediaQuery.textScalerOf(context);
    var widths = _measure(context);
    final natural = widths.fold(0.0, (sum, width) => sum + width);
    final fits = natural <= available;
    if (fits && natural > 0) {
      widths = [for (final width in widths) width * available / natural];
    }
    final width = fits ? available : natural;
    final numeric = _numericColumns;
    final rowHeight =
        scaler.scale(kToolMonoStyle.fontSize!) * kToolMonoStyle.height! +
        2 * _cellPadding;
    final scheme = Theme.of(context).colorScheme;
    final header = DecoratedBox(
      key: const ValueKey('rows-table-header'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widths.length; i++)
            _cell(
              widths[i],
              numeric[i],
              rowHeight,
              Text(
                safePathText(widget.columns[i]),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: _headStyle(context),
              ),
            ),
        ],
      ),
    );
    final table = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(header: true, child: header),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: ToolValuePanel.maxHeight - rowHeight,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemExtent: rowHeight + 1,
              itemCount: visible,
              itemBuilder: (context, index) =>
                  _row(index, widths, numeric, rowHeight),
            ),
          ),
        ],
      ),
    );
    return fits
        ? table
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final widget = this.widget;
    final subtle = context.hermesColors.subtleText;
    final rows = widget.rows;
    final limit = math.min(rows.length, ToolRowsTable.rowCap);
    final visible = math.min(_shown, limit);
    final all = math.max(widget.total ?? 0, rows.length);
    final more = math.min(ToolRowsTable.pageSize, limit - visible);
    final capped = visible >= ToolRowsTable.rowCap && all > visible;
    final remainder = visible < all;
    final footer = !remainder
        ? null
        : capped
        ? l10n.chatWidgetsRowsCapped(visible, all)
        : switch (widget.unit) {
            RowsUnit.matches => l10n.chatWidgetsRowsShowingMatches(
              visible,
              all,
            ),
            RowsUnit.rows => l10n.chatWidgetsRowsShowingRows(visible, all),
          };
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.summary,
                style: codeCaption(context).copyWith(color: subtle),
              ),
            ),
          if (widget.state == ToolRowsState.running)
            CodeRunningLine(label: widget.statusLabel),
          for (final note in widget.notes) CodeNoteView(note),
          if (widget.state == ToolRowsState.done && rows.isEmpty)
            if (widget.emptyLabel.isNotEmpty)
              CodeNoteView(CodeNote(CodeNoteTone.info, widget.emptyLabel)),
          if (rows.isNotEmpty && widget.columns.isNotEmpty) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) => _grid(context, box.maxWidth, visible),
            ),
            if (widget.moreColumns > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.chatWidgetsRowsMoreColumns(widget.moreColumns),
                  style: codeCaption(context).copyWith(color: subtle),
                ),
              ),
            if (footer != null || _copied)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  if (footer != null)
                    Text(
                      footer,
                      style: codeCaption(context).copyWith(color: subtle),
                    ),
                  if (more > 0 && visible < limit)
                    TextButton(
                      key: const ValueKey('rows-table-more'),
                      style: FilesMetrics.of(context).buttonStyle(),
                      onPressed: () => setState(() => _shown = visible + more),
                      child: Text(l10n.chatWidgetsRowsShowMore(more)),
                    ),
                  if (_copied)
                    Text(
                      l10n.chatWidgetsToolValueCopied,
                      style: codeCaption(context).copyWith(color: subtle),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
