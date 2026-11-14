import 'process_output_state.dart';
import 'subagents/process_models.dart';
import 'subagents/process_stop_controller.dart';
import 'widgets/process_output_card.dart';

/// What a program card shows of the list, or null when the list never named
/// the program: the card then keeps the wording it had before the list
/// existed, with no state icon, so it never reads as running or succeeded.
ProcessCardInfo? processCardInfo(
  ProcessOutput card, {
  ProcessStopStatus stop = ProcessStopStatus.idle,
}) {
  final status = card.status;
  if (status == null) return null;
  return ProcessCardInfo(
    command: card.command,
    status: switch (status) {
      ProgramStatus.running => ProcessCardStatus.running,
      ProgramStatus.stopped => ProcessCardStatus.stopped,
      ProgramStatus.exited => ProcessCardStatus.exited,
      ProgramStatus.ended => ProcessCardStatus.ended,
    },
    exitCode: status == ProgramStatus.exited ? card.exitCode : null,
    runTime: card.uptime,
    seeded: card.seeded,
    stop: stop,
  );
}

/// How a Stop's phase reads on the card. The open confirmation and a
/// confirmation closed because the program ended draw no banner; neither
/// does a server without `process.kill`, whose card simply loses Stop.
ProcessStopStatus processStopStatusOf(ProcessStopPhase phase) =>
    switch (phase) {
      ProcessStopPhase.idle ||
      ProcessStopPhase.confirming ||
      ProcessStopPhase.ended ||
      ProcessStopPhase.unsupported => ProcessStopStatus.idle,
      ProcessStopPhase.sending => ProcessStopStatus.sending,
      ProcessStopPhase.checking => ProcessStopStatus.checking,
      ProcessStopPhase.killed => ProcessStopStatus.killed,
      ProcessStopPhase.alreadyEnded => ProcessStopStatus.alreadyEnded,
      ProcessStopPhase.notListed => ProcessStopStatus.notListed,
      ProcessStopPhase.failed => ProcessStopStatus.failed,
      ProcessStopPhase.unconfirmed => ProcessStopStatus.unconfirmed,
    };
