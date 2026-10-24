import 'package:flutter_otel/flutter_otel.dart';

import '../telemetry/telemetry.dart';
import 'memory_proposal_session.dart';
import 'memory_proposals.dart';

/// How reading one kind of proposals ended.
enum ProposalReadStatus {
  ok,

  /// Hermes answered in a way the app does not understand.
  unreadable,

  /// The server does not know the command.
  unsupported,

  /// The command did not run.
  failed,
}

/// What reading one kind of proposals gave.
class KindRead {
  const KindRead(this.status, [this.proposals = const [], this.raw = '']);

  final ProposalReadStatus status;
  final List<MemoryProposal> proposals;

  /// The answer as received, for an unreadable one.
  final String raw;
}

/// Both kinds of proposals of a profile, as last read.
class ProposalsSnapshot {
  const ProposalsSnapshot({required this.memory, required this.skills});

  final KindRead memory;
  final KindRead skills;

  List<MemoryProposal> get proposals => [
    ...memory.proposals,
    ...skills.proposals,
  ];

  int get count => memory.proposals.length + skills.proposals.length;
}

final _unknownCommand = RegExp(r'^Unknown command\b');
final _diffHeader = RegExp(r'^# Pending skill write [^\n]*\n\n?');

/// Reads and explains the staged memory and skill writes of a profile.
class MemoryProposalsRepository {
  MemoryProposalsRepository(
    this.session, {
    this.telemetry = const ConnectionTelemetry(),
  });

  final MemoryProposalSession session;
  final ConnectionTelemetry telemetry;

  Future<ProposalsSnapshot> load(String profile) async {
    final (memory, skills) = await (
      _read(profile, ProposalKind.memory, parseMemoryPending),
      _read(profile, ProposalKind.skill, parseSkillsPending),
    ).wait;
    return ProposalsSnapshot(memory: memory, skills: skills);
  }

  Future<KindRead> _read(
    String profile,
    ProposalKind kind,
    ParsedProposals Function(String) parse,
  ) async {
    final span = _start('memory.proposals.fetch', {'kind': kind.slug});
    KindRead read;
    try {
      final output = stripProgressLines(
        await session.run(profile, '/${kind.command} pending'),
      ).trim();
      if (_unknownCommand.hasMatch(output)) {
        read = const KindRead(ProposalReadStatus.unsupported);
      } else {
        final parsed = parse(output);
        if (parsed.unknownLines.isNotEmpty) {
          _quiet(
            () => telemetry.events('memory.proposals.parse_lenient', {
              'kind': kind.slug,
              'unknown_lines': parsed.unknownLines.length,
            }),
          );
        }
        read = parsed.unreadable
            ? KindRead(ProposalReadStatus.unreadable, const [], parsed.raw)
            : KindRead(ProposalReadStatus.ok, parsed.proposals);
      }
    } on Object {
      read = const KindRead(ProposalReadStatus.failed);
    }
    _quiet(() {
      if (read.status == ProposalReadStatus.ok) {
        span?.setAttribute('count', read.proposals.length);
      }
      span?.setAttribute('outcome', read.status.name);
      span?.end();
    });
    return read;
  }

  /// What `/skills diff` answers for the skill proposal [id], without the
  /// progress line and the title Hermes puts above it.
  Future<String> diff(String profile, String id) async {
    final span = _start('memory.proposals.diff', const {});
    var outcome = 'failed';
    try {
      final output = stripProgressLines(
        await session.run(profile, '/skills diff $id'),
      ).trim();
      outcome = 'ok';
      return output.replaceFirst(_diffHeader, '');
    } finally {
      _quiet(() {
        span?.setAttribute('outcome', outcome);
        span?.end();
      });
    }
  }

  Span? _start(String name, Map<String, Object> attributes) {
    try {
      return telemetry.tracer?.startSpan(
        name,
        attributes: {...telemetry.serverAttributes, ...attributes},
      );
    } on Object {
      return null;
    }
  }

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
