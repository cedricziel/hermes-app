/// What `rollback.*` answers, read leniently. Raw server text (reasons,
/// commands, error messages, directories) never leaves this file: a reason
/// becomes a [CheckpointReason], an error becomes a [CheckpointFailureKind].
library;

import 'dart:convert';

/// The longest diff the server sends; it cuts there without a marker.
const kCheckpointDiffLimit = 4000;

/// Why a checkpoint was taken, from the first words of the server's reason.
enum CheckpointReason { beforeEdit, beforeTerminal, beforeRestore, other }

/// Why a call failed, in words the app can show without the server's text.
enum CheckpointFailureKind {
  notFound,
  nestedRepositories,
  storeBusy,
  container,
  pathRejected,
  sessionGone,
  transport,
  other,
}

/// What the server said it was busy with (`4009`).
enum CheckpointBusyReason { replying, compressing }

class Checkpoint {
  const Checkpoint({
    required this.hash,
    required this.reason,
    this.timestamp,
    this.restoredFrom,
  });

  /// The full hash, always the one sent back (a short all-digit hash would be
  /// read by the server as an index).
  final String hash;
  final CheckpointReason reason;

  /// Null when missing or unparseable: unknown, never "now".
  final DateTime? timestamp;

  /// For a [CheckpointReason.beforeRestore], the first characters of the hash
  /// that restore went to; it tells a new safety checkpoint from an older one.
  final String? restoredFrom;

  @override
  bool operator ==(Object other) =>
      other is Checkpoint &&
      other.hash == hash &&
      other.reason == reason &&
      other.timestamp == timestamp &&
      other.restoredFrom == restoredFrom;

  @override
  int get hashCode => Object.hash(hash, reason, timestamp, restoredFrom);
}

sealed class CheckpointList {
  const CheckpointList();
}

final class CheckpointsOff extends CheckpointList {
  const CheckpointsOff();
}

final class CheckpointsOn extends CheckpointList {
  const CheckpointsOn(this.checkpoints);

  /// Newest first, as the server lists them.
  final List<Checkpoint> checkpoints;
}

/// `method not found`: this server has no checkpoints. Draw nothing.
final class CheckpointsUnsupported extends CheckpointList {
  const CheckpointsUnsupported();
}

final class CheckpointsFailed extends CheckpointList {
  const CheckpointsFailed(this.kind);
  final CheckpointFailureKind kind;
}

/// One file `rollback.diff` lists.
class ChangedFile {
  const ChangedFile({
    required this.path,
    this.restorable = false,
    this.binary = false,
    this.renamed = false,
    this.changes,
    this.added,
    this.removed,
    this.diff,
    this.cutShort = false,
  });

  /// The path as `stat` shows it, unquoted. Sent as `file_path` only when
  /// [restorable].
  final String path;

  /// Whether "Restore this file" may be offered: the path was read back
  /// exactly and cannot be read as a glob or an option.
  final bool restorable;
  final bool binary, renamed;

  /// The number `stat` prints beside the name (lines changed).
  final int? changes;

  /// Counted from [diff] when there is a section for the file.
  final int? added, removed;

  /// This file's section of the diff; null when the server cut the diff
  /// before it or sent none (a binary file has none to show).
  final String? diff;

  /// The server's cut fell inside this file's section: the last one of a diff
  /// as long as the cut. Its diff is shown but ends early.
  final bool cutShort;
}

sealed class CheckpointChanges {
  const CheckpointChanges();
}

final class Changes extends CheckpointChanges {
  const Changes(this.files, {required this.truncated});
  final List<ChangedFile> files;

  /// The diff text is as long as the server's cut, so a section may end
  /// mid-line and later files may have none.
  final bool truncated;
}

/// Both `stat` and `diff` came back empty. The server swallows its own
/// failures this way, so for a listed checkpoint it means unreadable.
final class ChangesUnreadable extends CheckpointChanges {
  const ChangesUnreadable();
}

/// The container-backend refusal: file paths belong to the container.
final class ChangesRefused extends CheckpointChanges {
  const ChangesRefused();
}

final class ChangesFailed extends CheckpointChanges {
  const ChangesFailed(this.kind);
  final CheckpointFailureKind kind;
}

sealed class CheckpointRestore {
  const CheckpointRestore();
}

final class Restored extends CheckpointRestore {
  const Restored({this.historyRemoved = 0});

  /// Messages the server removed from the chat; 0 for a one-file restore.
  final int historyRemoved;
}

/// Files are back but the chat was not rewound (5021 with that text).
final class RestoredHistoryNotRewound extends CheckpointRestore {
  const RestoredHistoryNotRewound();
}

/// Refused before anything was touched.
final class RestoreRefused extends CheckpointRestore {
  const RestoreRefused(this.kind);
  final CheckpointFailureKind kind;
}

final class RestoreBusy extends CheckpointRestore {
  const RestoreBusy(this.reason);
  final CheckpointBusyReason reason;
}

/// No answer, or the connection dropped after the request went out. The app
/// re-reads and never sends again.
final class RestoreMayHaveHappened extends CheckpointRestore {
  const RestoreMayHaveHappened();
}

final class RestoreUnsupported extends CheckpointRestore {
  const RestoreUnsupported();
}

/// Failed with files possibly touched ([filesPossiblyChanged]) or not.
final class RestoreFailed extends CheckpointRestore {
  const RestoreFailed(this.kind, {required this.filesPossiblyChanged});
  final CheckpointFailureKind kind;
  final bool filesPossiblyChanged;
}

final _hex = RegExp(r'^[0-9a-fA-F]+$');
final _digits = RegExp(r'^[0-9]+$');

/// Whether [hash] can be sent back: hex, 4 to 64 characters, and never all
/// digits (the server reads an all-digit reference of any length as a
/// 1-based index).
bool isUsableCheckpointHash(String hash) =>
    hash.length >= 4 &&
    hash.length <= 64 &&
    _hex.hasMatch(hash) &&
    !_digits.hasMatch(hash);

/// Reads `rollback.list`; null when the answer does not look like one.
CheckpointList? parseCheckpointList(Map<String, Object?> result) {
  if (result['enabled'] != true) {
    return result['enabled'] == false ? const CheckpointsOff() : null;
  }
  final rows = result['checkpoints'];
  final checkpoints = <Checkpoint>[];
  if (rows is List) {
    for (final row in rows) {
      if (row is! Map) continue;
      final hash = row['hash'];
      if (hash is! String || !isUsableCheckpointHash(hash)) continue;
      final message = row['message'];
      final (reason, restoredFrom) = _readReason(message);
      final stamp = row['timestamp'];
      checkpoints.add(
        Checkpoint(
          hash: hash,
          reason: reason,
          restoredFrom: restoredFrom,
          timestamp: stamp is String ? DateTime.tryParse(stamp) : null,
        ),
      );
    }
  }
  return CheckpointsOn(List.unmodifiable(checkpoints));
}

final _restoringTo = RegExp(r'restoring to ([0-9a-f]{8})(?![0-9a-f])');

(CheckpointReason, String?) _readReason(Object? message) {
  if (message is! String) return (CheckpointReason.other, null);
  final text = message.trimLeft().toLowerCase();
  if (text.startsWith('before write_file') || text.startsWith('before patch')) {
    return (CheckpointReason.beforeEdit, null);
  }
  if (text.startsWith('before terminal')) {
    return (CheckpointReason.beforeTerminal, null);
  }
  if (text.startsWith('pre-rollback snapshot')) {
    final target = _restoringTo.firstMatch(text)?.group(1);
    return (CheckpointReason.beforeRestore, target);
  }
  return (CheckpointReason.other, null);
}

/// The container-backend refusal text (`terminal.backend=docker` and the
/// like), recognised by its prefix.
bool isContainerRefusal(String message) =>
    message.startsWith('Checkpoints are not taken for terminal.backend');

/// Reads `rollback.diff`: the file list from `stat`, each file's section of
/// `diff` beside it.
CheckpointChanges parseCheckpointChanges(Map<String, Object?> result) {
  final stat = result['stat'] is String ? result['stat'] as String : '';
  final diff = result['diff'] is String ? result['diff'] as String : '';
  if (stat.trim().isEmpty && diff.trim().isEmpty) {
    return const ChangesUnreadable();
  }
  final sections = parseDiff(diff);
  // The cut falls inside the last section of a diff as long as the limit.
  final cutKey = diff.length >= kCheckpointDiffLimit && sections.isNotEmpty
      ? sections.keys.last
      : null;
  final listed = parseStat(stat);
  final files = <ChangedFile>[];
  final used = <String>{};
  for (final entry in listed) {
    var key = entry.path;
    if (!sections.containsKey(key) && key.startsWith('...')) {
      // git shortens long names in `stat`; match the unique section that ends
      // the same way. Such a name is never offered for a one-file restore.
      final tail = key.substring(3);
      final matches = [
        for (final path in sections.keys)
          if (path.endsWith(tail)) path,
      ];
      if (matches.length == 1) key = matches.single;
    }
    used.add(key);
    files.add(
      _withSection(entry, sections[key], cut: cutKey != null && key == cutKey),
    );
  }
  // A diff with no stat still lists its files, but a path that did not come
  // from `stat` is never offered for a one-file restore.
  for (final entry in sections.entries) {
    if (used.add(entry.key)) {
      files.add(
        _withSection(
          ChangedFile(path: entry.key),
          entry.value,
          cut: cutKey != null && entry.key == cutKey,
        ),
      );
    }
  }
  return Changes(
    List.unmodifiable(files),
    truncated: diff.length >= kCheckpointDiffLimit,
  );
}

ChangedFile _withSection(
  ChangedFile file,
  String? section, {
  bool cut = false,
}) {
  var added = 0, removed = 0;
  if (section != null) {
    var inHunk = false;
    for (final line in section.split('\n')) {
      if (line.startsWith('@@')) {
        inHunk = true;
      } else if (inHunk && line.startsWith('+')) {
        added++;
      } else if (inHunk && line.startsWith('-')) {
        removed++;
      }
    }
  }
  return ChangedFile(
    path: file.path,
    restorable: file.restorable,
    binary: file.binary,
    renamed: file.renamed,
    changes: file.changes,
    // Counts of a section the server cut would be too low: the `stat` total
    // stands in for them.
    added: section == null || file.binary || cut ? null : added,
    removed: section == null || file.binary || cut ? null : removed,
    diff: section,
    cutShort: cut && !file.binary,
  );
}

/// Whether [path] is safe to send as a one-file restore: git would take it
/// literally and it stays inside the folder.
bool _exactPath(String path) {
  if (path.isEmpty || path == '.' || path.startsWith('-')) return false;
  if (path.startsWith('/') || path.startsWith('...')) return false;
  if (RegExp(r'[\[\]*?\\:\x00-\x1f]').hasMatch(path)) return false;
  return !path.split('/').any((part) => part == '..' || part.isEmpty);
}

/// Reads `git diff --stat` lines: `path | N +++---`, `path | Bin 0 -> 12
/// bytes` and the trailing summary (ignored). A rename shows its new path and
/// is not offered for a one-file restore.
List<ChangedFile> parseStat(String stat) {
  final files = <ChangedFile>[];
  for (final line in stat.split('\n')) {
    final bar = line.lastIndexOf(' | ');
    if (bar < 0) continue;
    final name = line.substring(0, bar).trim();
    final rest = line.substring(bar + 3).trim();
    if (name.isEmpty) continue;
    final binary = rest.startsWith('Bin');
    final count = binary ? null : int.tryParse(rest.split(' ').first);
    if (!binary && count == null) continue;
    final renamed = name.contains(' => ');
    final path = renamed ? _renamedTo(name) : _unquote(name);
    if (path == null) {
      // A quoted name that cannot be decoded is listed by what it shows and
      // never offered for a one-file restore.
      files.add(ChangedFile(path: name, binary: binary, changes: count));
      continue;
    }
    files.add(
      ChangedFile(
        path: path,
        binary: binary,
        renamed: renamed,
        changes: count,
        restorable: !renamed && _exactPath(path),
      ),
    );
  }
  return files;
}

String? _renamedTo(String name) {
  final braces = RegExp(r'^(.*)\{(.*) => (.*)\}(.*)$').firstMatch(name);
  if (braces != null) {
    final joined = '${braces[1]}${braces[3]}${braces[4]}';
    return joined.replaceAll('//', '/');
  }
  final parts = name.split(' => ');
  return parts.length == 2 ? _unquote(parts[1].trim()) : null;
}

/// Undoes git's C-style quoting of a name; a name that is not quoted comes
/// back as it is. Null when the quoting cannot be read back.
String? _unquote(String name) {
  if (!(name.length >= 2 && name.startsWith('"') && name.endsWith('"'))) {
    return name;
  }
  final body = name.substring(1, name.length - 1);
  final bytes = <int>[];
  final runes = body.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    if (runes[i] != 0x5C) {
      bytes.addAll(utf8.encode(String.fromCharCode(runes[i])));
      continue;
    }
    if (++i >= runes.length) return null;
    final next = String.fromCharCode(runes[i]);
    switch (next) {
      case 't':
        bytes.add(9);
      case 'n':
        bytes.add(10);
      case '"' || r'\':
        bytes.add(runes[i]);
      default:
        if (i + 3 > runes.length) return null;
        final octal = String.fromCharCodes(runes.sublist(i, i + 3));
        if (!RegExp(r'^[0-7]{3}$').hasMatch(octal)) return null;
        bytes.add(int.parse(octal, radix: 8));
        i += 2;
    }
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

/// Splits `git diff` text into one section per file, by the path after `b/`.
/// A section ends where the next `diff --git` begins; the last may end
/// mid-line when the server cut the text.
Map<String, String> parseDiff(String diff) {
  final sections = <String, String>{};
  final lines = diff.split('\n');
  String? path;
  var start = 0;
  void close(int end) {
    final current = path;
    if (current != null) {
      sections[current] = lines.sublist(start, end).join('\n');
    }
  }

  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('diff --git ')) continue;
    close(i);
    path = _headerPath(lines[i].substring('diff --git '.length), lines, i + 1);
    start = i;
  }
  close(lines.length);
  return sections;
}

String? _headerPath(String header, List<String> lines, int next) {
  if (header.startsWith('"')) {
    final match = RegExp(r'^"(?:[^"\\]|\\.)*" ("(?:[^"\\]|\\.)*")$')
        .firstMatch(header);
    final quoted = match?.group(1);
    final path = quoted == null ? null : _unquote(quoted);
    return path != null && path.startsWith('b/') ? path.substring(2) : null;
  }
  if (!header.startsWith('a/')) return null;
  // `a/<p> b/<p>`: the two halves are equal unless the file was renamed.
  final both = header.substring(2);
  for (
    var at = both.indexOf(' b/');
    at >= 0;
    at = both.indexOf(' b/', at + 1)
  ) {
    if (both.substring(0, at) == both.substring(at + 3)) {
      return both.substring(0, at);
    }
  }
  // Renamed: git names the new path in `rename to`.
  for (
    var i = next;
    i < lines.length && !lines[i].startsWith('diff --git ');
    i++
  ) {
    if (lines[i].startsWith('rename to ')) {
      return _unquote(lines[i].substring('rename to '.length));
    }
    if (lines[i].startsWith('@@')) break;
  }
  final split = both.lastIndexOf(' b/');
  return split < 0 ? null : both.substring(split + 3);
}
