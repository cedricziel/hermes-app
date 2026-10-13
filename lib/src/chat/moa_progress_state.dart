enum MoaKind { reference, progress, phase, aggregating }

class MoaUpdate {
  const MoaUpdate(
    this.kind, {
    this.label,
    this.text,
    this.index,
    this.phase,
    this.aggregator,
    this.done,
    this.total,
  });
  final MoaKind kind;
  final String? label, text, phase, aggregator;
  final int? index, done, total;

  static MoaUpdate? decode(String type, Map<String, Object?> payload) {
    final label = payload['label'], text = payload['text'];
    final phase = payload['phase'], aggregator = payload['aggregator'];
    final rawDone = payload['refs_done'], rawTotal = payload['refs_total'];
    int? done, total;
    if (rawDone is int &&
        rawTotal is int &&
        rawDone >= 0 &&
        rawTotal >= 0 &&
        rawDone <= rawTotal) {
      done = rawDone;
      total = rawTotal;
    }
    switch (type) {
      case 'moa.reference':
        if (label is! String || text is! String) return null;
        final index = payload['index'];
        return MoaUpdate(
          MoaKind.reference,
          label: label,
          text: text,
          index: index is int && index >= 0 ? index : null,
        );
      case 'moa.progress':
        if (label is! String) return null;
        return MoaUpdate(
          MoaKind.progress,
          label: label,
          done: done,
          total: total,
        );
      case 'moa.phase':
        if (phase is! String) return null;
        return MoaUpdate(
          MoaKind.phase,
          phase: phase,
          aggregator: aggregator is String ? aggregator : null,
          done: done,
          total: total,
        );
      case 'moa.aggregating':
        if (aggregator is! String) return null;
        return MoaUpdate(MoaKind.aggregating, aggregator: aggregator);
      default:
        return null;
    }
  }
}

class MoaReference {
  const MoaReference({
    required this.eventIdentity,
    required this.label,
    required this.text,
    this.index,
  });
  final Object eventIdentity;
  final String label, text;
  final int? index;
}

class MoaProgress {
  const MoaProgress({
    required this.turn,
    this.phase = 'Advisors',
    this.aggregator,
    this.done,
    this.total,
    this.live = true,
    this.references = const [],
    this.referencesAvailable = true,
  });
  final Object turn;
  final String phase;
  final String? aggregator;
  final int? done, total;
  final bool live, referencesAvailable;
  final List<MoaReference> references;
}

enum MoaOutcome { applied, duplicate, stale }

class MoaProgressState {
  final _turns = <Object, MoaProgress>{};
  final _seen = <Object, Set<Object>>{};
  final _finished = <Object>{};
  Object? _attachment;
  bool _referencesAvailable = true;
  List<MoaProgress> get cards => List.unmodifiable(_turns.values);

  void adopt(Object attachment) {
    if (_attachment == attachment) return;
    clear();
    _attachment = attachment;
  }

  MoaOutcome apply(
    MoaUpdate update, {
    required Object attachment,
    required Object turn,
    required Object eventIdentity,
  }) {
    if (_attachment != attachment) return MoaOutcome.stale;
    if (!(_seen[turn] ??= {}).add(eventIdentity)) return MoaOutcome.duplicate;
    final old =
        _turns[turn] ??
        MoaProgress(
          turn: turn,
          live: !_finished.contains(turn),
          referencesAvailable: _referencesAvailable,
        );
    final references = [...old.references];
    if (update.kind == MoaKind.reference) {
      final reference = MoaReference(
        eventIdentity: eventIdentity,
        label: update.label!,
        text: update.text!,
        index: update.index,
      );
      final index = update.index == null
          ? -1
          : references.indexWhere((entry) => entry.index == update.index);
      if (index < 0) {
        references.add(reference);
      } else {
        references[index] = reference;
      }
    }
    final counts =
        update.kind == MoaKind.progress || update.kind == MoaKind.phase;
    _turns[turn] = MoaProgress(
      turn: turn,
      live: old.live,
      phase: switch (update.kind) {
        MoaKind.progress => 'Advisors',
        MoaKind.phase => update.phase!.isEmpty ? 'Advisors' : update.phase!,
        MoaKind.aggregating => 'Aggregating',
        MoaKind.reference => old.phase,
      },
      aggregator: update.aggregator ?? old.aggregator,
      done: counts ? update.done : old.done,
      total: counts ? update.total : old.total,
      references: List.unmodifiable(references),
      referencesAvailable: old.referencesAvailable,
    );
    return MoaOutcome.applied;
  }

  void finish(Object turn) {
    _finished.add(turn);
    final old = _turns[turn];
    if (old == null) return;
    _turns[turn] = MoaProgress(
      turn: turn,
      phase: old.phase,
      aggregator: old.aggregator,
      done: old.done,
      total: old.total,
      live: false,
      references: old.references,
      referencesAvailable: old.referencesAvailable,
    );
  }

  void beginTurn() => _referencesAvailable = true;

  void invalidateReferences() {
    _referencesAvailable = false;
    for (final old in _turns.values.toList()) {
      _turns[old.turn] = MoaProgress(
        turn: old.turn,
        phase: old.phase,
        aggregator: old.aggregator,
        done: old.done,
        total: old.total,
        live: old.live,
        referencesAvailable: false,
      );
    }
  }

  void clear() {
    _turns.clear();
    _seen.clear();
    _finished.clear();
    _attachment = null;
    _referencesAvailable = true;
  }
}
