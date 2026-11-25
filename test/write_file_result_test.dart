import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/write_file_result.dart';

import 'support/code_tool_fixtures.dart';

void main() {
  test('a write shows the content as sent, numbered from 1', () {
    final result = WriteFileResult.of(
      writeCall({'bytes_written': 17, 'dirs_created': true}),
    )!;
    expect(result.path, 'notes/todo.md');
    expect(result.rows.map((r) => r.number), [1, 2]);
    expect(result.rows.map((r) => r.text), ['# Todo', '- ship it']);
    expect(result.content, '# Todo\n- ship it\n');
    expect(result.bytesWritten, 17);
    expect(result.refused, isFalse);
  });

  test('reports verified, a lint error, diagnostics and a warning', () {
    final result = WriteFileResult.of(
      writeCall({
        'bytes_written': 312,
        'verified': true,
        'lint': {'status': 'error', 'output': 'line 3: unexpected token'},
        'lsp_diagnostics': 'main.dart:3 error',
        'warning': 'File is large',
      }),
    )!;
    expect(result.verified, isTrue);
    expect(result.lintOutput, 'line 3: unexpected token');
    expect(result.diagnostics, 'main.dart:3 error');
    expect(result.warning, 'File is large');
  });

  test('a lint that is ok or skipped says nothing', () {
    for (final status in ['ok', 'skipped']) {
      final result = WriteFileResult.of(
        writeCall({
          'bytes_written': 1,
          'lint': {'status': status, 'output': 'fine'},
        }),
      )!;
      expect(result.lintOutput, isNull, reason: status);
    }
  });

  test('an error is a refusal that keeps what was tried', () {
    final result = WriteFileResult.of(
      writeCall({'error': 'File changed on disk since it was read'}),
    )!;
    expect(result.refused, isTrue);
    expect(result.error, 'File changed on disk since it was read');
    expect(result.rows, isNotEmpty);
  });

  test('a call that has not answered yet still shows the content', () {
    final result = WriteFileResult.of(writeCall(null))!;
    expect(result.answered, isFalse);
    expect(result.rows, hasLength(2));
  });

  test('arguments that are not a path and a content are not a write', () {
    expect(WriteFileResult.of(writeCall(null, args: {'path': 'a'})), isNull);
    expect(WriteFileResult.of(writeCall(null, args: null)), isNull);
  });

  test('a result that is not an object is not a write', () {
    expect(WriteFileResult.of(writeCall(const <Object?>[1])), isNull);
  });
}
