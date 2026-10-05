import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/markdown_entities.dart';

void main() {
  test('inserts a blank line between a bold paragraph line and a table', () {
    const markdown =
        '**Neu & cool seit letzter Woche:**\n'
        '| Modell | Kontext | Note |\n'
        '|---|---|---|\n'
        '| GPT-6 | 1M | Neu! |\n';
    expect(
      insertTableBlankLines(markdown),
      '**Neu & cool seit letzter Woche:**\n\n'
      '| Modell | Kontext | Note |\n'
      '|---|---|---|\n'
      '| GPT-6 | 1M | Neu! |\n',
    );
  });

  test('inserts a blank line between a plain paragraph and a table', () {
    const markdown = 'Some intro text\n| a | b |\n| --- | --- |\n| 1 | 2 |';
    expect(
      insertTableBlankLines(markdown),
      'Some intro text\n\n| a | b |\n| --- | --- |\n| 1 | 2 |',
    );
  });

  test('leaves a table that already follows a blank line unchanged', () {
    const markdown = 'Intro\n\n| a | b |\n|---|---|\n| 1 | 2 |';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('leaves a table that starts the message unchanged', () {
    const markdown = '| a | b |\n|---|---|\n| 1 | 2 |';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('does not split a multi-row table after its delimiter row', () {
    const markdown = 'Intro\n| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |';
    expect(
      insertTableBlankLines(markdown),
      'Intro\n\n| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |',
    );
  });

  test('does not touch a horizontal rule after a paragraph', () {
    const markdown = 'Intro\n---\nMore text';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test(
    'leaves prose before a delimiter without a matching header unchanged',
    () {
      const markdown = 'Intro\nMore prose\n|---|---|';
      expect(insertTableBlankLines(markdown), markdown);
    },
  );

  test('leaves a mismatched table header unchanged', () {
    const markdown = 'Intro\n| One |\n|---|---|';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('separates a one-column table from a paragraph', () {
    const markdown = 'Intro\n| Name |\n| --- |\n| Ada |';
    expect(
      insertTableBlankLines(markdown),
      'Intro\n\n| Name |\n| --- |\n| Ada |',
    );
  });

  test('does not insert a blank line inside a closed code fence', () {
    const markdown =
        'Text\n\n'
        '```markdown\n'
        '| a | b |\n'
        '|---|---|\n'
        '```\n';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('does not insert a blank line inside a still-streaming code fence', () {
    const markdown = '```dart\nfinal t = |\n|---|---|\n';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('keeps a four-backtick fence open after three backticks', () {
    const markdown =
        '````markdown\n'
        '```\n'
        'Prose\n'
        '| a | b |\n'
        '|---|---|\n'
        '````';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('keeps a fence open when a different marker looks like a close', () {
    const markdown =
        '~~~markdown\n'
        '```\n'
        'Prose\n'
        '| a | b |\n'
        '|---|---|\n'
        '~~~';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('keeps a fence open when a closing marker has trailing text', () {
    const markdown =
        '```markdown\n'
        '```not closed\n'
        'Prose\n'
        '| a | b |\n'
        '|---|---|\n'
        '```';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('does not touch a table inside inline code', () {
    const markdown = 'Use `|---|---|` to delimit tables.';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test('separates a table that follows a code fence', () {
    const markdown = '```py\nx\n```\n| a | b |\n|---|---|\n| 1 | 2 |';
    expect(
      insertTableBlankLines(markdown),
      '```py\nx\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |',
    );
  });

  test('leaves consecutive tables separated by blank lines unchanged', () {
    const markdown =
        'Intro\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nOutro\n\n| e | f |\n|---|---|\n';
    expect(insertTableBlankLines(markdown), markdown);
  });

  test(
    'is streaming-safe: blank line appears once the delimiter row arrives',
    () {
      const header = '**Models**\n| a | b |\n';
      expect(insertTableBlankLines(header), header);
      final complete = insertTableBlankLines('$header|---|---|\n');
      expect(complete, '**Models**\n\n| a | b |\n|---|---|\n');
      // Re-normalizing already-normalized text is stable.
      expect(insertTableBlankLines(complete), complete);
    },
  );

  test('normalizeMarkdown decodes entities and separates the table', () {
    const markdown =
        'A &amp; B\n'
        '| a | b |\n'
        '|---|---|\n';
    expect(normalizeMarkdown(markdown), 'A & B\n\n| a | b |\n|---|---|\n');
  });

  test('normalizeMarkdown decodes entity-encoded pipes before splitting', () {
    const markdown = 'A &#124; B\n| a | b |\n|---|---|\n';
    expect(normalizeMarkdown(markdown), 'A | B\n\n| a | b |\n|---|---|\n');
  });
}
