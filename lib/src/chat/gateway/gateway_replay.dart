import 'dart:math';

import 'gateway_rpc_client.dart';

/// Tracks, per runtime session, the highest event `seq` already delivered, so
/// a replay after a reconnect and the live frames that overlap it never hand
/// the same event to the reply twice.
///
/// A seq only means something within the server process that numbered it, so
/// each watermark remembers the replay epoch it was recorded at.
class ReplayLedger {
  final Map<String, int> _watermarks = {};
  final Map<String, String> _epochs = {};

  /// Whether an event with [seq] in session [sid] is new. A new event raises
  /// the session's watermark and records the [epoch] it arrived in, when known.
  /// An event without a seq cannot be ordered, so it is always delivered and
  /// leaves the watermark alone.
  bool observe(String sid, int? seq, {String? epoch}) {
    if (seq == null) return true;
    // Another epoch numbers its seqs from 1 again, so a watermark recorded in
    // the old one says nothing about this event.
    final recorded = _epochs[sid];
    if (recorded != null && epoch != null && recorded != epoch) {
      _watermarks.remove(sid);
      _epochs.remove(sid);
    }
    final watermark = _watermarks[sid];
    if (watermark != null && seq <= watermark) return false;
    _watermarks[sid] = seq;
    if (epoch != null) _epochs[sid] = epoch;
    return true;
  }

  /// The highest seq delivered for [sid], or 0 when none was.
  int lastSeen(String sid) => _watermarks[sid] ?? 0;

  /// Whether any event of [sid] was delivered with a seq. Without one there is
  /// nothing to replay from: `last_seen: 0` would hand over the whole ring.
  bool hasWatermark(String sid) => _watermarks.containsKey(sid);

  /// The seq a watch of [sid] on a connection at [epoch] starts after: the
  /// watermark, unless it was recorded at another epoch.
  int resumeFrom(String sid, String? epoch) {
    final recorded = _epochs[sid];
    if (recorded != null && epoch != null && recorded != epoch) return 0;
    return lastSeen(sid);
  }

  /// A copy of what the ledger holds now.
  ReplayLedger snapshot() => ReplayLedger()
    .._watermarks.addAll(_watermarks)
    .._epochs.addAll(_epochs);

  /// The replay epoch [sid]'s watermark was recorded at, or null when none was
  /// known.
  String? epochOf(String sid) => _epochs[sid];

  /// Reconciles a `session.events.since` answer with the live frames parked
  /// while it was in flight.
  ///
  /// An answer from another epoch than the one the watermark was recorded at
  /// means a different process numbered the seqs, so the watermarks recorded
  /// at any other epoch are dropped and the caller must refetch. A truncated answer is refetched too,
  /// and the watermark stays where it was: parked events are still checked
  /// against it, and jumping to `latest_seq` would lose the deltas the server
  /// sent after the snapshot.
  ReplayDecision merge({
    required String sid,
    required Map<String, Object?> result,
    required List<GatewayEvent> parked,
  }) {
    final epoch = result['epoch'];
    final recorded = _epochs[sid];
    if (recorded != null && epoch is String && epoch != recorded) {
      for (final stale in [
        for (final entry in _epochs.entries)
          if (entry.value != epoch) entry.key,
      ]) {
        _watermarks.remove(stale);
        _epochs.remove(stale);
      }
      return const Refetch();
    }
    if (result['truncated'] == true) return const Refetch();

    final delivered = <GatewayEvent>[];
    for (final event in [..._replayed(sid, result['events']), ...parked]) {
      if (event.sessionId != sid) continue;
      if (observe(sid, event.seq, epoch: epoch is String ? epoch : null)) {
        delivered.add(event);
      }
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
