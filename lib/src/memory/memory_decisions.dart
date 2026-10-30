import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart';

import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import 'memory_proposals.dart';

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

/// Reads what `/memory approve` or `/memory reject` (`/skills …` for a
/// skill) answered for [id].
///
/// An approval is saved when Hermes approved at least one write and names no
/// failure for [id]: its "Failed:" section lists "id: reason" lines, while the
/// lines after an approved replace, patch or remove also read "id: entry" and
/// are not failures. Any other answer is a failure, shown as Hermes wrote it.
MemoryDecisionState parseMemoryDecisionAnswer(
  String output, {
  required String id,
  required bool approve,
  ProposalKind kind = ProposalKind.memory,
}) {
  final answer = stripProgressLines(output).trim();
  if (!approve) {
    return answer.startsWith('Rejected pending ${kind.command} write')
        ? const MemoryDecisionState(MemoryDecisionPhase.rejected)
        : MemoryDecisionState(MemoryDecisionPhase.failed, answer);
  }
  final lines = answer.split('\n');
  final failures = lines.indexOf('Failed:');
  final prefix = '$id:';
  final reason = failures < 0
      ? null
      : lines
            .skip(failures + 1)
            .map((line) => line.trimLeft())
            .where((line) => line.startsWith(prefix))
            .map((line) => line.substring(prefix.length).trim())
            .where((reason) => reason.isNotEmpty)
            .firstOrNull;
  if (reason != null) {
    return MemoryDecisionState(MemoryDecisionPhase.failed, reason);
  }
  final count = int.tryParse(_approved.firstMatch(answer)?.group(1) ?? '');
  return count != null && count > 0
      ? const MemoryDecisionState(MemoryDecisionPhase.saved)
      : MemoryDecisionState(MemoryDecisionPhase.failed, answer);
}

/// Approves and rejects staged memory and skill writes through a gateway
/// session, and holds each one's state for as long as its owner lives: a chat
/// for the tool card, the profile's inbox for the Waiting for you screen.
class MemoryDecisions extends ChangeNotifier {
  MemoryDecisions({
    required this.available,
    required this.run,
    this.telemetry = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
    this.surface = 'tool_card',
  });

  /// Whether there is a session to run the commands in.
  final bool Function() available;

  /// Runs a slash command and returns Hermes' output.
  final Future<String> Function(String command) run;
  final ConnectionTelemetry telemetry;
  final Breadcrumbs breadcrumbs;

  /// Where the decision is made, a fixed name for telemetry: `tool_card` or
  /// `inbox`.
  final String surface;

  final _states = <String, MemoryDecisionState>{};
  var _disposed = false;

  MemoryDecisionState stateOf(String id) =>
      _states[id] ?? MemoryDecisionState.idle;

  Future<void> decide(
    String id, {
    required bool approve,
    ProposalKind kind = ProposalKind.memory,
  }) async {
    if (!available() || !stateOf(id).canDecide) return;
    final choice = approve ? 'approve' : 'reject';
    final span = _begin(choice, kind.slug);
    final (_, outcome) = await _decide(id, approve, kind);
    _end(span, choice, kind.slug, outcome);
  }

  /// Decides each of [proposals] in turn with its own command, never with
  /// `all`, so a proposal staged after the list was read is not decided
  /// unseen. A refusal by Hermes leaves that one failed and goes on; a lost
  /// connection ends the run.
  Future<void> decideAll(
    Iterable<MemoryProposal> proposals, {
    required bool approve,
  }) async {
    final todo = [
      for (final proposal in proposals)
        if (stateOf(proposal.id).canDecide) proposal,
    ];
    if (!available() || todo.isEmpty) return;
    final choice = approve ? 'approve_all' : 'reject_all';
    final kinds = {for (final proposal in todo) proposal.kind.slug};
    final kind = kinds.length == 1 ? kinds.single : 'mixed';
    final span = _begin(choice, kind);
    var outcome = approve ? 'saved' : 'rejected';
    for (final proposal in todo) {
      final (state, result) = await _decide(
        proposal.id,
        approve,
        proposal.kind,
      );
      if (result == 'unreachable') {
        outcome = result;
        break;
      }
      if (state.phase == MemoryDecisionPhase.failed) outcome = 'failed';
    }
    _end(span, choice, kind, outcome);
  }

  Future<(MemoryDecisionState, String)> _decide(
    String id,
    bool approve,
    ProposalKind kind,
  ) async {
    _set(id, const MemoryDecisionState(MemoryDecisionPhase.running));
    MemoryDecisionState state;
    String outcome;
    try {
      final output = await run(
        '/${kind.command} ${approve ? 'approve' : 'reject'} $id',
      );
      state = parseMemoryDecisionAnswer(
        output,
        id: id,
        approve: approve,
        kind: kind,
      );
      outcome = state.phase.name;
    } on Object {
      outcome = 'unreachable';
      state = const MemoryDecisionState(
        MemoryDecisionPhase.failed,
        "Couldn't reach Hermes. Try again.",
      );
    }
    _set(id, state);
    return (state, outcome);
  }

  Span? _begin(String choice, String kind) {
    breadcrumbs('memory.$surface.decide', {'choice': choice});
    try {
      return telemetry.tracer?.startSpan(
        'memory.proposals.decide',
        attributes: {
          ...telemetry.serverAttributes,
          'choice': choice,
          'kind': kind,
          'surface': surface,
        },
      );
    } on Object {
      return null;
    }
  }

  void _end(Span? span, String choice, String kind, String outcome) {
    try {
      span?.setAttribute('outcome', outcome);
      telemetry.events('memory.proposal_decided', {
        'choice': choice,
        'kind': kind,
        'outcome': outcome,
        'surface': surface,
      });
      span?.end();
    } on Object {
      // Telemetry never breaks the app.
    }
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
