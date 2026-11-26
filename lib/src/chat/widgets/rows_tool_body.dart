import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../chat_models.dart';
import '../rows_result.dart';
import 'code_tool_body.dart';
import 'tool_rows_table.dart';

/// What a tool call whose result is a list of flat rows shows: a table, and
/// for a file search the words for no match and for a search cut short. Null
/// from [of] for a result that is not that shape, so the card keeps its
/// generic input and result.
class RowsToolBody extends StatelessWidget {
  const RowsToolBody._({this.result});

  /// Null while a file search runs.
  final RowsResult? result;

  static Widget? of(ToolCall call) {
    if (call.preparing) return null;
    if (call.resultData == null && call.result.isEmpty) {
      return call.name == 'search_files' &&
              call.status == ToolCallStatus.running
          ? const RowsToolBody._()
          : null;
    }
    final result = RowsResult.of(call);
    return result == null ? null : RowsToolBody._(result: result);
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
    return ToolRowsTable(
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
  }
}
