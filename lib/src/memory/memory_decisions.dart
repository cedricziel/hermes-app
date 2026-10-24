import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart';

import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';

enum MemoryDecisionPhase { idle, running, saved, rejected, failed }

/// Where one staged memory write stands: [text] is Hermes' reason (or ours)
/// while [phase] is failed.
class MemoryDecisionState {
  const MemoryDecisionState(this.phase, [this.text = '']);

  static const idle = MemoryDecisionState(MemoryDecisionPhase.idle);

  final MemoryDecisionPhase phase;
  final String text;

  /// Approve and Reject are offered: nothing is running and nothing was
  /// decided yet.
  bool get canDecide =>
      phase == MemoryDecisionPhase.idle || phase == MemoryDecisionPhase.failed;
}

final _approved = RegExp(r'^\s*Approved\s+(\d+)\b');

/// Reads what `/memory approve` or `/memory reject` answered for [id].
///
/// An approval is saved when Hermes approved at least one write and names no
/// failure for [id] (its "Failed:" lines read "id: reason"). Any other
/// answer is a failure, shown as Hermes wrote it.
MemoryDecisionState parseMemoryDecisionAnswer(
  String output, {
  required String id,
  required bool approve,
}) {
  final answer = output.trim();
  if (!approve) {
    return answer.startsWith('Rejected pending memory write')
        ? const MemoryDecisionState(MemoryDecisionPhase.rejected)
        : MemoryDecisionState(MemoryDecisionPhase.failed, answer);
  }
  final reason = RegExp(
    '^\\s*${RegExp.escape(id)}:\\s*(.+)\$',
    multiLine: true,
  ).firstMatch(answer)?.group(1);
  if (reason != null) {
    return MemoryDecisionState(MemoryDecisionPhase.failed, reason.trim());
  }
  final count = int.tryParse(_approved.firstMatch(answer)?.group(1) ?? '');
  return count != null && count > 0
      ? const MemoryDecisionState(MemoryDecisionPhase.saved)
      : MemoryDecisionState(MemoryDecisionPhase.failed, answer);
}

/// Approves and rejects the staged memory writes of one chat through its
/// gateway session, and holds each one's state for as long as the chat is
/// open.
class MemoryDecisions extends ChangeNotifier {
  MemoryDecisions({
    required this.available,
    required this.run,
    this.telemetry = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
  });

  /// Whether the chat has a stored thread to run the commands on.
  final bool Function() available;

  /// Runs a slash command on the chat's thread and returns Hermes' output.
  final Future<String> Function(String command) run;
  final ConnectionTelemetry telemetry;
  final Breadcrumbs breadcrumbs;

  final _states = <String, MemoryDecisionState>{};
  var _disposed = false;

  MemoryDecisionState stateOf(String id) =>
      _states[id] ?? MemoryDecisionState.idle;

  Future<void> decide(String id, {required bool approve}) async {
    if (!available() || !stateOf(id).canDecide) return;
    final choice = approve ? 'approve' : 'reject';
    breadcrumbs('memory.tool_card.decide', {'choice': choice});
    _set(id, const MemoryDecisionState(MemoryDecisionPhase.running));
    Span? span;
    try {
      span = telemetry.tracer?.startSpan(
        'memory.proposals.decide',
        attributes: {
          ...telemetry.serverAttributes,
          'choice': choice,
          'surface': 'tool_card',
        },
      );
    } on Object {
      // Telemetry never breaks the app.
    }
    var outcome = 'unreachable';
    MemoryDecisionState state;
    try {
      final output = await run('/memory $choice $id');
      state = parseMemoryDecisionAnswer(output, id: id, approve: approve);
      outcome = state.phase.name;
    } on Object {
      state = const MemoryDecisionState(
        MemoryDecisionPhase.failed,
        "Couldn't reach Hermes. Try again.",
      );
    }
    try {
      span?.setAttribute('outcome', outcome);
      telemetry.events('memory.proposal_decided', {
        'choice': choice,
        'outcome': outcome,
        'surface': 'tool_card',
      });
      span?.end();
    } on Object {
      // Telemetry never breaks the app.
    }
    _set(id, state);
  }

  void _set(String id, MemoryDecisionState state) {
    if (_disposed) return;
    _states[id] = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
