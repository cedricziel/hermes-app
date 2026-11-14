import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../network/poll_backoff.dart';
import '../chat_models.dart';
import 'agent_detail_host.dart';
import 'agent_models.dart';
import 'roster_row.dart';
import 'agent_work_result.dart';
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
        if (_demand > 0 && _gatesOpen) unawaited(_read());
      });
    }
    return RosterWatch._(() {
      if (_disposed || --_demand > 0) return;
      _timer?.cancel();
      _timer = null;
    });
  }

  bool get _gatesOpen =>
      !_disposed &&
      _demand > 0 &&
      _env.foreground &&
      _env.unlocked &&
      _env.connection != null &&
      !identical(_unsupportedOn, _env.connection) &&
      !identical(_blockedOn, _env.connection);

  bool get _anyActive => _rows.values.any((row) => row.active);

  void _tick() {
    // Until one read has answered, a chat with no frame rows still needs
    // reading: its agents may have started from another client.
    if (!_gatesOpen || !(_anyActive || !_listed) || !_backoff.tick()) return;
    unawaited(_read());
  }

  /// The chat's stored id changed (a new chat got its first one). Rows from
  /// frames stay; answers still in flight are dropped.
  void retarget(String threadId) {
    if (_disposed || this.threadId == threadId) return;
    this.threadId = threadId;
    _generation++;
    _inFlight = null;
    _listed = false;
    _blockedOn = null;
  }

  /// The session now holds the connection (an action attached it), so list
  /// reads may start again after a 4001.
  void markAttached() {
    if (_blockedOn == null) return;
    _blockedOn = null;
    if (_gatesOpen) unawaited(_read());
  }

  /// Reads the list now, after any read already in flight, and answers what
  /// the read came to. Used for the re-read after a stop.
  Future<AgentWorkResult<AgentList>> readNow() async {
    final pending = _inFlight;
    if (pending != null) await pending;
    if (_disposed) return const WorkLost();
    return _read(force: true);
  }

  Future<AgentWorkResult<AgentList>> _read({bool force = false}) {
    final running = _inFlight;
    if (!force && running != null) return running;
    late final Future<AgentWorkResult<AgentList>> read;
    read = _readOnce(force: force).whenComplete(() {
      if (identical(_inFlight, read)) _inFlight = null;
    });
    return _inFlight = read;
  }

  Future<AgentWorkResult<AgentList>> _readOnce({required bool force}) async {
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
        _backoff.succeeded();
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
        _backoff.failed();
        return WorkFailed(kind);
      case WorkLost():
        _lastReadFailed = true;
        _backoff.failed();
        return const WorkLost();
    }
  }

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
      _loggedUnsupported = false;
      _listed = false;
      _inFlight = null;
      _backoff.reset();
    }
    notifyListeners();
    if (_gatesOpen && _inFlight == null) unawaited(_read());
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
    _inFlight = null;
    _listed = false;
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
