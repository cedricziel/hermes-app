import 'dart:math';

import 'gateway_rpc_client.dart';

/// Tracks, per runtime session, the highest event `seq` already delivered, so
/// a replay after a reconnect and the live frames that overlap it never hand
/// the same event to the reply twice.
class ReplayLedger {
  final Map<String, int> _watermarks = {};

  /// Whether an event with [seq] in session [sid] is new. A new event raises
  /// the session's watermark. An event without a seq cannot be ordered, so it
  /// is always delivered and leaves the watermark alone.
  bool observe(String sid, int? seq) {
    if (seq == null) return true;
    final watermark = _watermarks[sid];
    if (watermark != null && seq <= watermark) return false;
    _watermarks[sid] = seq;
    return true;
  }

  /// The highest seq delivered for [sid], or 0 when none was.
  int lastSeen(String sid) => _watermarks[sid] ?? 0;

  /// Reconciles a `session.events.since` answer with the live frames parked
  /// while it was in flight.
  ///
  /// A new server epoch means the seqs were numbered by a different process,
  /// so every watermark is dropped and the caller must refetch. A truncated
  /// answer is refetched too, and the watermark stays where it was: parked
  /// events are still checked against it, and jumping to `latest_seq` would
  /// lose the deltas the server sent after the snapshot.
  ReplayDecision merge({
    required String sid,
    required Map<String, Object?> result,
    required List<GatewayEvent> parked,
    required String? connectionEpoch,
  }) {
    final epoch = result['epoch'];
    if (connectionEpoch != null &&
        epoch is String &&
        epoch != connectionEpoch) {
      _watermarks.clear();
      return const Refetch();
    }
    if (result['truncated'] == true) return const Refetch();

    final delivered = <GatewayEvent>[];
    for (final event in [..._replayed(sid, result['events']), ...parked]) {
      if (event.sessionId != sid) continue;
      if (observe(sid, event.seq)) delivered.add(event);
    }
    return Deliver(delivered);
  }

  static Iterable<GatewayEvent> _replayed(String sid, Object? elements) sync* {
    if (elements is! List) return;
    for (final element in elements) {
      if (element is! Map) continue;
      final type = element['type'];
      if (type is! String) continue;
      final sessionId = element['session_id'];
      final seq = element['seq'];
      yield GatewayEvent(
        type: type,
        sessionId: sessionId is String && sessionId.isNotEmpty
            ? sessionId
            : sid,
        payload: _payload(element['payload']),
        seq: seq is int ? seq : null,
      );
    }
  }

  static Map<String, Object?> _payload(Object? raw) {
    if (raw is! Map) return const {};
    return {for (final entry in raw.entries) entry.key.toString(): entry.value};
  }
}

/// What the transport does with a replay: hand the events to the reply, or
/// rebuild the reply from the server's state.
sealed class ReplayDecision {
  const ReplayDecision();
}

/// Deliver [events] in order to the reply.
final class Deliver extends ReplayDecision {
  const Deliver(this.events);

  final List<GatewayEvent> events;
}

/// The replay cannot be trusted to cover the gap. The caller rebuilds the
/// reply from `inflight` or from the stored messages.
final class Refetch extends ReplayDecision {
  const Refetch();
}

/// The delay before reconnect attempt [attempt] (from 0). The bound doubles
/// from [base] up to [cap], and the actual delay is drawn uniformly below it,
/// so clients that dropped together do not reconnect in lockstep.
Duration reconnectDelay(
  int attempt,
  Random random, {
  Duration base = const Duration(milliseconds: 300),
  Duration cap = const Duration(seconds: 15),
}) {
  final grown = base.inMicroseconds * pow(2, attempt).toDouble();
  final bound = min(cap.inMicroseconds.toDouble(), grown);
  return Duration(microseconds: (random.nextDouble() * bound).floor());
}

/// How long a prompt may go without its turn starting before a stale
/// `session.info` (`running: false`) is taken for the end of the turn.
const Duration _staleReportGrace = Duration(seconds: 15);

/// Whether a `session.info` reporting `running: false` may end a reply.
///
/// A report that arrives just after `prompt.submit`, before the turn started,
/// can describe the previous turn, so it is ignored until the grace passes.
bool settles({
  required bool started,
  required DateTime submittedAt,
  required DateTime now,
}) {
  if (started) return true;
  return now.difference(submittedAt) >= _staleReportGrace;
}
