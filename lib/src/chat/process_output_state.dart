import 'dart:convert';

import 'subagents/process_models.dart';

class ProcessOutputUpdate {
  const ProcessOutputUpdate(this.processId, {this.chunk, this.closed = false});
  final String processId;
  final String? chunk;
  final bool closed;

  static ProcessOutputUpdate? decode(
    String type,
    Map<String, Object?> payload,
  ) {
    final id = payload['process_id'];
    if (id is! String || id.isEmpty) return null;
    if (type == 'terminal.close') return ProcessOutputUpdate(id, closed: true);
    final chunk = payload['chunk'];
    if (type != 'agent.terminal.output' || chunk is! String) return null;
    return ProcessOutputUpdate(id, chunk: chunk);
  }

  @override
  String toString() => 'ProcessOutputUpdate(closed: $closed)';
}

/// One program card: the output frames delivered and, once `process.list`
/// named the program, its command and state.
class ProcessOutput {
  const ProcessOutput({
    required this.processId,
    this.text = '',
    this.closed = false,
    this.omitted = false,
    this.status,
    this.command,
    this.exitCode,
    this.completionReason,
    this.uptime,
    this.seeded = false,
  });
  final String processId, text;
  final bool closed, omitted;

  /// Null until the list names the program: the card then keeps the wording
  /// it had before the list existed and never claims a result.
  final ProgramStatus? status;
  final String? command;
  final int? exitCode;
  final String? completionReason;
  final Duration? uptime;

  /// The text came from the list's `output_tail` or a kill answer that
  /// Hermes had cut, so only the end of the output is held.
  final bool seeded;

  bool get listed => status != null;
  bool get running => status == ProgramStatus.running;

  ProcessOutput _with({
    String? text,
    bool? closed,
    bool? omitted,
    ProgramStatus? status,
    String? command,
    int? exitCode,
    String? completionReason,
    Duration? uptime,
    bool? seeded,
  }) => ProcessOutput(
    processId: processId,
    text: text ?? this.text,
    closed: closed ?? this.closed,
    omitted: omitted ?? this.omitted,
    status: status ?? this.status,
    command: command ?? this.command,
    exitCode: exitCode ?? this.exitCode,
    completionReason: completionReason ?? this.completionReason,
    uptime: uptime ?? this.uptime,
    seeded: seeded ?? this.seeded,
  );

  @override
  String toString() =>
      'ProcessOutput(${text.length} chars, closed: $closed, status: $status)';
}

enum ProcessOutputOutcome { applied, truncated, evicted, stale, ignored }

/// The program cards of one chat's session, held in memory and scoped to
/// the attachment that delivered them: frames, `process.list` and
/// `process.kill` answers for another attachment change nothing.
class ProcessOutputState {
  static const maxBytes = 64 * 1024;
  static const maxCards = 16;
  final _cards = <String, ProcessOutput>{};
  Object? _attachment;
  bool omittedCards = false;
  List<ProcessOutput> get cards => List.unmodifiable(_cards.values);
  bool hasScope(Object attachment) => _attachment == attachment;

  ProcessOutput? card(String processId) => _cards[processId];

  void adopt(Object attachment) {
    if (_attachment == attachment) return;
    clear();
    _attachment = attachment;
  }

  ProcessOutputOutcome apply(
    ProcessOutputUpdate update, {
    required Object attachment,
  }) {
    if (_attachment != attachment) return ProcessOutputOutcome.stale;
    if (update.processId.isEmpty || (!update.closed && update.chunk == null)) {
      return ProcessOutputOutcome.ignored;
    }
    final evicted = !_cards.containsKey(update.processId) && _makeRoom();
    final old = _cards[update.processId];
    final (text, truncated) = _bounded(
      '${old?.text ?? ''}${update.chunk ?? ''}',
    );
    _cards[update.processId] =
        (old ?? ProcessOutput(processId: update.processId))._with(
          text: text,
          closed: update.closed || (old?.closed ?? false),
          omitted: truncated || (old?.omitted ?? false),
        );
    return evicted
        ? ProcessOutputOutcome.evicted
        : truncated
        ? ProcessOutputOutcome.truncated
        : ProcessOutputOutcome.applied;
  }

  /// Counts confirmed kill answers. A list read captures it when it is sent
  /// and passes it to [applyList] as `since`.
  int get generation => _generation;
  var _generation = 0;

  /// The [generation] at which each program's kill answer was applied. Kept
  /// when a card is evicted, so an older list cannot bring it back running.
  final _settledAt = <String, int>{};

  /// Merges a `process.list` answer by id. A listed program's card gets its
  /// command and state; `output_tail` only seeds a card with no text. Cards
  /// already held are merged first, then only running programs without a
  /// card get one, so finished programs never take a card's slot and a row
  /// that ends a card frees its slot for a later one. A running card the
  /// list no longer has reads as ended. With [since], the [generation] the
  /// read was sent at, a row for a program whose kill was answered after
  /// that is older than the card and is skipped.
  ProcessOutputOutcome applyList(
    ProcessList list, {
    required Object attachment,
    int? since,
  }) {
    if (_attachment != attachment) return ProcessOutputOutcome.stale;
    bool outdated(String id) => since != null && (_settledAt[id] ?? -1) > since;
    final listed = {for (final process in list.processes) process.id};
    final added = <ListedProcess>[];
    for (final process in list.processes) {
      final card = _cards[process.id];
      if (card == null) {
        if (process.running) added.add(process);
        continue;
      }
      if (outdated(process.id)) continue;
      _cards[process.id] = _merge(card, process);
    }
    for (final MapEntry(:key, :value) in _cards.entries.toList()) {
      if (value.running && !listed.contains(key)) {
        _cards[key] = value._with(status: ProgramStatus.ended);
      }
    }
    var evicted = false;
    for (final process in added) {
      // A program the frames never named takes a free slot or a finished
      // card's, never a running card's: that would drop frame output and
      // churn on the next read.
      if (outdated(process.id) ||
          _cards.containsKey(process.id) ||
          (_cards.length >= maxCards && !_cards.values.any(_finished))) {
        continue;
      }
      evicted = _makeRoom() || evicted;
      _cards[process.id] = _merge(
        ProcessOutput(processId: process.id),
        process,
      );
    }
    return evicted
        ? ProcessOutputOutcome.evicted
        : ProcessOutputOutcome.applied;
  }

  ProcessOutput _merge(ProcessOutput card, ListedProcess process) {
    final tail = process.outputTail;
    return _seed(
      card._with(
        status: process.status,
        command: process.command,
        exitCode: process.exitCode,
        completionReason: process.completionReason,
        uptime: process.uptime,
      ),
      tail,
      // Hermes keeps the last 4,000 characters: a tail that long was cut.
      cut: tail != null && tail.runes.length >= kProcessTailChars,
    );
  }

  /// Merges a `process.kill` answer into its card; never adds one. Its
  /// `output` overlaps what frames delivered, so it only seeds a card with no
  /// text. An `error` answer leaves the card as it was.
  ProcessOutputOutcome applyKill(
    String processId,
    ProcessKill answer, {
    required Object attachment,
  }) {
    if (_attachment != attachment) return ProcessOutputOutcome.stale;
    final card = _cards[processId];
    if (card == null) return ProcessOutputOutcome.ignored;
    if (answer.outcome == KillOutcome.error) {
      return ProcessOutputOutcome.ignored;
    }
    _settledAt[processId] = ++_generation;
    switch (answer.outcome) {
      case KillOutcome.error:
        break;
      case KillOutcome.notFound:
        if (card.running) {
          _cards[processId] = card._with(status: ProgramStatus.ended);
        }
      case KillOutcome.killed:
        _cards[processId] = _seed(
          card._with(
            status: ProgramStatus.stopped,
            exitCode: answer.exitCode,
            completionReason: 'killed',
          ),
          answer.output,
          cut: answer.outputCut,
        );
      case KillOutcome.alreadyExited:
        final reason = answer.completionReason ?? card.completionReason;
        final code = answer.exitCode ?? card.exitCode;
        _cards[processId] = _seed(
          card._with(
            status: programStatusOf(
              running: false,
              completionReason: reason,
              exitCode: code,
            ),
            exitCode: code,
            completionReason: reason,
          ),
          answer.output,
          cut: answer.outputCut,
        );
    }
    return ProcessOutputOutcome.applied;
  }

  /// [text] becomes the card's output when it has none yet.
  ProcessOutput _seed(ProcessOutput card, String? text, {required bool cut}) {
    if (card.text.isNotEmpty || text == null || text.isEmpty) return card;
    final (bounded, truncated) = _bounded(text);
    return card._with(text: bounded, seeded: cut || truncated);
  }

  /// Frees one slot when all are taken: a closed or finished card first,
  /// otherwise the oldest. Answers whether a card went.
  bool _makeRoom() {
    if (_cards.length < maxCards) return false;
    final done = _cards.values.where(_finished);
    _cards.remove(done.isEmpty ? _cards.keys.first : done.first.processId);
    omittedCards = true;
    return true;
  }

  static bool _finished(ProcessOutput card) =>
      card.closed || (card.listed && !card.running);

  static (String, bool) _bounded(String text) {
    final bytes = utf8.encode(text);
    if (bytes.length <= maxBytes) return (text, false);
    var start = bytes.length - maxBytes;
    while (start < bytes.length && (bytes[start] & 0xc0) == 0x80) {
      start++;
    }
    return (utf8.decode(bytes.sublist(start)), true);
  }

  void clear() {
    _cards.clear();
    _settledAt.clear();
    omittedCards = false;
    _attachment = null;
  }

  @override
  String toString() =>
      'ProcessOutputState(cards: ${_cards.length}, '
      'listed: ${_cards.values.where((card) => card.listed).length})';
}
