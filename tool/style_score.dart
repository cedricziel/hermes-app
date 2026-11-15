// Measures how far lib/ is from the design system: hand-written colours,
// off-scale spacing and radii, literal font sizes, dialogs built outside the
// shared helpers, non-adaptive controls and English strings in widgets.
// Read-only; see .claude/skills/hill-climb-style/SKILL.md.
//
//   dart run tool/style_score.dart [--json] [--category a.color]
//       [--area chat] [--top 20] [--no-list]
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'style_score/allowlist.dart';
import 'style_score/measure.dart';
import 'style_score/report.dart';
import 'style_score/scanner.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
    ..addOption('category', help: 'Only this category, e.g. a.color.')
    ..addOption('area', help: 'Only this area, e.g. chat (or lib).')
    ..addOption('top', defaultsTo: '20', help: 'Offender files to show.')
    ..addFlag(
      'ratchet-yaml',
      negatable: false,
      help: 'Print rule -> path: count YAML (baseline shape) and nothing else.',
    )
    ..addFlag('no-list', negatable: false, help: 'Skip the per-hit list.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n${parser.usage}');
    exit(64);
  }
  if (opts.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }
  if (!Directory('lib').existsSync()) {
    stderr.writeln('run from the repository root');
    exit(64);
  }

  final ({List<Finding> findings, int allowlisted, List<AllowEntry> unused})
  applied;
  try {
    applied = measureLib();
  } on AllowlistError catch (e) {
    stderr.writeln('$allowlistPath: $e');
    exit(65);
  }
  var findings = applied.findings;
  final category = opts.option('category');
  final area = opts.option('area');
  if (category != null) {
    findings = findings.where((f) => f.category == category).toList();
  }
  if (area != null) {
    findings = findings.where((f) => areaOf(f.path) == area).toList();
  }
  final report = StyleReport(
    findings,
    allowlisted: applied.allowlisted,
    unused: applied.unused,
  );
  final list = !opts.flag('no-list');
  if (opts.flag('ratchet-yaml')) {
    stdout.write(report.ratchetYaml());
  } else if (opts.flag('json')) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(report.toJson(list: list)),
    );
  } else {
    stdout.write(report.text(top: int.parse(opts.option('top')!), list: list));
  }
}
