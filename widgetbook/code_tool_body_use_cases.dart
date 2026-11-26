import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/code_tool_body.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/code_tool_fixtures.dart';
import 'frame.dart';

const _source = [
  'import "dart:io";',
  '',
  '/// Prints the size of every file under [root].',
  'Future<void> main(List<String> args) async {',
  '  final root = Directory(args.isEmpty ? "." : args.first);',
  '  await for (final entry in root.list(recursive: true)) {',
  '    if (entry is File) {',
  '      print("\${entry.path}: \${await entry.length()} bytes");',
  '    }',
  '  }',
  '}',
];

const _notes = ['# Todo', '', '- ship the code view', '- write the tests'];

const _readPath = 'tools/file_sizes.dart';

Widget _card(ToolCall call, {double width = 480}) =>
    frame(ToolCallCard(call: call, initiallyOpen: true), maxWidth: width);

ToolCall _read(
  Map<String, Object?> answer, {
  String path = _readPath,
  Map<String, Object?>? args,
}) => readCall(answer, args: args ?? {'path': path});

Map<String, Object?> _complete() =>
    readAnswer(content: numbered(_source), totalLines: _source.length);

ToolCall _write(
  Map<String, Object?>? answer, {
  ToolCallStatus status = ToolCallStatus.completed,
}) => writeCall(answer, status: status);

Widget _german(Widget child) => Builder(
  builder: (context) => Localizations.override(
    context: context,
    locale: const Locale('de'),
    child: child,
  ),
);

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Widget _body(CodeToolBody body, {double width = 480}) => frame(
  DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0x33808080)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: body),
  ),
  maxWidth: width,
);

WidgetbookNode codeToolBodyNode() => WidgetbookFolder(
  name: 'Code tool views',
  children: [
    WidgetbookComponent(
      name: 'ReadFileToolBody',
      useCases: [
        WidgetbookUseCase(
          name: 'Complete',
          builder: (_) => _card(_read(_complete())),
        ),
        ...onEachPlatform('Complete', (_) => _card(_read(_complete()))),
        WidgetbookUseCase(
          name: 'At an offset',
          builder: (_) => _card(
            _read(
              readAnswer(
                content: numbered(_source, first: 2001),
                totalLines: 2400,
              ),
              args: {'path': _readPath, 'offset': 2001},
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Cut short',
          builder: (_) => _card(
            _read(
              readAnswer(
                content: numbered(_source),
                totalLines: 5320,
                extra: {'truncated': true},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Cut short by the size limit, long lines, masked',
          builder: (_) => _card(
            _read(
              readAnswer(
                content: numbered([..._source, 'token = «redacted-secret»']),
                totalLines: 5320,
                extra: {
                  'truncated': true,
                  'truncated_by': 'bytes',
                  'next_offset': 1800,
                  'truncated_lines': true,
                },
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Text taken from a document',
          builder: (_) => _card(
            _read(
              readAnswer(
                content: numbered(['Chapter one', 'It was a bright day.']),
                extra: {'extracted_document': true},
              ),
              path: 'docs/report.pdf',
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Missing, with similar files',
          builder: (_) => _card(
            _read({
              'error': 'File not found: tools/file_size.dart',
              'not_found': true,
              'similar_files': [
                'tools/file_sizes.dart',
                'tools/file_tree.dart',
              ],
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'Missing, with Hermes\' warning and hint',
          builder: (_) => _card(
            _read({
              'error': 'File not found: tools/file_size.dart',
              '_warning': 'You already looked for this file.',
              'hint': 'Check the spelling of the path.',
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'Binary',
          builder: (_) => _card(
            _read({
              'is_binary': true,
              'file_size': 48213,
              'error': 'Binary file (PNG image data, 640 x 480)',
            }, path: 'assets/logo.png'),
          ),
        ),
        WidgetbookUseCase(
          name: 'Image',
          builder: (_) => _card(
            _read({
              'is_image': true,
              'is_binary': true,
              'file_size': 2400000,
            }, path: 'assets/photo.jpg'),
          ),
        ),
        WidgetbookUseCase(
          name: 'Empty file',
          builder: (_) => _card(_read(readAnswer(content: '', totalLines: 0))),
        ),
        WidgetbookUseCase(
          name: 'Read again (unchanged)',
          builder: (_) => _card(
            _read({
              'status': 'unchanged',
              'dedup': true,
              'content_returned': false,
              'path': _readPath,
              'message': 'File unchanged since last read.',
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'Running',
          builder: (_) => _card(
            readCall(
              null,
              args: {'path': _readPath},
              status: ToolCallStatus.running,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Unexpected shape (generic view)',
          builder: (_) => _card(
            _read({'content': 'no row numbers here', 'total_lines': 1}),
          ),
        ),
        WidgetbookUseCase(
          name: 'Long path',
          builder: (_) => _card(
            _read(
              _complete(),
              path: 'packages/hermes_app/lib/src/chat/widgets/tools/very_long_folder_name/file_sizes.dart',
            ),
            width: 360,
          ),
        ),
        WidgetbookUseCase(
          name: 'German',
          builder: (_) => _german(
            _card(
              _read(
                readAnswer(
                  content: numbered(_source),
                  totalLines: 5320,
                  extra: {'truncated': true},
                ),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text, narrow',
          builder: (_) => _scaled(
            3,
            _card(
              _read(
                _complete(),
                path: 'packages/app/lib/src/chat/widgets/file_sizes.dart',
              ),
              width: 320,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _scaled(3, _card(_read(_complete()), width: 390)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'WriteFileToolBody',
      useCases: [
        WidgetbookUseCase(
          name: 'Preparing',
          builder: (_) => _card(
            writeCall(
              null,
              args: null,
              status: ToolCallStatus.running,
              preparing: true,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Running',
          builder: (_) => _card(
            writeCall(
              null,
              args: {'path': 'notes/todo.md', 'content': _notes.join('\n')},
              status: ToolCallStatus.running,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Complete, verified',
          builder: (_) => _card(
            _write({
              'bytes_written': 312,
              'verified': true,
              'dirs_created': true,
            }),
          ),
        ),
        ...onEachPlatform(
          'Complete, verified',
          (_) => _card(_write({'bytes_written': 312, 'verified': true})),
        ),
        WidgetbookUseCase(
          name: 'Syntax problem and diagnostics',
          builder: (_) => _card(
            writeCall(
              {
                'bytes_written': 4300,
                'lint': {
                  'status': 'error',
                  'output':
                      'tools/file_sizes.dart:7:5: Expected an identifier.',
                },
                'lsp_diagnostics': 'file_sizes.dart:7 error: expected ";"',
                'warning': 'The file is larger than the editor limit.',
              },
              args: {'path': _readPath, 'content': _source.join('\n')},
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Refused',
          builder: (_) => _card(
            _write({
              'error': 'The file changed on disk since it was read. Read it again before writing.',
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'Refused, with warning and hint',
          builder: (_) => _card(
            _write({
              'error': 'The file changed on disk since it was read.',
              '_warning': 'The path resolved to /srv/notes/todo.md.',
              'hint': 'Read the file again before writing it.',
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'Refused, no content',
          builder: (_) => _card(
            writeCall(
              {'error': 'The file changed on disk since it was read.'},
              args: {'path': 'notes/todo.md', 'content': ''},
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Refused, German',
          builder: (_) => _german(
            _card(
              _write({'error': 'The file changed on disk since it was read.'}),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'CodeToolBody',
      useCases: [
        WidgetbookUseCase(
          name: 'A wrapped long line',
          builder: (_) => _body(
            CodeToolBody(
              path: 'README.md',
              language: 'markdown',
              rows: const [
                (number: 1, text: '# Notes'),
                (
                  number: 2,
                  text: 'A very long line that does not fit on one row of a phone screen, so it wraps and keeps its number on the first row only, then goes on and on.',
                ),
                (number: 3, text: 'Last line'),
              ],
              meta: 'Lines 1–3 of 3',
            ),
            width: 340,
          ),
        ),
        WidgetbookUseCase(
          name: '2,000 lines',
          builder: (_) => _body(
            CodeToolBody(
              path: 'data/rows.txt',
              rows: [
                for (var i = 1; i <= 2000; i++)
                  (number: i, text: 'line $i of the generated file'),
              ],
              meta: 'Lines 1–2,000 of 5,320',
              trailing: const [
                CodeNote(
                  CodeNoteTone.warning,
                  'Cut short. Lines 1–2,000 of 5,320. The next read starts at line 2,001.',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ],
);
