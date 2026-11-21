import '../widgets/curator_run_confirmation.dart';
import '../widgets/curator_section.dart';
import 'curator_controller.dart';
import 'curator_status.dart';

/// What the section shows for a [CuratorController], and nothing it decides
/// itself: Run now and Check status follow the controller's own answers. Pure
/// reads, so it holds no state and sends nothing.
///
/// The controller's `unsupported` load hides the section before this is
/// called (`CuratorController.visible`), so it has no view. Hermes' own text
/// (a refused pause, a spawn failure, a failed pass's last line) never
/// reaches the controller, so the three detail fields stay empty.
CuratorSectionModel curatorSectionModel(CuratorController c, {DateTime? now}) {
  final status = c.status;
  return CuratorSectionModel(
    load: curatorLoadView(c.load),
    status: status == null ? null : curatorStatusView(status),
    refreshing: c.refreshing,
    pause: curatorPauseView(c.pause),
    paused: c.paused,
    run: curatorRunView(c.phase),
    notStarted: c.notStarted == null
        ? null
        : curatorNotStartedView(c.notStarted!),
    checking: c.checking,
    checkFailed: c.checkFailed,
    startedAt: c.startedAt,
    outputLines: c.outputLines,
    earlierLines: c.earlierLines,
    hasOutput: c.hasOutput,
    outputBlanked: c.blanked,
    outputDropped: c.outputDropped,
    canRunNow: c.canRunNow,
    canCheck: c.canCheck,
    now: now,
  );
}

/// [CuratorLoad.unsupported] has no view: the section is not built then.
CuratorLoadView curatorLoadView(CuratorLoad load) => switch (load) {
  CuratorLoad.loading => CuratorLoadView.loading,
  CuratorLoad.loaded => CuratorLoadView.loaded,
  CuratorLoad.offline => CuratorLoadView.offline,
  CuratorLoad.unavailable => CuratorLoadView.unavailable,
  CuratorLoad.failed => CuratorLoadView.failed,
  CuratorLoad.lost => CuratorLoadView.lost,
  CuratorLoad.profileGone => CuratorLoadView.profileGone,
  CuratorLoad.unsupported => CuratorLoadView.failed,
};

CuratorPauseView curatorPauseView(CuratorPause pause) => switch (pause) {
  CuratorPause.idle => CuratorPauseView.idle,
  CuratorPause.saving => CuratorPauseView.saving,
  CuratorPause.failed => CuratorPauseView.failed,
  CuratorPause.lost => CuratorPauseView.lost,
  CuratorPause.offline => CuratorPauseView.offline,
  CuratorPause.profileGone => CuratorPauseView.profileGone,
};

CuratorRunView curatorRunView(CuratorRunPhase phase) => switch (phase) {
  CuratorRunPhase.opening => CuratorRunView.opening,
  CuratorRunPhase.idle => CuratorRunView.idle,
  CuratorRunPhase.starting => CuratorRunView.starting,
  CuratorRunPhase.following => CuratorRunView.following,
  CuratorRunPhase.finished => CuratorRunView.finished,
  CuratorRunPhase.failed => CuratorRunView.failed,
  CuratorRunPhase.stopped => CuratorRunView.stopped,
  CuratorRunPhase.unconfirmed => CuratorRunView.unconfirmed,
  CuratorRunPhase.notStarted => CuratorRunView.notStarted,
  CuratorRunPhase.lostAnswer => CuratorRunView.lostAnswer,
  CuratorRunPhase.progressLost => CuratorRunView.progressLost,
  CuratorRunPhase.stillRunning => CuratorRunView.stillRunning,
  CuratorRunPhase.elsewhere => CuratorRunView.elsewhere,
  CuratorRunPhase.unchecked => CuratorRunView.unchecked,
  CuratorRunPhase.checkedNothing => CuratorRunView.checkedNothing,
};

CuratorNotStartedView curatorNotStartedView(CuratorNotStarted why) =>
    switch (why) {
      CuratorNotStarted.offline => CuratorNotStartedView.offline,
      CuratorNotStarted.refused => CuratorNotStartedView.refused,
      CuratorNotStarted.spawnFailed => CuratorNotStartedView.spawnFailed,
      CuratorNotStarted.profileGone => CuratorNotStartedView.profileGone,
    };

CuratorStatusView curatorStatusView(CuratorStatus s) => CuratorStatusView(
  enabled: s.enabled,
  paused: s.paused,
  intervalHours: s.intervalHours,
  lastRun: switch (s.lastRun) {
    CuratorLastRun.never => CuratorLastRunView.never,
    CuratorLastRun.at => CuratorLastRunView.at,
    CuratorLastRun.unknown => CuratorLastRunView.unknown,
  },
  lastRunAt: s.lastRunAt,
  staleAfterDays: s.staleAfterDays,
  archiveAfterDays: s.archiveAfterDays,
);

/// The confirmation's numbers and flags: the status read's days, and the
/// config switches once they are read (null until then, and when unreadable).
CuratorRunConfirmationModel curatorConfirmationModel(CuratorController c) =>
    CuratorRunConfirmationModel(
      staleAfterDays: c.status?.staleAfterDays,
      archiveAfterDays: c.status?.archiveAfterDays,
      pruneBuiltins: c.confirmation?.pruneBuiltins,
      consolidate: c.confirmation?.consolidate,
    );
