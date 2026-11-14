import 'lenient_read.dart';

/// Names one background program of one chat on one connection. A stop
/// confirmation holds the key it started with, so a list that refreshes or
/// reorders never moves it to another program.
final class ProcessKey {
  const ProcessKey({
    required this.threadId,
    required this.profile,
    required this.connection,
    required this.processId,
  });

  final String threadId;
  final String? profile;

  /// The token of the connection the program was seen on (compared by
  /// identity).
  final Object connection;

  /// The registry id `agent.terminal.output` carries as `process_id` and
  /// `process.list` as `session_id`.
  final String processId;

  @override
  bool operator ==(Object other) =>
      other is ProcessKey &&
      threadId == other.threadId &&
      profile == other.profile &&
      identical(connection, other.connection) &&
      processId == other.processId;

  @override
  int get hashCode =>
      Object.hash(threadId, profile, identityHashCode(connection), processId);

  @override
  String toString() => 'ProcessKey()';
}

/// What Hermes' program list says of a program.
enum ProgramStatus {
  running,

  /// Exited with `completion_reason: killed`, whatever the code.
  stopped,

  /// Exited on its own with a code (0 included).
  exited,

  /// Exited without a code, or a status the app does not know.
  ended,
}

/// Hermes keeps this many characters of a program's output in
/// `output_tail`; a tail this long was cut at its start.
const kProcessTailChars = 4000;

ProgramStatus programStatusOf({
  required bool running,
  String? completionReason,
  int? exitCode,
}) {
  if (running) return ProgramStatus.running;
  if (completionReason == 'killed') return ProgramStatus.stopped;
  return exitCode == null ? ProgramStatus.ended : ProgramStatus.exited;
}

/// One row of `process.list`. The working directory and pid are not kept.
final class ListedProcess {
  const ListedProcess({
    required this.id,
    required this.running,
    this.command,
    this.exitCode,
    this.completionReason,
    this.uptime,
    this.outputTail,
    this.unknownStatus = false,
  });

  final String id;

  /// The row's status was a word the app does not know: the program reads
  /// as ended whatever its code, so a code never claims a clean exit.
  final bool unknownStatus;

  /// As Hermes gave it, already cut to 200 characters there.
  final String? command;
  final bool running;
  final int? exitCode;
  final String? completionReason;
  final Duration? uptime;

  /// The last [kProcessTailChars] characters of the output.
  final String? outputTail;

  ProgramStatus get status => unknownStatus
      ? ProgramStatus.ended
      : programStatusOf(
          running: running,
          completionReason: completionReason,
          exitCode: exitCode,
        );

  @override
  String toString() => 'ListedProcess($status)';
}

final class ProcessList {
  const ProcessList(this.processes);
  final List<ListedProcess> processes;

  @override
  String toString() => 'ProcessList(${processes.length})';
}

/// The four statuses of `process.kill`; an error 4044 reads as [notFound].
enum KillOutcome { killed, alreadyExited, notFound, error }

/// A `process.kill` answer.
final class ProcessKill {
  const ProcessKill({
    required this.outcome,
    this.exitCode,
    this.completionReason,
    this.output,
    this.outputCut = false,
  });

  final KillOutcome outcome;
  final int? exitCode;
  final String? completionReason;

  /// The completion-sized tail, which overlaps what frames delivered.
  final String? output;

  /// Hermes trimmed [output] at its start.
  final bool outputCut;

  @override
  String toString() => 'ProcessKill($outcome)';
}

/// Reads a `process.list` answer; null when its rows are not a list (an
/// answer without them is not an empty list). Rows without an id are
/// skipped, and a row that is not a map is too.
ProcessList? parseProcessList(Map<String, Object?> result) {
  final rows = result['processes'];
  if (rows is! List) return null;
  final processes = <ListedProcess>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final id = readString(row['session_id']);
    if (id == null) continue;
    final status = row['status'];
    final uptime = readInt(row['uptime_seconds']);
    final tail = row['output_tail'];
    processes.add(
      ListedProcess(
        id: id,
        command: readString(row['command']),
        // The schema's default is running; any other word is an end, and
        // only `exited` is one the app knows.
        running: status == null || status == 'running',
        unknownStatus:
            status != null && status != 'running' && status != 'exited',
        exitCode: readInt(row['exit_code']),
        completionReason: readString(row['completion_reason']),
        uptime: uptime == null
            ? null
            : Duration(seconds: uptime < 0 ? 0 : uptime),
        outputTail: tail is String ? tail : null,
      ),
    );
  }
  return ProcessList(List.unmodifiable(processes));
}

/// Reads a `process.kill` answer; null for any status but the four known.
ProcessKill? parseProcessKill(Map<String, Object?> result) {
  final outcome = switch (result['status']) {
    'killed' => KillOutcome.killed,
    'already_exited' => KillOutcome.alreadyExited,
    'not_found' => KillOutcome.notFound,
    'error' => KillOutcome.error,
    _ => null,
  };
  if (outcome == null) return null;
  final output = result['output'];
  final cut = result['output_cut'];
  return ProcessKill(
    outcome: outcome,
    exitCode: readInt(result['exit_code']),
    completionReason: readString(result['completion_reason']),
    output: output is String ? output : null,
    outputCut: switch (cut) {
      bool() => cut,
      num() => cut != 0,
      String() => cut.isNotEmpty,
      _ => false,
    },
  );
}
