import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/tool_value_budget.dart';
import 'package:hermes_app/src/chat/widgets/code_tool_bodies.dart';
import 'package:hermes_app/src/chat/widgets/tool_hidden_chars.dart';
import 'package:hermes_app/src/chat/widgets/tool_value_view.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'support/code_tool_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Future<String?> _copy(WidgetTester tester) async {
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.tap(find.byKey(const ValueKey('tool-value-copy')));
  await tester.pump();
  return copied;
}

Widget _read(ToolCall call) => ReadFileToolBody.of(call)!;

void main() {
  testWidgets('Copy copies the text Hermes returned, without the numbers', (
    tester,
  ) async {
    await _pump(
      tester,
      _read(
        readCall(readAnswer(content: '1|first\r\n2|second\r', totalLines: 2)),
      ),
    );
    expect(await _copy(tester), 'first\r\nsecond\r');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('a write copies the content as sent', (tester) async {
    await _pump(tester, WriteFileToolBody.of(writeCall({'bytes_written': 3}))!);
    expect(await _copy(tester), '# Todo\n- ship it\n');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('the gutter is not selectable and not read out', (tester) async {
    await _pump(
      tester,
      SelectionArea(
        child: _read(
          readCall(readAnswer(content: numbered(['alpha', 'beta']))),
        ),
      ),
    );
    final gutter = find.text('1');
    expect(gutter, findsOneWidget);
    // The code registers with the surrounding selection area; the number
    // does not, so selecting and copying never carries it.
    expect(SelectionContainer.maybeOf(tester.element(gutter)), isNull);
    expect(
      SelectionContainer.maybeOf(
        tester.element(find.textContaining('alpha', findRichText: true)),
      ),
      isNotNull,
    );
    expect(
      find.ancestor(of: gutter, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
  });

  testWidgets('a selection across rows copies one line per row', (
    tester,
  ) async {
    await _pump(
      tester,
      const SelectionArea(
        child: ToolValueView(
          text: 'alpha\n\nbeta\ngamma',
          lineNumbers: [1, 2, 3, 4],
        ),
      ),
    );
    final area = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    area.selectAll(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();
    // ignore: deprecated_member_use
    area.copySelection(SelectionChangedCause.toolbar);
    await tester.pump();
    expect(copied, 'alpha\n\nbeta\ngamma');
  });

  testWidgets('the header fits at three times the text size on a narrow '
      'screen', (tester) async {
    for (final width in [200.0, 320.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesDarkTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: _read(
                    readCall(
                      readAnswer(content: numbered(['a']), totalLines: 1),
                      args: const {
                        'path':
                            'packages/app/lib/src/chat/widgets/file_sizes.dart',
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('shows Hermes\' warning and hint with a read', (tester) async {
    await _pump(
      tester,
      _read(
        readCall(
          readAnswer(
            content: numbered(['a']),
            extra: {
              '_warning': 'Read twice.',
              '_hint': 'Has conflict markers.',
            },
          ),
        ),
      ),
    );
    expect(find.text('Read twice.'), findsOneWidget);
    expect(find.text('Has conflict markers.'), findsOneWidget);
  });

  testWidgets('numbered text with no numbers draws as plain text', (
    tester,
  ) async {
    await _pump(tester, const ToolValueView(text: 'abc', lineNumbers: []));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('abc', findRichText: true), findsOneWidget);
  });

  testWidgets('the last row of a CRLF file draws no hidden character', (
    tester,
  ) async {
    await _pump(
      tester,
      _read(readCall(readAnswer(content: '1|first\r\n2|second\r'))),
    );
    expect(find.byType(HiddenCharBox), findsNothing);
  });

  testWidgets('a long path keeps the width a short tag leaves it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: _read(
              readCall(
                readAnswer(content: numbered(['a'])),
                args: const {
                  'path': 'a/long/folder/path/to/some/file_sizes.dart',
                },
              ),
            ),
          ),
        ),
      ),
    );
    // 43 characters of the test font's 12 px boxes take about 516 px; the
    // tag and Copy take the rest, so the whole path shows.
    expect(
      find.text('a/long/folder/path/to/some/file_sizes.dart'),
      findsOneWidget,
    );
  });

  testWidgets('a second large card stays plain once the budget is spent', (
    tester,
  ) async {
    final budget = ToolValueBudget(maxChars: 1500);
    Widget card(String name) => _read(
      readCall(
        readAnswer(content: numbered(List.filled(60, 'final value = 1;'))),
        args: {'path': '$name.dart'},
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: ToolValueBudgetScope(
          budget: budget,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: [card('a'), card('b')]),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Dart'), findsOneWidget);
    expect(budget.holders, 1);
    expect(find.byKey(const ValueKey('tool-value-notice')), findsOneWidget);
  });

  testWidgets('a closed code card gives its colour share back', (tester) async {
    final budget = ToolValueBudget(maxChars: 1500);
    Widget app({required bool open}) => MaterialApp(
      theme: buildHermesLightTheme(),
      home: ToolValueBudgetScope(
        budget: budget,
        child: Scaffold(
          body: open
              ? _read(
                  readCall(
                    readAnswer(
                      content: numbered(List.filled(60, 'final value = 1;')),
                    ),
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
    await tester.pumpWidget(app(open: true));
    expect(budget.holders, 1);
    await tester.pumpWidget(app(open: false));
    expect(budget.holders, 0);
    expect(budget.used, 0);
  });

  testWidgets('a single line reads Line n, not Lines n–n', (tester) async {
    await _pump(
      tester,
      _read(
        readCall(
          readAnswer(content: numbered(['only'], first: 5), totalLines: 90),
          args: const {'path': 'a.txt', 'offset': 5},
        ),
      ),
    );
    expect(find.text('Line 5 of 90'), findsOneWidget);
  });

  testWidgets('a write shows its hint and path warning', (tester) async {
    await _pump(
      tester,
      WriteFileToolBody.of(
        writeCall({
          'bytes_written': 1,
          '_warning': 'Resolved to /srv.',
          'hint': 'Prefer patch.',
        }),
      )!,
    );
    expect(find.text('Resolved to /srv.'), findsOneWidget);
    expect(find.text('Prefer patch.'), findsOneWidget);
  });

  testWidgets('every note has an icon and a word', (tester) async {
    await _pump(
      tester,
      _read(
        readCall(
          readAnswer(
            content: numbered(['a']),
            totalLines: 90,
            extra: {'truncated': true, 'truncated_lines': true},
          ),
        ),
      ),
    );
    expect(find.textContaining('Cut short.'), findsOneWidget);
    expect(find.text('Some long lines were cut by Hermes.'), findsOneWidget);
    for (final note in [
      find.textContaining('Cut short.'),
      find.text('Some long lines were cut by Hermes.'),
    ]) {
      final row = find.ancestor(of: note, matching: find.byType(Row)).first;
      expect(
        find.descendant(of: row, matching: find.byType(AppIcon)),
        findsOneWidget,
      );
    }
  });

  testWidgets('a refused write says what was tried', (tester) async {
    await _pump(
      tester,
      WriteFileToolBody.of(writeCall({'error': 'File changed on disk'}))!,
    );
    expect(find.text('Not written.'), findsOneWidget);
    expect(find.text('File changed on disk'), findsOneWidget);
    expect(find.text('What Hermes tried to write'), findsOneWidget);
    expect(find.textContaining('ship it', findRichText: true), findsOneWidget);
  });

  testWidgets('a read at an offset starts its gutter there', (tester) async {
    await _pump(
      tester,
      _read(
        readCall(
          readAnswer(content: numbered(['x', 'y'], first: 2001)),
          args: const {'path': 'big.txt', 'offset': 2001},
        ),
      ),
    );
    expect(find.text('2001'), findsOneWidget);
    expect(find.text('2002'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('a binary file shows a note and no content', (tester) async {
    await _pump(
      tester,
      _read(
        readCall({
          'is_binary': true,
          'file_size': 2048,
          'error': 'Binary file (ZIP)',
          'base64_content': 'AAAASECRET',
        }),
      ),
    );
    expect(find.text('Not a text file.'), findsOneWidget);
    expect(find.textContaining('Binary file (ZIP)'), findsOneWidget);
    expect(find.textContaining('SECRET', findRichText: true), findsNothing);
    expect(find.byKey(const ValueKey('tool-value-copy')), findsNothing);
  });

  testWidgets('a binary file with no description or size has no blank line', (
    tester,
  ) async {
    await _pump(tester, _read(readCall({'is_binary': true})));
    expect(find.text('The content is never shown here.'), findsOneWidget);
  });

  testWidgets('an empty file says so instead of a blank box', (tester) async {
    await _pump(
      tester,
      _read(readCall(readAnswer(content: '', totalLines: 0))),
    );
    expect(find.text('This file is empty.'), findsOneWidget);
  });

  testWidgets('a running read shows only the path and its state', (
    tester,
  ) async {
    await _pump(tester, _read(readCall(null, status: ToolCallStatus.running)));
    expect(find.text('Reading…'), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-value-copy')), findsNothing);
  });
}
