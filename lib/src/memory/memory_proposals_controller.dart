import 'dart:async';

import 'package:flutter/foundation.dart';

import '../telemetry/breadcrumbs.dart';
import 'memory_decisions.dart';
import 'memory_proposals.dart';
import 'memory_proposals_repository.dart';

/// What the inbox says about the last decision, until the next one.
class MemoryProposalsNotice {
  const MemoryProposalsNotice(this.title, {this.detail, this.isError = false});

  final String title;
  final String? detail;
  final bool isError;
}

/// A skill proposal's changes, as asked for by "Show changes".
class ProposalDiff {
  const ProposalDiff({this.text, this.loading = false, this.failed = false});

  final String? text;
  final bool loading;
  final bool failed;
}

/// The Waiting for you inbox of one profile: the proposals Hermes holds, the
/// decision on each and the last thing said about one. Everything is dropped
/// when the repository or profile changes, and a late answer of an earlier
/// scope is ignored.
class MemoryProposalsController extends ChangeNotifier {
  MemoryProposalsController({this.breadcrumbs = Breadcrumbs.none});

  final Breadcrumbs breadcrumbs;

  MemoryProposalsRepository? _repository;
  String? _profile;
  int _generation = 0;
  int _reads = 0;
  bool _disposed = false;
  final _running = <Future<void>>{};
  final _diffs = <String, ProposalDiff>{};
  String? _selectedId;

  /// The proposals as last read; null before the first read ends.
  ProposalsSnapshot? snapshot;
  bool loading = false;

  /// A decision for all of them is running.
  bool deciding = false;
  MemoryProposalsNotice? notice;

  /// Decides the proposals of the bound profile; null while unbound.
  MemoryDecisions? decisions;

  String? get profile => _profile;

  /// How many changes wait, or null when neither kind could be read.
  int? get waiting => snapshot?.waiting;

  /// The proposal whose detail is shown: the one picked, else the first.
  MemoryProposal? get selected {
    final all = snapshot?.proposals ?? const <MemoryProposal>[];
    return all.where((p) => p.id == _selectedId).firstOrNull ?? all.firstOrNull;
  }

  ProposalDiff? diffOf(String id) => _diffs[id];

  /// Completes when every read and decision started so far has ended.
  Future<void> get whenIdle async {
    while (_running.isNotEmpty) {
      await Future.wait(_running.toList());
    }
  }

  void select(String id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void bind(MemoryProposalsRepository? repository, String? profile) {
    if (identical(_repository, repository) && _profile == profile) return;
    final generation = ++_generation;
    decisions?.dispose();
    _repository = repository;
    _profile = profile;
    snapshot = null;
    notice = null;
    deciding = false;
    loading = false;
    _selectedId = null;
    _diffs.clear();
    decisions = repository == null || profile == null
        ? null
        : MemoryDecisions(
            available: () => !_disposed && generation == _generation,
            run: (command) => repository.session.run(profile, command),
            surface: 'inbox',
            telemetry: repository.telemetry,
            breadcrumbs: breadcrumbs,
          );
    notifyListeners();
    if (repository != null && profile != null) unawaited(_track(load()));
  }

  Future<void> _track(Future<void> work) {
    _running.add(work);
    unawaited(work.whenComplete(() => _running.remove(work)));
    return work;
  }

  Future<void> load() async {
    final repository = _repository, profile = _profile;
    if (repository == null || profile == null) return;
    final generation = _generation, read = ++_reads;
    bool stale() => _disposed || generation != _generation || read != _reads;
    loading = true;
    notifyListeners();
    final result = await repository.load(profile);
    if (stale()) return;
    snapshot = result;
    loading = false;
    notifyListeners();
  }

  Future<void> decide(MemoryProposal proposal, {required bool approve}) async {
    final decisions = this.decisions;
    if (decisions == null) return;
    final generation = _generation;
    await _track(
      decisions.decide(proposal.id, approve: approve, kind: proposal.kind),
    );
    if (_disposed || generation != _generation) return;
    final state = decisions.stateOf(proposal.id);
    notice = switch (state.phase) {
      MemoryDecisionPhase.saved => _saved(proposal),
      MemoryDecisionPhase.rejected => const MemoryProposalsNotice('Rejected'),
      MemoryDecisionPhase.failed => MemoryProposalsNotice(
        state.text,
        isError: true,
      ),
      _ => null,
    };
    notifyListeners();
    await _track(load());
  }

  /// Decides each listed proposal in turn, with the list as it was read.
  Future<void> decideAll({required bool approve}) async {
    final decisions = this.decisions;
    final listed = snapshot?.proposals;
    if (decisions == null || listed == null || listed.isEmpty || deciding) {
      return;
    }
    final generation = _generation;
    deciding = true;
    notifyListeners();
    await _track(decisions.decideAll(listed, approve: approve));
    if (_disposed || generation != _generation) return;
    deciding = false;
    final failed = [
      for (final proposal in listed)
        if (decisions.stateOf(proposal.id).phase == MemoryDecisionPhase.failed)
          decisions.stateOf(proposal.id).text,
    ];
    notice = failed.isNotEmpty
        ? MemoryProposalsNotice(failed.first, isError: true)
        : approve
        ? MemoryProposalsNotice(
            listed.length == 1 ? 'Saved' : 'Saved ${listed.length} changes',
            detail: 'Hermes uses it from the next chat.',
          )
        : MemoryProposalsNotice(
            listed.length == 1
                ? 'Rejected'
                : 'Rejected ${listed.length} changes',
          );
    notifyListeners();
    await _track(load());
  }

  /// Reads what a skill proposal would change; a diff already read stays.
  Future<void> showChanges(MemoryProposal proposal) async {
    final repository = _repository, profile = _profile;
    if (repository == null || profile == null) return;
    final id = proposal.id;
    final shown = _diffs[id];
    if (shown?.loading == true || shown?.text != null) return;
    final generation = _generation;
    _diffs[id] = const ProposalDiff(loading: true);
    notifyListeners();
    ProposalDiff result;
    try {
      result = ProposalDiff(text: await repository.diff(profile, id));
    } on Object {
      result = const ProposalDiff(failed: true);
    }
    if (_disposed || generation != _generation) return;
    _diffs[id] = result;
    notifyListeners();
  }

  MemoryProposalsNotice _saved(MemoryProposal proposal) =>
      proposal.kind == ProposalKind.skill
      ? const MemoryProposalsNotice(
          'Skill saved',
          detail: 'Hermes uses it from the next chat.',
        )
      : MemoryProposalsNotice(
          proposal.target == null
              ? 'Saved'
              : 'Saved to ${proposal.targetLabel}',
          detail: 'Hermes uses it from the next chat.',
        );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    decisions?.dispose();
    super.dispose();
  }
}
