import 'dart:convert';
import 'dart:math';

/// Fixed fixtures for the chat benchmark. Everything is generated from a seed,
/// so every run feeds the app the same bytes; the text is invented.
const _words = [
  'lantern',
  'harbor',
  'copper',
  'meadow',
  'quartz',
  'orbit',
  'willow',
  'ember',
  'canyon',
  'marble',
  'thistle',
  'glacier',
  'violet',
  'anchor',
  'bramble',
  'cinder',
  'drift',
  'echo',
  'fable',
  'garnet',
  'hollow',
  'iris',
  'juniper',
  'kestrel',
  'ledger',
  'mosaic',
  'nectar',
  'opal',
  'pebble',
  'quill',
  'ripple',
  'saffron',
  'tundra',
  'umber',
  'velvet',
  'wander',
  'yarrow',
  'zephyr',
  'the',
  'and',
  'of',
  'with',
  'across',
  'beneath',
  'before',
  'while',
  'carries',
  'follows',
  'gathers',
  'settles',
  'in',
  'a',
  'to',
  'from',
  'slowly',
  'quietly',
  'often',
  'rarely',
];

String sentence(Random r, {int min = 6, int max = 16}) {
  final n = min + r.nextInt(max - min + 1);
  final out = [for (var i = 0; i < n; i++) _words[r.nextInt(_words.length)]];
  out[0] = out[0][0].toUpperCase() + out[0].substring(1);
  return '${out.join(' ')}.';
}

/// Prose with inline Markdown: bold, italics, code spans and links.
String paragraph(Random r, {int sentences = 4}) {
  final parts = <String>[];
  for (var i = 0; i < sentences; i++) {
    var s = sentence(r);
    switch (r.nextInt(6)) {
      case 0:
        s = s.replaceFirst(
          RegExp(r'\b\w{6,}\b'),
          '**${_words[r.nextInt(38)]}**',
        );
      case 1:
        s = s.replaceFirst(
          RegExp(r'\b\w{5,}\b'),
          '`${_words[r.nextInt(38)]}_${r.nextInt(99)}`',
        );
      case 2:
        s = s.replaceFirst(RegExp(r'\b\w{5,}\b'), '*${_words[r.nextInt(38)]}*');
      case 3:
        s = s.replaceFirst(
          RegExp(r'\b\w{5,}\b'),
          '[${_words[r.nextInt(38)]}](https://example.test/${_words[r.nextInt(38)]})',
        );
    }
    parts.add(s);
  }
  return parts.join(' ');
}

int wordCount(String text) => RegExp(r'\S+').allMatches(text).length;

/// About [words] words of mixed Markdown: headings, paragraphs, lists and
/// quotes, the way a long answer reads.
String markdownReply(int words, {int seed = 1}) {
  final r = Random(seed);
  final out = StringBuffer();
  var section = 0;
  while (wordCount(out.toString()) < words) {
    if (section % 6 == 0) {
      out.write(
        '## Part ${section ~/ 6 + 1}: ${sentence(r, min: 3, max: 6)}\n\n',
      );
    }
    switch (section % 6) {
      case 2:
        for (var i = 0; i < 5; i++) {
          out.write('- ${sentence(r)}\n');
        }
        out.write('\n');
      case 4:
        out.write('> ${paragraph(r, sentences: 2)}\n\n');
      default:
        out.write('${paragraph(r, sentences: 3 + r.nextInt(3))}\n\n');
    }
    section++;
  }
  return out.toString();
}

/// Source-looking lines: stable, varied, with a few long ones.
String codeLines(Random r, int lines, {String indent = ''}) {
  final out = StringBuffer();
  for (var i = 0; i < lines; i++) {
    final w = _words[r.nextInt(38)];
    switch (i % 5) {
      case 0:
        out.writeln(
          '${indent}final $w${i}Result = await service.fetch$w(id: $i, retries: ${r.nextInt(5)});',
        );
      case 1:
        out.writeln(
          '${indent}if ($w${i - 1}Result.isEmpty) { return <String, Object?>{"$w": $i}; }',
        );
      case 2:
        out.writeln('$indent// ${sentence(r, min: 4, max: 9)}');
      case 3:
        out.writeln(
          '${indent}for (final item in items.where((e) => e.${w}Count > $i)) {',
        );
      default:
        out.writeln(
          '$indent  print("$w \${item.name} -> ${r.nextInt(100000)}");',
        );
    }
  }
  return out.toString();
}

/// A reply with [blocks] fenced code blocks between short paragraphs; block
/// [bigIndex] holds [bigLines] lines, the others 25 to 70.
String codeReply({
  int blocks = 12,
  int bigIndex = 6,
  int bigLines = 2000,
  int seed = 2,
}) {
  final r = Random(seed);
  const langs = ['dart', 'python', 'json', 'bash', 'yaml', 'sql', 'typescript'];
  final out = StringBuffer();
  for (var b = 0; b < blocks; b++) {
    out.write('${paragraph(r, sentences: 2)}\n\n');
    final lines = b == bigIndex ? bigLines : 25 + r.nextInt(46);
    out.write('```${langs[b % langs.length]}\n${codeLines(r, lines)}```\n\n');
  }
  out.write(paragraph(r));
  return out.toString();
}

/// [fences] code fences with nothing between the markers, each after a short
/// line of prose.
String emptyFenceReply(int fences, {int seed = 11}) {
  final r = Random(seed);
  final out = StringBuffer();
  for (var i = 0; i < fences; i++) {
    out.write('${sentence(r, min: 3, max: 6)}\n\n```\n```\n\n');
  }
  return out.toString();
}

Map<String, Object?> bigJson(Random r, {int keys = 40, int depth = 2}) => {
  for (var i = 0; i < keys; i++)
    '${_words[r.nextInt(38)]}_$i': switch (i % 4) {
      0 => sentence(r, min: 8, max: 20),
      1 => r.nextInt(1000000),
      2 =>
        depth > 0
            ? bigJson(r, keys: 6, depth: depth - 1)
            : [for (var j = 0; j < 8; j++) r.nextInt(500)],
      _ => [for (var j = 0; j < 5; j++) sentence(r, min: 3, max: 6)],
    },
};

/// A GFM table of [rows] rows and [cols] columns, with a short lead-in.
String table(Random r, {int rows = 30, int cols = 5}) {
  final out = StringBuffer()
    ..writeln(
      '| ${[for (var c = 0; c < cols; c++) _words[r.nextInt(38)]].join(' | ')} |',
    )
    ..writeln('| ${List.filled(cols, '---').join(' | ')} |');
  for (var i = 0; i < rows; i++) {
    out.writeln(
      '| ${[for (var c = 0; c < cols; c++) c == 0 ? 'row$i' : (c == 1 ? '`${_words[r.nextInt(38)]}`' : sentence(r, min: 1, max: 4))].join(' | ')} |',
    );
  }
  return out.toString();
}

String tableReply({int tables = 8, int rows = 30, int seed = 3}) {
  final r = Random(seed);
  final out = StringBuffer();
  for (var t = 0; t < tables; t++) {
    out.write(
      '### ${sentence(r, min: 2, max: 4)}\n\n${paragraph(r, sentences: 2)}\n\n',
    );
    out.write('${table(r, rows: rows)}\n');
  }
  return out.toString();
}

String listReply({int lists = 25, int items = 40, int seed = 4}) {
  final r = Random(seed);
  final out = StringBuffer();
  for (var l = 0; l < lists; l++) {
    out.write('### ${sentence(r, min: 2, max: 4)}\n\n');
    for (var i = 0; i < items; i++) {
      final marker = l.isEven ? '- ' : '${i + 1}. ';
      out.write('$marker${sentence(r, min: 5, max: 14)}\n');
      if (i % 5 == 2) {
        out.write(
          '${l.isEven ? '  ' : '   '}- **${_words[r.nextInt(38)]}**: ${sentence(r, min: 3, max: 8)}\n',
        );
        out.write(
          '${l.isEven ? '  ' : '   '}- ${sentence(r, min: 3, max: 8)}\n',
        );
      }
    }
    out.write('\n');
  }
  return out.toString();
}

/// Splits [text] into deltas of about [size] characters, cut at word breaks
/// where possible, like a model streaming tokens.
List<String> deltas(String text, {int size = 24}) {
  final out = <String>[];
  var i = 0;
  while (i < text.length) {
    var end = min(i + size, text.length);
    if (end < text.length) {
      final space = text.lastIndexOf(RegExp(r'[ \n]'), end);
      if (space > i) end = space + 1;
    }
    out.add(text.substring(i, end));
    i = end;
  }
  return out;
}

/// Stored chat rows, oldest first: alternating prompts and replies. [closing]
/// opens the newest row, so a benchmark can wait for it on screen.
List<Map<String, Object?>> historyRows(
  int count, {
  int seed = 5,
  String closing = '',
}) {
  final r = Random(seed);
  return [
    for (var i = 1; i <= count; i++)
      {
        'id': i,
        'role': i.isOdd ? 'user' : 'assistant',
        'content': i.isOdd
            ? sentence(r, min: 8, max: 24)
            : '${i == count ? closing : ''}${paragraph(r, sentences: 3)}\n\n'
                  '${i % 6 == 0 ? '```dart\n${codeLines(r, 8)}```\n\n' : ''}'
                  '${i % 4 == 0 ? '- ${sentence(r)}\n- ${sentence(r)}\n- ${sentence(r)}\n\n' : ''}'
                  '${paragraph(r, sentences: 2)}',
        'tool_calls': null,
        'tool_name': null,
        'tool_call_id': null,
        'reasoning': null,
        'finish_reason': i.isOdd ? null : 'stop',
        'timestamp': 1780000000.0 + i * 30,
      },
  ];
}

String compactJson(Object? value) => jsonEncode(value);
