import 'json_read.dart';

/// `GET /api/actions/{name}/status`: a detached action's state and the lines
/// of its latest run.
class ActionStatus {
  const ActionStatus({
    required this.running,
    this.exitCode,
    this.actionId,
    this.startHeader,
    this.lines = const [],
    this.receipt,
  });

  static ActionStatus? parse(Object? json) {
    final root = readMap(json);
    if (root == null) return null;
    final raw = readStrings(root['lines']);
    return ActionStatus(
      running: readBool(root['running']) ?? false,
      exitCode: readInt(root['exit_code']),
      actionId: readString(root['action_id']),
      startHeader: _latestHeader(raw),
      lines: linesOfLatestRun(raw),
      receipt: root['receipt'],
    );
  }

  final bool running;

  /// Null while running, or when the dashboard restarted and nothing durable
  /// says how it ended.
  final int? exitCode;
  final String? actionId;

  /// The header that began the latest run in [lines]' tail, without its line
  /// end; null when the tail holds none. It says which run the lines belong
  /// to: a header that is not the one seen before belongs to a newer run.
  final String? startHeader;

  /// The lines after the last `=== <name> started …` header.
  final List<String> lines;

  /// The compact receipt of a `hermes-update` status, as sent.
  final Object? receipt;
}

final _startHeader = RegExp(r'^=== .+ started .* ===\s*$');

/// An action's log is append-only and every run starts with a header, so the
/// lines of the latest run are those after the last header.
List<String> linesOfLatestRun(List<String> lines) {
  final last = lines.lastIndexWhere(_startHeader.hasMatch);
  return last < 0 ? lines : lines.sublist(last + 1);
}

String? _latestHeader(List<String> lines) {
  final last = lines.lastIndexWhere(_startHeader.hasMatch);
  return last < 0 ? null : lines[last].trim();
}
