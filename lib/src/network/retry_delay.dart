import 'dart:math';

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
