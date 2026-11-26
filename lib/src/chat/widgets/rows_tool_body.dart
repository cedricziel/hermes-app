import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart' show wellFormedText;
import '../../widgets/disclosure_tile.dart';
import '../chat_models.dart';
import '../rows_result.dart';
import 'code_tool_body.dart' show CodeNote, CodeNoteTone, codeCaption;
import 'tool_rows_table.dart';
import 'tool_value_view.dart';

/// What a tool call whose result is a list of flat rows shows: a table, and
/// for a file search the words for no match and for a search cut short. Null
/// from [of] for a result that is not that shape, so the card keeps its
/// generic input and result.
class RowsToolBody extends StatelessWidget {
  const RowsToolBody._({required this.call, this.result});

  final ToolCall call;

  /// Null while a file search runs.
  final RowsResult? result;

  static Widget? of(ToolCall call) {
    // A failed call shows its error as the generic card does.
    if (call.preparing || call.status == ToolCallStatus.error) return null;
    if (call.resultData == null && call.result.isEmpty) {
      return call.name == 'search_files' &&
              call.status == ToolCallStatus.running
          ? RowsToolBody._(call: call)
          : null;
    }
    final result = RowsResult.of(call);
    return result == null ? null : RowsToolBody._(call: call, result: result);
  }

  CodeNote _note(AppLocalizations l10n, RowsNote note) => switch (note.kind) {
    RowsNoteKind.stoppedEarly => CodeNote(
      CodeNoteTone.warning,
      l10n.chatWidgetsRowsStoppedEarly(note.count!),
    ),
    // Hermes' words say why; a number in them is shown as the headline.
    RowsNoteKind.heldBack when note.count != null => CodeNote(
      CodeNoteTone.warning,
      l10n.chatWidgetsRowsHeldBack(note.count!),
      detail: note.text,
    ),
    RowsNoteKind.heldBack ||
    RowsNoteKind.warning => CodeNote(CodeNoteTone.warning, note.text),
    RowsNoteKind.hint => CodeNote(CodeNoteTone.info, note.text),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = this.result;
    if (result == null) {
      return ToolRowsTable(
        state: ToolRowsState.running,
        statusLabel: l10n.chatWidgetsRowsSearching,
      );
    }
    final count = result.rows.length;
    final columns = result.columns.length + result.moreColumns;
    final table = ToolRowsTable(
      columns: result.columns,
      rows: result.rows,
      moreColumns: result.moreColumns,
      unit: result.unit,
      total: result.total,
      summary: result.isEmpty
          ? ''
          : switch (result.unit) {
              RowsUnit.matches => l10n.chatWidgetsRowsSummaryMatches(
                count,
                columns,
              ),
              RowsUnit.rows => l10n.chatWidgetsRowsSummaryRows(count, columns),
            },
      notes: [for (final note in result.notes) _note(l10n, note)],
      emptyLabel: l10n.chatWidgetsRowsNoMatches,
    );
    // The table replaces the generic result: what it does not show (columns
    // past the eighth, a map's other values) stays reachable here.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        table,
        DisclosureTile(
          dense: true,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            l10n.chatWidgetsRowsRawResult,
            style: codeCaption(context),
          ),
          children: [
            // Built only once opened: encoding a large result is not free.
            Builder(
              builder: (context) => ToolValuePanel(
                label: l10n.chatWidgetsRowsRawResult,
                text: wellFormedText(_rawResult()),
                language: 'json',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _rawResult() => call.result.isNotEmpty
      ? call.result
      : const JsonEncoder.withIndent('  ').convert(call.resultData);
}
