import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/file_size.dart';
import '../chat_models.dart';
import '../read_file_result.dart';
import '../tool_value_language.dart';
import '../write_file_result.dart';
import 'code_tool_body.dart';

String? _languageOf(String path) => toolValueLanguage('', path: path);

String _lines(AppLocalizations l10n, int first, int last, int? total) =>
    first == last
    ? (total == null
          ? l10n.chatWidgetsCodeLineOne(first)
          : l10n.chatWidgetsCodeLineOneOf(first, total))
    : total == null
    ? l10n.chatWidgetsCodeLinesNoTotal(first, last)
    : l10n.chatWidgetsCodeLines(first, last, total);

/// What an opened `read_file` call shows: the file's text with its own line
/// numbers, and a note for each thing Hermes did to it. Null from [of] for a
/// result that is not the shape the view expects.
class ReadFileToolBody extends StatelessWidget {
  const ReadFileToolBody._({
    required this.path,
    required this.state,
    this.result,
  });

  final String path;
  final CodeToolState state;
  final ReadFileResult? result;

  static Widget? of(ToolCall call) {
    final path = call.args?['path'];
    if (call.preparing || path is! String || path.isEmpty) return null;
    if (call.resultData == null && call.result.isEmpty) {
      return call.status == ToolCallStatus.running
          ? ReadFileToolBody._(path: path, state: CodeToolState.running)
          : null;
    }
    final result = ReadFileResult.of(call);
    return result == null
        ? null
        : ReadFileToolBody._(
            path: path,
            state: CodeToolState.done,
            result: result,
          );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = this.result;
    if (result == null) {
      return CodeToolBody(
        path: path,
        language: _languageOf(path),
        state: state,
        statusLabel: l10n.chatWidgetsCodeReading,
      );
    }
    final size = result.fileSize == null
        ? ''
        : formatByteSize(l10n, result.fileSize!);
    return switch (result.kind) {
      ReadFileKind.code => CodeToolBody(
        path: path,
        language: result.extractedDocument ? null : _languageOf(path),
        rows: result.rows,
        meta: _lines(
          l10n,
          result.firstLine!,
          result.lastLine!,
          result.totalLines,
        ),
        trailing: [
          if (result.truncated)
            CodeNote(CodeNoteTone.warning, _cutShort(l10n, result)),
          if (result.longLinesCut)
            CodeNote(CodeNoteTone.info, l10n.chatWidgetsCodeLongLinesCut),
          if (result.maskedText)
            CodeNote(CodeNoteTone.info, l10n.chatWidgetsCodeMasked),
          if (result.extractedDocument)
            CodeNote(CodeNoteTone.info, l10n.chatWidgetsCodeDocument),
          if (result.warning.isNotEmpty)
            CodeNote(CodeNoteTone.warning, result.warning),
          if (result.hint.isNotEmpty) CodeNote(CodeNoteTone.info, result.hint),
        ],
      ),
      ReadFileKind.empty => CodeToolBody(
        path: path,
        trailing: [CodeNote(CodeNoteTone.info, l10n.chatWidgetsCodeEmpty)],
      ),
      ReadFileKind.pastEnd => CodeToolBody(
        path: path,
        trailing: [
          CodeNote(CodeNoteTone.info, l10n.chatWidgetsCodeNothingAtLines),
        ],
      ),
      ReadFileKind.unchanged => CodeToolBody(
        path: path,
        trailing: [CodeNote(CodeNoteTone.info, l10n.chatWidgetsCodeUnchanged)],
      ),
      ReadFileKind.notText => CodeToolBody(
        path: path,
        leading: [
          CodeNote(
            CodeNoteTone.info,
            l10n.chatWidgetsCodeNotText,
            detail: [
              [result.error, size].where((part) => part.isNotEmpty).join(' · '),
              l10n.chatWidgetsCodeNeverShown,
            ].where((part) => part.isNotEmpty).join('\n'),
          ),
        ],
      ),
      ReadFileKind.failed => CodeToolBody(
        path: path,
        leading: [
          CodeNote(
            CodeNoteTone.error,
            l10n.chatWidgetsCodeCouldntRead,
            detail: result.error,
          ),
          if (result.similarFiles.isNotEmpty)
            CodeNote(
              CodeNoteTone.info,
              l10n.chatWidgetsCodeSimilarFiles,
              items: result.similarFiles,
            ),
        ],
      ),
    };
  }

  static String _cutShort(AppLocalizations l10n, ReadFileResult result) {
    final first = result.firstLine!;
    final last = result.lastLine!;
    final total = result.totalLines;
    final next = result.nextLine;
    return [
      l10n.chatWidgetsCodeCutShort,
      total == null
          ? l10n.chatWidgetsCodeCutShortLinesNoTotal(first, last)
          : l10n.chatWidgetsCodeCutShortLines(first, last, total),
      if (result.truncatedByBytes) l10n.chatWidgetsCodeSizeLimit,
      if (next != null) l10n.chatWidgetsCodeCutShortNext(next),
    ].join(' ');
  }
}

/// What an opened `write_file` call shows: the content as sent, coloured as
/// soon as the call runs, and what Hermes reported about the write.
class WriteFileToolBody extends StatelessWidget {
  const WriteFileToolBody._({required this.state, required this.result});

  final CodeToolState state;
  final WriteFileResult result;

  static Widget? of(ToolCall call) {
    final result = call.preparing ? null : WriteFileResult.of(call);
    if (result == null) return null;
    return WriteFileToolBody._(
      state: !result.answered && call.status == ToolCallStatus.running
          ? CodeToolState.running
          : CodeToolState.done,
      result: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = result.bytesWritten == null
        ? null
        : formatByteSize(l10n, result.bytesWritten!);
    return CodeToolBody(
      path: result.path,
      language: _languageOf(result.path),
      rows: result.rows,
      copyText: result.content,
      state: state,
      statusLabel: l10n.chatWidgetsCodeWriting,
      heading: result.refused ? l10n.chatWidgetsCodeTried : '',
      leading: [
        if (result.refused)
          CodeNote(
            CodeNoteTone.error,
            l10n.chatWidgetsCodeNotWritten,
            detail: result.error,
          ),
      ],
      trailing: [
        if (result.answered && !result.refused) ...[
          if (size != null && result.verified)
            CodeNote(
              CodeNoteTone.success,
              l10n.chatWidgetsCodeWroteChecked(size),
            )
          else if (size != null)
            CodeNote(CodeNoteTone.success, l10n.chatWidgetsCodeWrote(size))
          else if (result.verified)
            CodeNote(CodeNoteTone.success, l10n.chatWidgetsCodeCheckedOnDisk),
          if (result.lintOutput != null)
            CodeNote(
              CodeNoteTone.warning,
              l10n.chatWidgetsCodeSyntaxProblem,
              detail: result.lintOutput!,
            ),
          if (result.diagnostics.isNotEmpty)
            CodeNote(
              CodeNoteTone.info,
              l10n.chatWidgetsCodeDiagnostics,
              detail: result.diagnostics,
            ),
          if (result.warning.isNotEmpty)
            CodeNote(CodeNoteTone.warning, result.warning),
          if (result.hint.isNotEmpty) CodeNote(CodeNoteTone.info, result.hint),
        ],
      ],
    );
  }
}
