import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../l10n/l10n.dart';
import '../../chat/widgets/relative_time.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/busy_bar.dart';
import '../../widgets/grouped_action_row.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/output_lines_tile.dart';

// The view of the curator controller's state. The names match the
// controller's enums, so the screen maps them with `byName`.

/// Where the status read stands; an old server hides the section, so it has
/// no value here.
enum CuratorLoadView {
  loading,
  loaded,
  offline,
  unavailable,
  failed,
  profileGone,

  /// The read got no answer in time; reads are safe to repeat.
  lost,
}

enum CuratorLastRunView { never, at, unknown }

enum CuratorPauseView { idle, saving, failed, lost, offline, profileGone }

enum CuratorRunView {
  opening,
  idle,
  starting,
  following,
  finished,
  failed,
  stopped,
  unconfirmed,
  notStarted,
  lostAnswer,
  progressLost,
  stillRunning,
  elsewhere,
  unchecked,
  checkedNothing,
}

enum CuratorNotStartedView { offline, refused, spawnFailed, profileGone }

/// What `GET /api/curator` said; every field may be unknown.
class CuratorStatusView {
  const CuratorStatusView({
    this.enabled,
    this.paused,
    this.intervalHours,
    this.lastRun = CuratorLastRunView.unknown,
    this.lastRunAt,
    this.staleAfterDays,
    this.archiveAfterDays,
  });

  /// Null counts as on, as Hermes' default does.
  final bool? enabled;
  final bool? paused;
  final int? intervalHours;
  final CuratorLastRunView lastRun;
  final DateTime? lastRunAt;
  final int? staleAfterDays;
  final int? archiveAfterDays;

  bool get isOn => enabled != false;
}

/// Everything [CuratorSection] shows. Output lines are display strings
/// already; the widget never selects or copies them.
class CuratorSectionModel {
  const CuratorSectionModel({
    this.load = CuratorLoadView.loaded,
    this.status,
    this.refreshing = false,
    this.pause = CuratorPauseView.idle,
    this.paused,
    this.run = CuratorRunView.idle,
    this.notStarted,
    this.notStartedDetail,
    this.pauseDetail,
    this.failureLine,
    this.checking = false,
    this.checkFailed = false,
    this.startedAt,
    this.outputLines = const [],
    this.earlierLines = 0,
    this.hasOutput = false,
    this.outputBlanked = false,
    this.outputDropped = false,
    this.canRunNow = false,
    this.canCheck = false,
    this.now,
  });

  final CuratorLoadView load;
  final CuratorStatusView? status;
  final bool refreshing;
  final CuratorPauseView pause;

  /// The switch: the value being sent while saving, else Hermes' answer.
  final bool? paused;
  final CuratorRunView run;
  final CuratorNotStartedView? notStarted;

  /// Hermes' own text of a spawn failure. Server text: it must arrive already
  /// cleaned for display (control and bidi characters made visible), like the
  /// output lines. The widget shows it in a title and never makes it
  /// selectable.
  final String? notStartedDetail;

  /// Hermes' text when it refused a pause change. Same rules as
  /// [notStartedDetail].
  final String? pauseDetail;

  /// Hermes' last line of a failed pass. Same rules as [notStartedDetail].
  final String? failureLine;
  final bool checking;
  final bool checkFailed;
  final DateTime? startedAt;
  final List<String> outputLines;
  final int earlierLines;

  /// The pass printed lines, even when they are blanked now.
  final bool hasOutput;
  final bool outputBlanked;

  /// The lines were dropped (App Lock) and are gone, not just hidden.
  final bool outputDropped;

  /// The controller's answers: the widget obeys them and keeps no rule of
  /// its own. Run now is enabled with [canRunNow]; Check status with
  /// [canCheck].
  final bool canRunNow;
  final bool canCheck;

  /// The clock for "3 days ago"; the device's when null.
  final DateTime? now;
}

class CuratorSectionCallbacks {
  const CuratorSectionCallbacks({
    required this.onTryAgain,
    required this.onPausedChanged,
    required this.onRunNow,
    required this.onCheckStatus,
  });

  final VoidCallback onTryAgain;
  final ValueChanged<bool> onPausedChanged;

  /// Opens the confirmation; nothing is sent until its Run now.
  final VoidCallback onRunNow;
  final VoidCallback onCheckStatus;
}

/// "Every hour", "Every day", "Every 2 days", "Every 12 hours".
String curatorIntervalLabel(AppLocalizations l10n, int hours) {
  if (hours == 1) return l10n.skillsCuratorEveryHour;
  if (hours % 24 == 0) return l10n.skillsCuratorEveryDays(hours ~/ 24);
  return l10n.skillsCuratorEveryHours(hours);
}

String _length(AppLocalizations l10n, int hours) => hours % 24 == 0
    ? l10n.skillsCuratorLengthDays(hours ~/ 24)
    : l10n.skillsCuratorLengthHours(hours);

/// The skill curator of one profile as a settings group: its status, the
/// pause switch and the Run now row with its result. A plain-model widget:
/// the controller's state in, callbacks out.
///
/// It announces to a screen reader, once each and only when the state
/// changes (never when it first builds and never while polling): a pass
/// starting, ending, and the switch turning on or off.
class CuratorSection extends StatefulWidget {
  const CuratorSection({
    super.key,
    required this.model,
    required this.callbacks,
    this.outputInitiallyOpen = false,
  });

  /// Opens the "Show output" tile at first, for the catalog and tests.
  final bool outputInitiallyOpen;
  final CuratorSectionModel model;
  final CuratorSectionCallbacks callbacks;

  @override
  State<CuratorSection> createState() => _CuratorSectionState();
}

class _CuratorSectionState extends State<CuratorSection> {
  @override
  void didUpdateWidget(CuratorSection old) {
    super.didUpdateWidget(old);
    final was = old.model;
    final now = widget.model;
    final l10n = context.l10n;
    bool ended(CuratorRunView r) =>
        r == CuratorRunView.finished || r == CuratorRunView.failed;
    // Only once Hermes has answered: `starting` may still end in a lost
    // answer or a refusal.
    final text =
        now.run == CuratorRunView.following &&
            (was.run == CuratorRunView.starting ||
                was.run == CuratorRunView.lostAnswer)
        ? l10n.skillsCuratorAnnounceStarted
        : now.run == CuratorRunView.finished && !ended(was.run)
        ? l10n.skillsCuratorAnnounceFinished
        : now.run == CuratorRunView.failed && !ended(was.run)
        ? l10n.skillsCuratorFailed
        : was.pause == CuratorPauseView.saving &&
              now.pause == CuratorPauseView.idle
        ? (now.paused == true
              ? l10n.skillsCuratorStatusPaused
              : l10n.skillsCuratorAnnounceResumed)
        : null;
    if (text != null) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          text,
          Directionality.of(context),
        ).catchError((Object _) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _CuratorBody(
    model: widget.model,
    callbacks: widget.callbacks,
    outputInitiallyOpen: widget.outputInitiallyOpen,
  );
}

class _CuratorBody extends StatelessWidget {
  const _CuratorBody({
    required this.model,
    required this.callbacks,
    required this.outputInitiallyOpen,
  });

  final bool outputInitiallyOpen;
  final CuratorSectionModel model;
  final CuratorSectionCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = model.status;
    final loaded = model.load == CuratorLoadView.loaded && status != null;
    final shownFooter = model.load == CuratorLoadView.loading || loaded;
    return GroupedSection(
      header: l10n.skillsCuratorTitle,
      footer: shownFooter ? l10n.skillsCuratorFooter : null,
      children: loaded
          ? [
              if (model.refreshing) const BusyBar(minHeight: 3),
              ..._rows(context, l10n, status),
            ]
          : [_unloaded(context, l10n)],
    );
  }

  Widget _unloaded(BuildContext context, AppLocalizations l10n) {
    final retry = TextButton(
      onPressed: callbacks.onTryAgain,
      style: ButtonStyle(
        visualDensity: platformChromeOf(context) == PlatformChrome.macos
            ? VisualDensity.standard
            : null,
      ),
      child: Text(l10n.skillsCuratorTryAgain),
    );
    final banner = switch (model.load) {
      CuratorLoadView.offline => AppBanner(
        tone: AppBannerTone.warning,
        icon: AppIcons.wifiOff,
        title: l10n.skillsCuratorCantReach,
        detail: l10n.skillsCuratorCantReachDetail,
        action: retry,
      ),
      CuratorLoadView.unavailable => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.skillsCuratorUnavailable,
        action: retry,
      ),
      CuratorLoadView.profileGone => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.skillsCuratorProfileGone,
      ),
      CuratorLoadView.lost => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.skillsCuratorLostState,
        action: retry,
      ),
      CuratorLoadView.loading => null,
      _ => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.skillsCuratorLoadFailed,
        action: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(12),
      child: banner ?? LoadingSkeleton(label: l10n.skillsCuratorLoading),
    );
  }

  List<Widget> _rows(
    BuildContext context,
    AppLocalizations l10n,
    CuratorStatusView status,
  ) {
    final paused = status.paused;
    final interval = status.intervalHours;
    final stale = status.staleAfterDays;
    final archive = status.archiveAfterDays;
    final everyLabel = interval == null
        ? null
        : curatorIntervalLabel(l10n, interval);
    // A long value would be cut at half the row, so it moves to the subtitle.
    final longEvery = everyLabel != null && everyLabel.length > 16;
    final off = !status.isOn;
    final statusValue = off
        ? l10n.commonOff
        : paused == null
        ? l10n.skillsCuratorStatusUnknown
        : paused
        ? l10n.skillsCuratorStatusPaused
        : l10n.skillsCuratorStatusActive;
    final statusNote = !off && paused == true
        ? l10n.skillsCuratorPausedNote
        : null;
    // Beyond twice the text size the row puts the value under the title
    // itself: the grouped row's own stacking does not know this icon grows
    // with the text, and would leave "Status" too little room.
    final stackStatus = MediaQuery.textScalerOf(context).scale(17) >= 2 * 17;
    return [
      GroupedRow(
        title: l10n.skillsCuratorStatus,
        titleMaxLines: null,
        subtitleMaxLines: null,
        wrapWhenStacked: true,
        leading: AppIcon(
          size: _scaled(context, GroupedMetrics.of(context).leadingSize),
          off
              ? AppIcons.radioOff
              : paused == null
              ? AppIcons.info
              : paused
              ? AppIcons.pause
              : AppIcons.checkCircle,
        ),
        value: stackStatus ? null : statusValue,
        subtitle: stackStatus
            ? [statusValue, ?statusNote].join('\n')
            : statusNote,
      ),
      // A line of its own, so the value does not sit beside wrapped text.
      if (off) _NoteRow(l10n.skillsCuratorOffNote),
      if (!off) ...[
        _LastRanRow(status: status, now: model.now),
        GroupedRow(
          title: l10n.skillsCuratorSchedule,
          titleMaxLines: null,
          subtitleMaxLines: null,
          wrapWhenStacked: true,
          value: longEvery
              ? null
              : everyLabel ?? l10n.skillsCuratorStatusUnknown,
          subtitle: longEvery ? everyLabel : null,
        ),
        GroupedRow(
          title: l10n.skillsCuratorUnused,
          titleMaxLines: null,
          subtitleMaxLines: null,
          wrapWhenStacked: true,
          value: stale == null || archive == null
              ? l10n.skillsCuratorStatusUnknown
              : null,
          subtitle: stale == null || archive == null
              ? null
              : l10n.skillsCuratorUnusedNote(stale, archive),
        ),
        _pauseRow(context, l10n, paused),
        ..._runRows(context, l10n, status),
      ],
    ];
  }

  /// [size] at least, and as large as the text size asks.
  static double _scaled(BuildContext context, double size) =>
      math.max(size, MediaQuery.textScalerOf(context).scale(size));

  Widget _pauseRow(BuildContext context, AppLocalizations l10n, bool? known) {
    if (known == null) {
      return _NoteRow(l10n.skillsCuratorPauseUnreadable);
    }
    final saving = model.pause == CuratorPauseView.saving;
    final scale = math.min(
      2.0,
      math.max(1.0, MediaQuery.textScalerOf(context).scale(17) / 17),
    );
    Widget control = GroupedSwitch(
      value: model.paused ?? known,
      onChanged: saving ? null : callbacks.onPausedChanged,
      label: saving
          ? '${l10n.skillsCuratorPause}, ${l10n.skillsCuratorPauseSaving}'
          : l10n.skillsCuratorPause,
    );
    // The switch follows the text size, since the design system's does not:
    // its own size, scaled, at the start of the line, and never under the
    // platform's target.
    if (scale > 1) {
      final target = switch (platformChromeOf(context)) {
        PlatformChrome.material => 48.0,
        PlatformChrome.ios => kAppleMinTapTarget,
        PlatformChrome.macos => 28.0,
      };
      control = SizedBox(
        width: 52 * scale,
        height: math.max(target, 32 * scale),
        child: FittedBox(
          alignment: AlignmentDirectional.centerStart,
          child: control,
        ),
      );
    }
    final row = GroupedRow(
      title: l10n.skillsCuratorPause,
      titleMaxLines: null,
      subtitle: saving
          ? l10n.skillsCuratorPauseSaving
          : l10n.skillsCuratorPauseNote,
      subtitleMaxLines: null,
      trailing: control,
      separateTrailing: true,
      trailingBelow: scale > 1.3,
      error: switch (model.pause) {
        CuratorPauseView.failed =>
          model.pauseDetail == null || model.pauseDetail!.isEmpty
              ? l10n.skillsCuratorPauseFailed
              : l10n.skillsCuratorPauseFailedWith(model.pauseDetail!),
        CuratorPauseView.offline => l10n.skillsCuratorCantReach,
        _ => null,
      },
      warning: switch (model.pause) {
        CuratorPauseView.lost => l10n.skillsCuratorPauseLost,
        CuratorPauseView.profileGone => l10n.skillsCuratorProfileGone,
        _ => null,
      },
    );
    return saving ? Column(children: [row, _bar(context)]) : row;
  }

  Widget _bar(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      GroupedMetrics.of(context).rowPadding,
      0,
      GroupedMetrics.of(context).rowPadding,
      10,
    ),
    child: const BusyBar(minHeight: 3),
  );

  List<Widget> _runRows(
    BuildContext context,
    AppLocalizations l10n,
    CuratorStatusView status,
  ) {
    final run = model.run;
    final when = model.now;
    final lastAt = status.lastRunAt;
    GroupedActionButton check() => GroupedActionButton(
      label: l10n.skillsCuratorCheckStatus,
      onPressed: model.canCheck ? callbacks.onCheckStatus : null,
    );
    GroupedActionStatus line(GroupedActionPhase phase, String text) =>
        GroupedActionStatus(phase: phase, text: text, buttons: [check()]);
    // A Check status that got no answer adds its own line to the state's.
    GroupedActionStatus unsure(GroupedActionPhase phase, String text) => line(
      phase,
      model.checkFailed ? '$text\n${l10n.skillsCuratorCouldntConfirm}' : text,
    );
    final working =
        run == CuratorRunView.starting || run == CuratorRunView.following;
    String? subtitle = run == CuratorRunView.opening
        ? l10n.skillsCuratorChecking
        : l10n.skillsCuratorRunNowNote;
    GroupedActionStatus? state;
    if (model.checking) {
      state = GroupedActionStatus(
        phase: GroupedActionPhase.working,
        text: l10n.skillsCuratorChecking,
      );
    } else if (working) {
      subtitle = l10n.skillsCuratorLeaveNote;
      state = GroupedActionStatus(
        phase: GroupedActionPhase.working,
        text: l10n.skillsCuratorRunning,
      );
    } else {
      switch (run) {
        case CuratorRunView.stopped:
          state = unsure(GroupedActionPhase.neutral, l10n.skillsCuratorStopped);
        case CuratorRunView.unconfirmed:
          final at = model.startedAt?.toLocal();
          if (at != null) subtitle = l10n.skillsCuratorStartedAt(at, at);
          state = unsure(
            GroupedActionPhase.warning,
            l10n.skillsCuratorUnconfirmed,
          );
        case CuratorRunView.lostAnswer:
          state = unsure(
            GroupedActionPhase.warning,
            l10n.skillsCuratorLostStart,
          );
        case CuratorRunView.progressLost:
          state = unsure(
            GroupedActionPhase.warning,
            l10n.skillsCuratorProgressLost,
          );
        case CuratorRunView.stillRunning:
          state = unsure(
            GroupedActionPhase.neutral,
            l10n.skillsCuratorStillRunning,
          );
        case CuratorRunView.elsewhere:
          subtitle = l10n.skillsCuratorElsewhere;
          state = unsure(
            GroupedActionPhase.neutral,
            l10n.skillsCuratorElsewhereNote,
          );
        case CuratorRunView.unchecked:
          state = unsure(
            GroupedActionPhase.warning,
            l10n.skillsCuratorUnchecked,
          );
        case CuratorRunView.checkedNothing:
          state = GroupedActionStatus(
            phase: GroupedActionPhase.neutral,
            text: lastAt == null
                ? l10n.skillsCuratorCheckedNothing
                : l10n.skillsCuratorCheckedNothingSince(
                    relativeTimeLabel(l10n, lastAt, now: when, bareDate: true),
                  ),
          );
        case CuratorRunView.notStarted:
          final form = model.notStarted;
          final detail = model.notStartedDetail;
          state = GroupedActionStatus(
            phase: GroupedActionPhase.failed,
            text: switch (form) {
              CuratorNotStartedView.offline =>
                l10n.skillsCuratorNotStartedOffline,
              CuratorNotStartedView.profileGone =>
                l10n.skillsCuratorNotStartedProfile,
              CuratorNotStartedView.refused =>
                l10n.skillsCuratorNotStartedRefused,
              _ => [
                l10n.skillsCuratorNotStartedFailed,
                if (detail != null && detail.isNotEmpty) detail,
              ].join(' '),
            },
            buttons: form == CuratorNotStartedView.profileGone
                ? const []
                : [
                    GroupedActionButton(
                      label: l10n.skillsCuratorTryAgain,
                      onPressed: model.canRunNow ? callbacks.onRunNow : null,
                    ),
                  ],
          );
        default:
      }
    }
    final ended =
        run == CuratorRunView.finished || run == CuratorRunView.failed;
    // A stopped pass, and a check that found nothing after one, keep the
    // lines of the pass this app started: shown as the earlier pass's.
    final earlier =
        (run == CuratorRunView.stopped ||
            run == CuratorRunView.checkedNothing) &&
        (model.hasOutput || model.outputDropped);
    final failure = model.failureLine;
    return [
      if (ended) ...[
        GroupedRow(
          title: run == CuratorRunView.finished
              ? l10n.skillsCuratorFinished
              : failure == null || failure.isEmpty
              ? l10n.skillsCuratorFailed
              : l10n.skillsCuratorFailedWith(failure),
          titleMaxLines: null,
          subtitle: run == CuratorRunView.finished
              ? l10n.skillsCuratorFinishedNote
              : null,
          subtitleMaxLines: null,
          leading: AppIcon(
            size: _scaled(context, GroupedMetrics.of(context).leadingSize),
            run == CuratorRunView.finished
                ? AppIcons.checkCircle
                : AppIcons.error,
            color: run == CuratorRunView.finished
                ? context.hermesColors.success
                : Theme.of(context).colorScheme.error,
          ),
        ),
        _output(l10n),
      ],
      if (earlier) _output(l10n, earlier: true),
      GroupedActionRow(
        title: ended ? l10n.skillsCuratorRunAgain : l10n.skillsCuratorRunNow,
        icon: AppIcons.play,
        // A disabled row always says why: the subtitle or the status line.
        subtitle: ended && model.canRunNow ? null : subtitle,
        touchTargetButtons: true,
        onPressed: model.canRunNow ? callbacks.onRunNow : null,
        status: state,
        spinnerWhileWorking: true,
        semanticLabel: working ? l10n.skillsCuratorRunNowRunning : null,
      ),
    ];
  }

  Widget _output(AppLocalizations l10n, {bool earlier = false}) {
    if (!model.hasOutput) {
      return _NoteRow(
        model.outputDropped
            ? l10n.skillsCuratorOutputCleared
            : l10n.skillsCuratorNoOutput,
      );
    }
    final count = model.outputLines.length + model.earlierLines;
    return OutputLinesTile(
      label: earlier
          ? l10n.skillsCuratorShowOutputEarlier
          : l10n.skillsCuratorShowOutput,
      lines: model.outputLines,
      initiallyOpen: outputInitiallyOpen,
      selectable: false,
      capHeight: true,
      maxLines: 30,
      earlierLines: model.earlierLines,
      earlierLabel: l10n.skillsCuratorOutputEarlier,
      footnote: l10n.skillsCuratorOutputFootnote,
      blank: model.outputBlanked,
      blankNote: l10n.skillsCuratorOutputHidden,
      semanticsLabel: model.outputBlanked || earlier
          ? null
          : l10n.skillsCuratorOutputSemantics(count),
    );
  }
}

/// A muted line of a group that is no row of its own.
class _NoteRow extends StatelessWidget {
  const _NoteRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: 8,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          style: TextStyle(
            fontSize: metrics.footerSize,
            color: context.hermesColors.subtleText,
          ),
        ),
      ),
    );
  }
}

/// "Last pass or first check", with its footnote. A tap shows the exact time
/// and a second tap hides it; the screen reader label has both at once.
class _LastRanRow extends StatefulWidget {
  const _LastRanRow({required this.status, this.now});

  final CuratorStatusView status;
  final DateTime? now;

  @override
  State<_LastRanRow> createState() => _LastRanRowState();
}

class _LastRanRowState extends State<_LastRanRow> {
  bool _exact = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final at = widget.status.lastRunAt;
    final known = widget.status.lastRun == CuratorLastRunView.at && at != null;
    final never = widget.status.lastRun == CuratorLastRunView.never;
    final interval = widget.status.intervalHours;
    final relative = known
        ? relativeTimeLabel(l10n, at, now: widget.now, bareDate: true)
        : null;
    final exact = known
        ? l10n.skillsCuratorLastRanExact(at.toLocal(), at.toLocal())
        : null;
    final row = GroupedRow(
      title: l10n.skillsCuratorLastRan,
      titleMaxLines: null,
      subtitleMaxLines: null,
      wrapWhenStacked: true,
      value: never
          ? l10n.skillsCuratorLastRanNever
          : relative ?? l10n.skillsCuratorStatusUnknown,
      subtitle: never
          ? (interval == null
                ? l10n.skillsCuratorLastRanNeverNoteUnknown
                : l10n.skillsCuratorLastRanNeverNote(_length(l10n, interval)))
          : known && _exact
          ? exact
          : null,
      onTap: known ? () => setState(() => _exact = !_exact) : null,
      chevron: false,
    );
    if (!known) return row;
    return Column(
      children: [
        Semantics(
          label: l10n.skillsCuratorLastRanSemantics(
            relative!,
            exactTimeLabel(l10n, at),
          ),
          excludeSemantics: true,
          button: true,
          onTap: () => setState(() => _exact = !_exact),
          child: row,
        ),
        _NoteRow(l10n.skillsCuratorLastRanFootnote),
      ],
    );
  }
}
