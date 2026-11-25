// Rewrites the Flutter barrel imports to their replacement packages:
//
//   package:flutter/material.dart  ->  package:material_ui/material_ui.dart
//   package:flutter/cupertino.dart ->  package:cupertino_ui/cupertino_ui.dart
//
// Usage:
//   dart run tool/migrate_material_ui_imports.dart [--check] [path ...]
//
// With no path it covers the repo's Dart roots (lib, test, widgetbook,
// integration_test, test_driver, tool, scripts, packages). A path is a file or
// a directory; run it on just your own files after merging main.
// `--check` changes nothing and exits 1 when a file would change.
//
// Only the URI inside an `import` or `export` directive that starts a line is
// replaced (a raw `r'...'` URI included), so `show`, `hide`, `as`, comments,
// line breaks and every other line stay byte for byte. A line that only looks
// like a directive inside a multi-line string is not a directive: the Dart
// parser decides which lines are. A directive that would repeat one already in the file
// (same URI, prefix and combinators) is removed. The script is idempotent.
//
// Skipped: `packages/hermes_api` (generated client, never hand-edited; the
// generator scripts own it), `*.g.dart`, `*.freezed.dart` (build_runner
// output) and `lib/l10n/generated` (gen-l10n output). The summary names each
// skipped root or count.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _replacements = {
  'package:flutter/material.dart': 'package:material_ui/material_ui.dart',
  'package:flutter/cupertino.dart': 'package:cupertino_ui/cupertino_ui.dart',
};

const _defaultRoots = [
  'lib',
  'test',
  'widgetbook',
  'integration_test',
  'test_driver',
  'tool',
  'scripts',
  'packages',
  'benchmark',
];

const _skippedPrefixes = {
  'packages/hermes_api/': 'generated client, never hand-edited',
  'lib/l10n/generated/': 'gen-l10n output',
};

final _skippedSuffixes = {
  '.g.dart': 'build_runner output',
  '.freezed.dart': 'build_runner output',
};

/// A directive that starts a line (so a string or comment holding the text is
/// left alone): `import`/`export`, the URI, and the rest up to `;`.
final _directive = RegExp(
  r'''^([ \t]*(?:import|export)\s+)(r?)(['"])([^'"\n]+)\3([^;]*;)''',
  multiLine: true,
);

/// Any directive, to find duplicates.
final _anyDirective = RegExp(
  r'''^([ \t]*)((?:import|export)\s+r?['"][^'"\n]+['"][^;]*;)''',
  multiLine: true,
);

String _normalize(String directive) =>
    directive.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Offsets of the URI literals of the real `import` and `export` directives in
/// [source], as the Dart parser reads them.
Set<int> _directiveUriOffsets(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  return {
    for (final d in unit.directives)
      if (d is UriBasedDirective) d.uri.offset,
  };
}

/// The migrated text of [source], or [source] itself when nothing changes.
String migrate(String source) {
  final real = _directiveUriOffsets(source);
  final seen = <String>{};
  // Directives already in the file, so a rewrite that would repeat one drops.
  for (final m in _anyDirective.allMatches(source)) {
    final text = m.group(2)!;
    if (!real.contains(m.start + m.group(1)!.length + _uriStart(text))) {
      continue;
    }
    if (!_replacements.containsKey(_uriOf(text))) {
      seen.add(_normalize(text));
    }
  }

  final out = StringBuffer();
  var last = 0;
  for (final m in _directive.allMatches(source)) {
    if (!real.contains(m.start + m.group(1)!.length)) continue;
    final uri = m.group(4)!;
    final target = _replacements[uri];
    if (target == null) continue;
    final quote = m.group(3)!;
    final rewritten =
        '${m.group(1)}${m.group(2)}$quote$target$quote${m.group(5)}';
    out.write(source.substring(last, m.start));
    if (seen.add(_normalize(rewritten))) {
      out.write(rewritten);
      last = m.end;
    } else {
      // Drop the whole line (or the tail of it, when code follows on it).
      var end = m.end;
      final rest = RegExp(r'[ \t]*(\r?\n)?').matchAsPrefix(source, end)!;
      end = rest.end;
      last = end;
    }
  }
  out.write(source.substring(last));
  return out.toString();
}

/// Offset of the URI literal (its `r` prefix or quote) inside [directive].
int _uriStart(String directive) =>
    RegExp(r'''^(?:import|export)\s+''').firstMatch(directive)!.end;

String _uriOf(String directive) =>
    RegExp(r'''['"]([^'"]+)['"]''').firstMatch(directive)!.group(1)!;

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final paths = args.where((a) => a != '--check').toList();
  if (paths.any((a) => a.startsWith('-'))) {
    stderr.writeln(
      'usage: dart run tool/migrate_material_ui_imports.dart [--check] '
      '[file-or-directory ...]',
    );
    exitCode = 64;
    return;
  }

  final files = <String>{};
  for (final p in paths.isEmpty ? _defaultRoots : paths) {
    final type = FileSystemEntity.typeSync(p);
    if (type == FileSystemEntityType.file) {
      files.add(p);
    } else if (type == FileSystemEntityType.directory) {
      for (final e in Directory(p).listSync(recursive: true)) {
        if (e is File && e.path.endsWith('.dart')) files.add(e.path);
      }
    } else if (paths.isNotEmpty) {
      stderr.writeln('not found: $p');
      exitCode = 66;
      return;
    }
  }

  final skipped = <String, int>{};
  final changed = <String>[];
  for (final raw in files.toList()..sort()) {
    final path = raw.replaceAll(r'\', '/').replaceFirst(RegExp(r'^\./'), '');
    final rel = _relative(path);
    final reason = _skipReason(rel);
    if (reason != null) {
      skipped[reason] = (skipped[reason] ?? 0) + 1;
      continue;
    }
    if (!path.endsWith('.dart')) continue;
    final source = File(path).readAsStringSync();
    final migrated = migrate(source);
    if (migrated == source) continue;
    changed.add(path);
    if (!check) File(path).writeAsStringSync(migrated);
  }

  if (skipped.isNotEmpty) {
    stdout.writeln('skipped (not touched):');
    for (final e in skipped.entries) {
      stdout.writeln('  ${e.value} files: ${e.key}');
    }
  }
  if (check) {
    for (final path in changed) {
      stdout.writeln('would change: $path');
    }
    stdout.writeln(
      changed.isEmpty
          ? 'ok: no Flutter barrel imports'
          : '${changed.length} file(s) still import a Flutter barrel; '
                'run: dart run tool/migrate_material_ui_imports.dart',
    );
    exitCode = changed.isEmpty ? 0 : 1;
  } else {
    stdout.writeln('rewrote ${changed.length} file(s)');
  }
}

/// [path] relative to the current directory when it is absolute under it.
String _relative(String path) {
  final cwd = Directory.current.path.replaceAll(r'\', '/');
  return path.startsWith('$cwd/') ? path.substring(cwd.length + 1) : path;
}

String? _skipReason(String rel) {
  for (final e in _skippedPrefixes.entries) {
    if (rel.startsWith(e.key)) return '${e.key} (${e.value})';
  }
  for (final e in _skippedSuffixes.entries) {
    if (rel.endsWith(e.key)) return '*${e.key} (${e.value})';
  }
  return null;
}
