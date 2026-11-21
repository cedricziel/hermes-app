import 'dart:io';

import 'allowlist.dart';
import 'scanner.dart';

/// The allowlist the CLI and the ratchet test both apply.
const allowlistPath = 'tool/style_score_allowlist.yaml';

/// Every finding in the `.dart` files under [root] that the scan does not
/// skip, in path order, with no allowlist applied. Paths are `/`-separated and
/// relative to the directory the process runs in (the repository root).
List<Finding> scanTree(Directory root) {
  final files =
      root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => !isSkipped(p))
          .toList()
        ..sort();
  return [
    for (final path in files)
      ...scanSource(File(path).readAsStringSync(), path: path),
  ];
}

/// Scans `lib/` and applies the allowlist: what the CLI reports and what the
/// ratchet counts. Throws [AllowlistError] on a bad allowlist.
({List<Finding> findings, int allowlisted, List<AllowEntry> unused})
measureLib({String allowlist = allowlistPath}) {
  final allow = loadAllowlist(allowlist);
  final applied = applyAllowlist(scanTree(Directory('lib')), allow);
  return (
    findings: applied.kept,
    allowlisted: applied.allowed,
    unused: unusedEntries(allow),
  );
}
