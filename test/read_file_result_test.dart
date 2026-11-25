import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/read_file_result.dart';

import 'support/code_tool_fixtures.dart';

ReadFileResult? _parse(ToolCall call) => ReadFileResult.of(call);

void main() {
  group('an ordinary read', () {
    test('shows code and no note when truncated, is_binary, is_image and '
        'not_found are all false', () {
      final result = _parse(
        readCall(readAnswer(content: numbered(['a', 'b']), totalLines: 2)),
      )!;
      expect(result.kind, ReadFileKind.code);
      expect(result.truncated, isFalse);
      expect(result.longLinesCut, isFalse);
      expect(result.maskedText, isFalse);
      expect(result.extractedDocument, isFalse);
    });

    test('decodes a JSON text in result when resultData is null', () {
      final result = _parse(
        readCall(
          null,
          text:
              '{"content": "1|a\\n2|b", "total_lines": 2, "truncated": false}',
        ),
      )!;
      expect(result.rows.map((r) => r.text), ['a', 'b']);
    });

    test('keeps a gutter number per row, and the offset of the read', () {
      final result = _parse(
        readCall(
          readAnswer(content: numbered(['x', 'y'], first: 2001)),
          args: const {'path': 'big.txt', 'offset': 2001},
        ),
      )!;
      expect(result.rows.map((r) => r.number), [2001, 2002]);
    });

    test('a row that fails the pattern makes the whole result null', () {
      expect(
        _parse(readCall(readAnswer(content: '1|a\nnot a row\n3|c'))),
        isNull,
      );
      expect(
        _parse(readCall(readAnswer(content: '<persisted-output>…'))),
        isNull,
      );
    });

    test('a result with no content text is null', () {
      expect(_parse(readCall({'total_lines': 3})), isNull);
      expect(_parse(readCall(const <Object?>[])), isNull);
    });

    test(
      'a row ending in a carriage return and a row holding U+2028 parse',
      () {
        final result = _parse(
          readCall(readAnswer(content: '1|first\r\n2|has\u2028break\r')),
        )!;
        expect(result.rows.map((r) => r.text), ['first\r', 'has\u2028break\r']);
      },
    );

    test('an empty content is an empty file, not a code view', () {
      final result = _parse(readCall(readAnswer(content: '', totalLines: 0)))!;
      expect(result.kind, ReadFileKind.empty);
      expect(result.rows, isEmpty);
    });

    test('an empty content past the end of the file says so', () {
      final result = _parse(
        readCall(
          readAnswer(content: '', totalLines: 10),
          args: const {'path': 'a.txt', 'offset': 50},
        ),
      )!;
      expect(result.kind, ReadFileKind.pastEnd);
    });
  });

  group('notes', () {
    test('truncated without truncated_by has no character sentence', () {
      final result = _parse(
        readCall(
          readAnswer(
            content: numbered(['a', 'b']),
            totalLines: 5320,
            extra: {'truncated': true},
          ),
        ),
      )!;
      expect(result.truncated, isTrue);
      expect(result.truncatedByBytes, isFalse);
      expect(result.nextLine, 3);
    });

    test('truncated_by bytes takes the next line from next_offset', () {
      final result = _parse(
        readCall(
          readAnswer(
            content: numbered(['a', 'b']),
            totalLines: 900,
            extra: {
              'truncated': true,
              'truncated_by': 'bytes',
              'next_offset': 120,
            },
          ),
        ),
      )!;
      expect(result.truncatedByBytes, isTrue);
      expect(result.nextLine, 120);
    });

    test('truncated_lines gives the long-line note', () {
      final result = _parse(
        readCall(
          readAnswer(
            content: numbered(['a ... [truncated]']),
            extra: {'truncated_lines': true},
          ),
        ),
      )!;
      expect(result.longLinesCut, isTrue);
    });

    test('dirs_created and file_size show nothing', () {
      final result = _parse(
        readCall(
          readAnswer(content: numbered(['a']), extra: {'dirs_created': true}),
        ),
      )!;
      expect(result.truncated, isFalse);
      expect(result.kind, ReadFileKind.code);
    });

    test('extracted_document gives the note', () {
      final result = _parse(
        readCall(
          readAnswer(
            content: numbered(['Chapter one']),
            extra: {'extracted_document': true},
          ),
        ),
      )!;
      expect(result.extractedDocument, isTrue);
    });

    for (final masked in [
      'token = «redacted:ghp_abc…»',
      'password = «redacted-secret»',
      '[REDACTED PRIVATE KEY]',
    ]) {
      test('content with $masked gets the masked-text note', () {
        final result = _parse(
          readCall(readAnswer(content: '1|ok\n5|$masked')),
        )!;
        expect(result.maskedText, isTrue);
        expect(result.rows.map((r) => r.number), [1, 5]);
      });
    }

    test('keeps Hermes\' _warning and _hint for the view', () {
      final result = _parse(
        readCall(
          readAnswer(
            content: numbered(['a']),
            extra: {
              '_warning': 'You already read this file.',
              '_hint': 'The file has merge conflict markers.',
            },
          ),
        ),
      )!;
      expect(result.warning, 'You already read this file.');
      expect(result.hint, 'The file has merge conflict markers.');
    });

    test('a bare *** is not taken for masked text', () {
      final result = _parse(readCall(readAnswer(content: '1|key = ***')))!;
      expect(result.maskedText, isFalse);
    });
  });

  group('a read that did not show text', () {
    test('is_binary wins over error', () {
      final result = _parse(
        readCall({
          'is_binary': true,
          'file_size': 4096,
          'error': 'Binary file (PNG image data)',
        }),
      )!;
      expect(result.kind, ReadFileKind.notText);
      expect(result.fileSize, 4096);
      expect(result.error, 'Binary file (PNG image data)');
    });

    test('is_image is not a text file either', () {
      final result = _parse(
        readCall({'is_image': true, 'is_binary': true, 'file_size': 10}),
      )!;
      expect(result.kind, ReadFileKind.notText);
    });

    test('base64_content never reaches the model', () {
      final result = _parse(
        readCall({
          'is_binary': true,
          'is_image': true,
          'base64_content': 'SECRETBYTES',
          'mime_type': 'image/png',
          'file_size': 10,
        }),
      )!;
      expect(result.toString(), isNot(contains('SECRETBYTES')));
      expect(result.error, isEmpty);
    });

    test('an error is a failed read, with the similar files', () {
      final result = _parse(
        readCall({
          'error': 'File not found',
          'not_found': true,
          'similar_files': ['lib/main.dart', 'lib/main_test.dart', 3],
        }),
      )!;
      expect(result.kind, ReadFileKind.failed);
      expect(result.error, 'File not found');
      expect(result.similarFiles, ['lib/main.dart', 'lib/main_test.dart']);
    });

    test('a repeated read answers the dedup stub', () {
      final result = _parse(
        readCall({
          'status': 'unchanged',
          'dedup': true,
          'content_returned': false,
          'path': 'lib/main.dart',
          'message': 'File unchanged since last read.',
        }),
      )!;
      expect(result.kind, ReadFileKind.unchanged);
      expect(result.rows, isEmpty);
    });
  });

  group('the call', () {
    test('without a path is not a read the view knows', () {
      expect(_parse(readCall(readAnswer(content: '1|a'), args: {})), isNull);
      expect(_parse(readCall(readAnswer(content: '1|a'), args: null)), isNull);
    });

    test('with no result yet has nothing to show', () {
      expect(_parse(readCall(null)), isNull);
    });
  });
}
