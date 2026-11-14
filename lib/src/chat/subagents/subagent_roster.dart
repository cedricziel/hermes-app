import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../network/poll_backoff.dart';
import '../chat_models.dart';
import '../process_output_state.dart';
import 'agent_detail_host.dart';
import 'agent_models.dart';
import 'roster_row.dart';
import 'agent_work_result.dart';
import 'process_models.dart';
import 'process_stop_controller.dart';
import 'subagent_repository.dart';

/// What the roster needs to know about the app around it.
abstract interface class RosterEnvironment {
  /// Fires when the connection, foreground or lock state changed.
  Listenable get changes;

  /// The token of the current gateway connection; null when there is none.
  Object? get connection;
  bool get foreground;

  /// Whether App Lock is off.
  bool get unlocked;
}

/// The chat's program cards, which the roster fills from `process.list`.
/// They belong to the chat's session as it is attached now; an answer for an
/// attachment that is gone changes nothing.
abstract interface class ProgramCards {
  /// Fires when a card changed outside the roster: a frame, a new
  /// attachment.
  Listenable get cardChanges;

  /// The attachment [threadId]'s session holds on the current connection,
  /// or null when it holds none.
  Object? attachmentOf(String threadId);

  /// The cards of [threadId] under [attachment], created with [create] when
  /// there are none yet; null when [attachment] is not the session's now.
  ProcessOutputState? cardsFor(
    String threadId,
    Object attachment, {
    bool create = false,
  });

  /// Says the roster changed a card.
  void cardsChanged();
}

/// How often the list is read while an agent runs and the roster is shown.
const kRosterEvery = Duration(seconds: 5);

/// How many ended agents This session keeps.
const kEndedKept = 20;

/// The most levels an agent is drawn under its parent.
const kMaxNesting = 3;

/// One handle on the roster being shown; closing it is how a panel or a
/// detail says it went away.
final class RosterWatch {
  RosterWatch._(this._close);
  final void Function() _close;
  var _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    _close();
  }
}

/// The agents of one chat, merged from its `subagent.*` frames and the list.
/// One roster serves one chat, profile and account; its owner creates it
/// with the chat's activity and [dispose]s it when the chat retires, the
/// profile changes or the user signs out.
///
/// The list is read only while something watches the roster, the app is in
/// front and unlocked, and the chat's session is attached: once on demand and
/// then every [kRosterEvery] while an agent runs, backing off after failures.
/// It never resumes a session to read. Goals, summaries and ids live only
/// here, in memory; `toString` prints counts.
class SubagentRoster extends ChangeNotifier {
  SubagentRoster({
    required this.threadId,
    required this.profile,
    required this._repository,
    required this._env,
    this.programs,
    this.events = noopAppEventLogger,
  }) {
    _env.changes.addListener(_onEnvironment);
    _seenConnection = _env.connection;
  }

  /// The stored id the list is read under. A new chat gets its id with its
  /// first reply, so it can change once; see [retarget].
  String threadId;
  final String? profile;
  final AppEventLogger events;
  final SubagentRepository _repository;

  /// The chat's program cards; without them `process.list` is never read.
  final ProgramCards? programs;

  /// The calls on this chat's agents, for a detail's own controller.
  SubagentRepository get repository => _repository;

  /// The token of the connection the roster reads on now, or null offline.
  Object? get connection => _env.connection;
  final RosterEnvironment _env;

  final _rows = <String, RosterRow>{};
  final _delegations = <String, RosterRow>{};
  var _order = 0;
  var _frameSeq = 0;
  var _demand = 0;
  var _disposed = false;
  Timer? _timer;
  final _backoff = PollBackoff();
  Object? _seenConnection;
  var _generation = 0;
  Future<AgentWorkResult<AgentList>>? _inFlight;

  /// Connections whose server answered method-not-found, and those whose
  /// session was not theirs to read (4001).
  Object? _unsupportedOn, _blockedOn;
  var _loggedUnsupported = false;

  /// The same, for `process.list`, which the server may lack while it has
  /// `subagent.list`.
  Object? _programsUnsupportedOn, _programsBlockedOn;
  var _loggedProgramsUnsupported = false;
  var _programsListed = false;
  Future<AgentWorkResult<ProcessList>>? _programsInFlight;

  /// Both lists share one backoff. Each read belongs to the round that
  /// started it, and a round counts its failures once, also when another
  /// round starts while its reads are out.
  var _rounds = 0;
  int? _failedRound;

  /// Cards the list has been read for once without naming them (a child
  /// agent's program may live under another session): not read for again.
  final _programsLookedFor = <String>{};

  /// Whether the last list answer was malformed or failed (for tests and the
  /// panel's quiet state).
  var _listed = false;
  var _lastReadFailed = false;
  bool get lastReadFailed => _lastReadFailed;

  // ---- frames ---------------------------------------------------------

  /// Takes one `subagent.*` frame of any reply of this chat.
  void applyFrame(Subagent frame) {
    if (_disposed) return;
    final row = _rows.putIfAbsent(
      frame.id,
      () => RosterRow(id: frame.id, order: _order++),
    );
    row.frameSeq = ++_frameSeq;
    if (frame.goal.isNotEmpty) row.goal = frame.goal;
    row.parentId = frame.parentId ?? row.parentId;
    row.taskIndex = frame.index;
    row.startedAt ??= frame.startedAt;
    row.toolCount = frame.toolCount ?? row.toolCount;
    row.lastTool = frame.lastTool ?? row.lastTool;
    row.lastToolPreview = frame.lastToolPreview ?? row.lastToolPreview;
    row.duration = frame.duration ?? row.duration;
    final next = stateOfFrame(frame.status);
    // An ended state never goes back to running.
    if (row.active || !next.active) {
      if (!next.active) {
        row.completedByFrame = true;
        final summary = frame.summary;
        if (summary != null && summary.isNotEmpty) row.summary = summary;
      }
      row.state = next;
    }
    _changed();
  }

  // ---- reads ----------------------------------------------------------

  /// Says the roster is on screen. Reads start with the first watch and stop
  /// with the last.
  RosterWatch watch() {
    if (_disposed) return RosterWatch._(() {});
    if (_demand++ == 0) {
      _backoff.reset();
      _timer = Timer.periodic(kRosterEvery, (_) => _tick());
      scheduleMicrotask(() {
        if (_demand > 0) _round(agents: true, programs: true);
      });
    }
    return RosterWatch._(() {
      if (_disposed || --_demand > 0) return;
      _timer?.cancel();
      _timer = null;
    });
  }

  bool get _shownAndAllowed =>
      !_disposed &&
      _demand > 0 &&
      _env.foreground &&
      _env.unlocked &&
      _env.connection != null;

  bool get _gatesOpen =>
      _shownAndAllowed &&
      !identical(_unsupportedOn, _env.connection) &&
      !identical(_blockedOn, _env.connection);

  bool get _programGatesOpen =>
      programs != null &&
      _shownAndAllowed &&
      !identical(_programsUnsupportedOn, _env.connection) &&
      !identical(_programsBlockedOn, _env.connection);

  bool get _anyActive => _rows.values.any((row) => row.active);

  bool get _anyProgramRunning =>
      _programCards?.cards.any((card) => card.running) ?? false;

  /// A card frames opened that no list read has looked for yet: a program
  /// that started after the last read.
  bool get _anyProgramUnlooked =>
      _programCards?.cards.any(
        (card) =>
            !card.listed &&
            !card.closed &&
            !_programsLookedFor.contains(card.processId),
      ) ??
      false;

  /// Failures counted by the backoff in a row (for tests).
  @visibleForTesting
  int get backoffFailures => _backoff.failures;

  ProcessOutputState? get _programCards {
    final cards = programs;
    final attachment = cards?.attachmentOf(threadId);
    return attachment == null ? null : cards!.cardsFor(threadId, attachment);
  }

  void _tick() {
    // Until one read has answered, a chat with no frame rows still needs
    // reading: its agents may have started from another client.
    final agents = _gatesOpen && (_anyActive || !_listed);
    final programs =
        _programGatesOpen &&
        (_anyProgramRunning || !_programsListed || _anyProgramUnlooked);
    if (!(agents || programs) || !_backoff.tick()) return;
    _round(agents: agents, programs: programs);
  }

  /// One round of reads on the shared timer and backoff.
  void _round({required bool agents, required bool programs}) {
    final round = ++_rounds;
    if (agents && _gatesOpen) unawaited(_read(round: round));
    if (programs && _programGatesOpen) {
      unawaited(_readPrograms(round: round));
    }
  }

  void _readFailed(int round) {
    if (_failedRound == round) return;
    _failedRound = round;
    _backoff.failed();
  }

  void _readSucceeded(int round) {
    if (_failedRound != round) _backoff.succeeded();
  }

  /// The chat's stored id changed (a new chat got its first one). Rows from
  /// frames stay; answers still in flight are dropped.
  void retarget(String threadId) {
    if (_disposed || this.threadId == threadId) return;
    this.threadId = threadId;
    _generation++;
    _inFlight = _programsInFlight = null;
    _listed = _programsListed = false;
    _blockedOn = _programsBlockedOn = null;
    _programsLookedFor.clear();
  }

  /// The session now holds the connection (an action attached it), so list
  /// reads may start again after a 4001.
  void markAttached() {
    final agents = _blockedOn != null, programs = _programsBlockedOn != null;
    _blockedOn = _programsBlockedOn = null;
    if (agents || programs) _round(agents: agents, programs: programs);
  }

  /// Reads the list now, after any read already in flight, and answers what
  /// the read came to. Used for the re-read after a stop.
  Future<AgentWorkResult<AgentList>> readNow() async {
    final pending = _inFlight;
    if (pending != null) await pending;
    if (_disposed) return const WorkLost();
    return _read(force: true, round: ++_rounds);
  }

  Future<AgentWorkResult<AgentList>> _read({
    bool force = false,
    required int round,
  }) {
    final running = _inFlight;
    if (!force && running != null) return running;
    late final Future<AgentWorkResult<AgentList>> read;
    read = _readOnce(force: force, round: round).whenComplete(() {
      if (identical(_inFlight, read)) _inFlight = null;
    });
    return _inFlight = read;
  }

  Future<AgentWorkResult<AgentList>> _readOnce({
    required bool force,
    required int round,
  }) async {
    final connection = _env.connection;
    // A forced read (the re-read after a stop) skips the demand and the
    // backoff, not the rules about the background, App Lock, a missing
    // connection or a method the server does not have.
    if (_disposed ||
        connection == null ||
        !_env.foreground ||
        !_env.unlocked ||
        identical(_unsupportedOn, connection) ||
        (!force && identical(_blockedOn, connection))) {
      return const WorkLost();
    }
    final generation = _generation, startSeq = _frameSeq;
    final result = await _repository.list(threadId, profile: profile);
    // An answer after the chat, profile, connection or account changed is not
    // about the state the user is looking at.
    if (_disposed ||
        generation != _generation ||
        !identical(connection, _env.connection)) {
      return const WorkLost();
    }
    switch (result) {
      case WorkOk(:final value):
        _apply(value, startSeq);
        _listed = true;
        _blockedOn = null;
        _lastReadFailed = false;
        _readSucceeded(round);
        _changed();
        return WorkOk(value);
      case WorkNotAttached():
        // Nothing was sent; frames carry the state until it attaches.
        return const WorkNotAttached();
      case WorkUnsupported():
        _unsupportedOn = connection;
        if (!_loggedUnsupported) {
          _loggedUnsupported = true;
          _log('subagent.unsupported', {'method': 'list'});
        }
        return const WorkUnsupported();
      case WorkFailed(kind: WorkFailureKind.notOwned):
        // This connection does not hold the session: rows stay as frames
        // left them, and no read follows until it does.
        _blockedOn = connection;
        _lastReadFailed = true;
        return const WorkFailed(WorkFailureKind.notOwned);
      case WorkFailed(:final kind):
        _lastReadFailed = true;
        _readFailed(round);
        return WorkFailed(kind);
      case WorkLost():
        _lastReadFailed = true;
        _readFailed(round);
        return const WorkLost();
    }
  }

  // ---- programs -------------------------------------------------------

  /// Reads `process.list` now, after any read already in flight, and
  /// answers what it came to. Used for the re-read after a lost kill.
  Future<AgentWorkResult<ProcessList>> readProgramsNow() async {
    final pending = _programsInFlight;
    if (pending != null) await pending;
    if (_disposed) return const WorkLost();
    return _readPrograms(force: true, round: ++_rounds);
  }

  Future<AgentWorkResult<ProcessList>> _readPrograms({
    bool force = false,
    required int round,
  }) {
    final running = _programsInFlight;
    if (!force && running != null) return running;
    late final Future<AgentWorkResult<ProcessList>> read;
    read = _readProgramsOnce(force: force, round: round).whenComplete(() {
      if (identical(_programsInFlight, read)) _programsInFlight = null;
    });
    return _programsInFlight = read;
  }

  Future<AgentWorkResult<ProcessList>> _readProgramsOnce({
    required bool force,
    required int round,
  }) async {
    final cards = programs, connection = _env.connection;
    if (cards == null ||
        _disposed ||
        connection == null ||
        !_env.foreground ||
        !_env.unlocked ||
        identical(_programsUnsupportedOn, connection) ||
        (!force && identical(_programsBlockedOn, connection))) {
      return const WorkLost();
    }
    // Reads stay attached-only: resuming to list would start an agent build.
    final attachment = cards.attachmentOf(threadId);
    if (attachment == null) return const WorkNotAttached();
    final generation = _generation;
    // The cards this read looks for; a later card is looked for by a later
    // read.
    final lookedFor = [
      for (final card
          in cards.cardsFor(threadId, attachment)?.cards ??
              const <ProcessOutput>[])
        card.processId,
    ];
    final result = await _repository.processList(threadId, profile: profile);
    if (_disposed ||
        generation != _generation ||
        !identical(connection, _env.connection)) {
      return const WorkLost();
    }
    switch (result) {
      case WorkOk(:final value):
        // The session may have been attached anew while the read ran: the
        // answer was about the attachment it started on.
        final state = cards.cardsFor(threadId, attachment, create: true);
        if (state == null) return const WorkLost();
        state.applyList(value, attachment: attachment);
        _programsListed = true;
        _programsLookedFor.addAll(lookedFor);
        _programsBlockedOn = null;
        _readSucceeded(round);
        cards.cardsChanged();
        _changed();
        return WorkOk(value);
      case WorkNotAttached():
        return const WorkNotAttached();
      case WorkUnsupported():
        // No list means no way to know a program still runs: cards stay as
        // the frames left them, without Stop.
        _programsUnsupportedOn = connection;
        if (!_loggedProgramsUnsupported) {
          _loggedProgramsUnsupported = true;
          _log('subagent.unsupported', {'method': 'process_list'});
        }
        return const WorkUnsupported();
      case WorkFailed(kind: WorkFailureKind.notOwned):
        _programsBlockedOn = connection;
        return const WorkFailed(WorkFailureKind.notOwned);
      case WorkFailed(:final kind):
        // 5032 (the agent is still starting) and 5010 land here: quiet, on
        // the backoff.
        _readFailed(round);
        return WorkFailed(kind);
      case WorkLost():
        _readFailed(round);
        return const WorkLost();
    }
  }

  /// A host for the stop of program [processId], for
  /// `ProcessStopController`; null without program cards.
  ProcessStopHost? programHostFor(String processId) =>
      programs == null ? null : _ProgramHost(this, processId);

  void _apply(AgentList list, int startSeq) {
    final listedIds = <String>{};
    for (final agent in list.agents) {
      listedIds.add(agent.id);
      final row = _rows.putIfAbsent(
        agent.id,
        () => RosterRow(id: agent.id, order: _order++),
      );
      final newerFrame = row.frameSeq > startSeq;
      if (row.goal.isEmpty) row.goal = agent.goal ?? '';
      row.parentId ??= agent.parentId;
      row.startedAt ??= agent.startedAt;
      row.delegationId ??= agent.delegationId;
      row.acceptingSteer = agent.acceptingSteer ?? row.acceptingSteer;
      if (newerFrame) continue;
      row.toolCount = agent.toolCount ?? row.toolCount;
      row.lastTool = agent.lastTool ?? row.lastTool;
      // Ended states stick; a list never brings an ended row back.
      if (!row.completedByFrame && (row.active || !agent.state.active)) {
        row.state = agent.state;
      }
    }
    for (final row in _rows.values) {
      if (row.active &&
          !listedIds.contains(row.id) &&
          !row.completedByFrame &&
          row.frameSeq <= startSeq) {
        // Gone from the list with no completion frame: ended, never finished.
        row.state = AgentState.ended;
      }
    }
    for (final failed in list.delegations) {
      final duplicate = _rows.values.any(
        (row) =>
            (row.delegationId == failed.delegationId &&
                row.taskIndex == failed.taskIndex) ||
            // The agent's own row may know neither id: it ended before the
            // list ever named its delegation.
            (!row.active &&
                row.goal.isNotEmpty &&
                row.goal == failed.goal &&
                (row.delegationId ?? failed.delegationId) ==
                    failed.delegationId &&
                (row.taskIndex ?? failed.taskIndex) == failed.taskIndex),
      );
      if (duplicate) {
        _delegations.remove(failed.key);
        continue;
      }
      final row = _delegations.putIfAbsent(
        failed.key,
        () => RosterRow(id: failed.key, order: _order++)..delegationOnly = true,
      );
      row.state = failed.state.active ? AgentState.failed : failed.state;
      row.goal = failed.goal ?? row.goal;
      row.error = failed.error;
      row.startedAt = failed.dispatchedAt ?? row.startedAt;
      row.delegationId = failed.delegationId;
      row.taskIndex = failed.taskIndex;
    }
  }

  // ---- reading the roster ---------------------------------------------

  RosterRow? row(String id) => _rows[id] ?? _delegations[id];

  /// The agents as the panel lists them: running and starting under Now,
  /// everything else under This session, each ordered by start time, nested
  /// under a parent listed in the same section up to [kMaxNesting] levels.
  AgentSections get sections {
    final all = [..._rows.values, ..._delegations.values];
    int byStart(RosterRow a, RosterRow b) {
      // A row with no start time (seen only by a frame so far) is the newest.
      final left = a.startedAt, right = b.startedAt;
      if (left != null && right != null && left != right) {
        return left.compareTo(right);
      }
      if ((left == null) != (right == null)) return left == null ? 1 : -1;
      return a.order.compareTo(b.order);
    }

    final now = all.where((row) => row.active).toList()..sort(byStart);
    final ended = all.where((row) => !row.active).toList()..sort(byStart);
    final shown = ended.length > kEndedKept
        ? ended.sublist(ended.length - kEndedKept)
        : ended;
    return AgentSections(
      now: _place(now),
      session: _place(shown),
      hiddenEnded: ended.length - shown.length,
    );
  }

  List<PlacedAgent> _place(List<RosterRow> section) {
    final byId = {for (final row in section) row.id: row};
    final children = <String, List<RosterRow>>{};
    final tops = <RosterRow>[];
    for (final row in section) {
      final parent = row.parentId;
      if (parent != null && parent != row.id && byId.containsKey(parent)) {
        (children[parent] ??= []).add(row);
      } else {
        tops.add(row);
      }
    }
    final placed = <PlacedAgent>[];
    final seen = <String>{};
    void visit(RosterRow row, int level) {
      if (!seen.add(row.id)) return;
      placed.add(PlacedAgent(row, level));
      for (final child in children[row.id] ?? const <RosterRow>[]) {
        // A fourth level is drawn at the third.
        visit(child, level + 1 < kMaxNesting ? level + 1 : kMaxNesting - 1);
      }
    }

    for (final row in tops) {
      visit(row, 0);
    }
    // A parent cycle has no top; show its rows rather than hide them.
    for (final row in section) {
      visit(row, 0);
    }
    return placed;
  }

  /// A host for the detail of [id], for `SubagentDetailController`.
  AgentDetailHost hostFor(String id) => _RosterHost(this, id);

  bool get hasAgents => _rows.isNotEmpty || _delegations.isNotEmpty;

  // ---- environment ----------------------------------------------------

  void _onEnvironment() {
    if (_disposed) return;
    final connection = _env.connection;
    if (!identical(connection, _seenConnection)) {
      // A new connection: nothing learned about the last one applies, and an
      // answer still in flight belongs to the old one.
      _seenConnection = connection;
      _generation++;
      _unsupportedOn = _blockedOn = null;
      _programsUnsupportedOn = _programsBlockedOn = null;
      _loggedUnsupported = _loggedProgramsUnsupported = false;
      _listed = _programsListed = false;
      _inFlight = _programsInFlight = null;
      _programsLookedFor.clear();
      _backoff.reset();
    }
    notifyListeners();
    _round(agents: _inFlight == null, programs: _programsInFlight == null);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _log(String name, Map<String, Object> attributes) {
    try {
      events(name, attributes);
    } on Object {
      // Telemetry never breaks the roster.
    }
  }

  /// Drops every row and cancels what is in flight: sign-out, server change,
  /// and a chat or profile that is no longer this one.
  void clear() {
    _generation++;
    _inFlight = _programsInFlight = null;
    _listed = _programsListed = false;
    _programsLookedFor.clear();
    _rows.clear();
    _delegations.clear();
    _lastReadFailed = false;
    _changed();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _env.changes.removeListener(_onEnvironment);
    _rows.clear();
    _delegations.clear();
    super.dispose();
  }

  @override
  String toString() =>
      'SubagentRoster(rows: ${_rows.length}, delegations: ${_delegations.length})';
}

class _RosterHost implements AgentDetailHost {
  _RosterHost(this._roster, this._id);
  final SubagentRoster _roster;
  final String _id;

  @override
  Listenable get changes => _roster;

  @override
  AgentView? get view => _roster.row(_id)?.toView();

  @override
  bool get online => _roster._env.connection != null;

  @override
  bool get readingAllowed =>
      _roster._env.foreground && _roster._env.unlocked && _roster._demand > 0;

  @override
  bool get unlocked => _roster._env.unlocked;

  /// What the re-read list says of this agent, not what a frame that landed
  /// meanwhile says: a completion frame counts as an end, but a progress
  /// frame does not make an agent the list no longer has look alive.
  @override
  Future<AgentWorkResult<AgentView?>> rereadList() async {
    final result = await _roster.readNow();
    return switch (result) {
      WorkOk(:final value) => WorkOk(_answer(value)),
      WorkNotAttached() => const WorkNotAttached(),
      WorkUnsupported() => const WorkUnsupported(),
      WorkLost() => const WorkLost(),
      WorkFailed(:final kind) => WorkFailed(kind),
    };
  }

  AgentView? _answer(AgentList list) {
    final row = _roster.row(_id);
    if (row == null) return null;
    if (!row.active && row.completedByFrame) return row.toView();
    final listed = list.agents.where((agent) => agent.id == _id).firstOrNull;
    if (listed == null) {
      // Gone from the list: ended, whatever a frame said since.
      return AgentView(
        state: row.active ? AgentState.ended : row.state,
        goal: row.goal,
        startedAt: row.startedAt,
        summary: row.summary,
        error: row.error,
      );
    }
    return AgentView(
      state: row.active ? listed.state : row.state,
      goal: row.goal,
      startedAt: row.startedAt,
      acceptingSteer: listed.acceptingSteer ?? row.acceptingSteer,
      summary: row.summary,
      error: row.error,
    );
  }
}

class _ProgramHost implements ProcessStopHost {
  _ProgramHost(this._roster, this._id);
  final SubagentRoster _roster;
  final String _id;

  @override
  late final Listenable changes = Listenable.merge([
    _roster,
    _roster.programs!.cardChanges,
  ]);

  @override
  ProcessOutput? get card => _roster._programCards?.card(_id);

  @override
  bool get online => _roster._env.connection != null;

  @override
  Future<AgentWorkResult<ListedProcess?>> rereadList() async {
    final result = await _roster.readProgramsNow();
    return switch (result) {
      WorkOk(:final value) => WorkOk(
        value.processes.where((process) => process.id == _id).firstOrNull,
      ),
      WorkNotAttached() => const WorkNotAttached(),
      WorkUnsupported() => const WorkUnsupported(),
      WorkLost() => const WorkLost(),
      WorkFailed(:final kind) => WorkFailed(kind),
    };
  }

  @override
  void applyKill(ProcessKill answer) {
    final cards = _roster.programs!;
    final attachment = cards.attachmentOf(_roster.threadId);
    final state = attachment == null
        ? null
        : cards.cardsFor(_roster.threadId, attachment);
    if (_roster._disposed || attachment == null || state == null) return;
    state.applyKill(_id, answer, attachment: attachment);
    cards.cardsChanged();
    _roster._changed();
  }
}
