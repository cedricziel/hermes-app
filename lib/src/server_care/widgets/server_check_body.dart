import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/busy_bar.dart';
import '../../widgets/command_row.dart';
import '../../widgets/disclosure_tile.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/state_message.dart';
import 'server_status_card.dart';

/// Where a Server check is.
enum ServerCheckStage {
  /// Nothing ran yet, or the result was dropped.
  intro,

  /// Hermes is checking.
  running,

  /// The report is shown.
  result,

  /// Not finished after three minutes; the run may still end.
  timeout,

  /// No report: see [ServerCheckView.failure].
  failed,
}

/// Why a check has no report.
enum ServerCheckFailureKind { refused, unreachable, exited }

/// A problem or a warning, as Hermes wrote it.
class CheckFinding {
  const CheckFinding({required this.title, this.detail, this.note, this.group});

  final String title;

  /// What Hermes put after the title.
  final String? detail;

  /// A `→` line under the finding: what to do or why it is harmless.
  final String? note;

  /// Hermes' own section title, such as "Messaging".
  final String? group;
}

/// One entry of Hermes' list of things to fix. A command Hermes quoted in it
/// gets a copy button of its own.
class CheckFix {
  const CheckFix({required this.text, this.command});

  final String text;
  final String? command;
}

/// The checks that passed under one of Hermes' section titles.
class CheckPassedGroup {
  const CheckPassedGroup({required this.title, required this.items});

  final String title;
  final List<String> items;
}

/// A line no rule matched, kept as Hermes wrote it.
class CheckUnknownLine {
  const CheckUnknownLine({required this.text, this.group});

  final String text;
  final String? group;
}

/// Everything the Server check page shows, as plain values. Hermes' words
/// (findings, fixes, unknown lines, a refusal) go through as they came.
class ServerCheckView {
  const ServerCheckView.intro()
    : stage = ServerCheckStage.intro,
      checksSoFar = 0,
      problems = const [],
      warnings = const [],
      fixes = const [],
      passed = const [],
      unknown = const [],
      allPassed = false,
      checkedAgo = null,
      incomplete = false,
      failure = null,
      message = null;

  const ServerCheckView.running({this.checksSoFar = 0})
    : stage = ServerCheckStage.running,
      problems = const [],
      warnings = const [],
      fixes = const [],
      passed = const [],
      unknown = const [],
      allPassed = false,
      checkedAgo = null,
      incomplete = false,
      failure = null,
      message = null;

  const ServerCheckView.result({
    this.problems = const [],
    this.warnings = const [],
    this.fixes = const [],
    this.passed = const [],
    this.unknown = const [],
    this.allPassed = false,
    this.checkedAgo,
    this.incomplete = false,
  }) : stage = ServerCheckStage.result,
       checksSoFar = 0,
       failure = null,
       message = null;

  const ServerCheckView.timeout()
    : stage = ServerCheckStage.timeout,
      checksSoFar = 0,
      problems = const [],
      warnings = const [],
      fixes = const [],
      passed = const [],
      unknown = const [],
      allPassed = false,
      checkedAgo = null,
      incomplete = false,
      failure = null,
      message = null;

  const ServerCheckView.failed({required this.failure, this.message})
    : stage = ServerCheckStage.failed,
      checksSoFar = 0,
      problems = const [],
      warnings = const [],
      fixes = const [],
      passed = const [],
      unknown = const [],
      allPassed = false,
      incomplete = false,
      checkedAgo = null;

  final ServerCheckStage stage;

  /// While running: how many checks have come in.
  final int checksSoFar;
  final List<CheckFinding> problems;
  final List<CheckFinding> warnings;
  final List<CheckFix> fixes;
  final List<CheckPassedGroup> passed;
  final List<CheckUnknownLine> unknown;
  final bool allPassed;

  /// With a result: the check ended without finishing, so this is only what
  /// it had read.
  final bool incomplete;

  /// "just now", "5 minutes ago": fills "Checked …".
  final String? checkedAgo;
  final ServerCheckFailureKind? failure;

  /// Hermes' refusal, or the last lines of a check that stopped.
  final String? message;

  int get passedCount => passed.fold(0, (n, g) => n + g.items.length);
}

/// The first command Hermes quoted in a fix, such as `hermes setup telegram`
/// from "Re-run 'hermes setup telegram'"; null when it quoted none, or only
/// `hermes doctor --fix`, which the app never offers to copy.
String? commandInFix(String text) {
  for (final m in RegExp(r"'(hermes\s[^']+)'").allMatches(text)) {
    final command = m.group(1)!;
    // The app never offers `--fix` to copy: the page's footer explains it.
    if (!command.contains('--fix')) return command;
  }
  return null;
}

/// The Server check page under its bar. Models and callbacks only; the page
/// owns the controller.
class ServerCheckBody extends StatelessWidget {
  const ServerCheckBody({
    super.key,
    required this.view,
    this.onRun,
    this.onKeepWaiting,
    this.onDismiss,
  });

  final ServerCheckView view;

  /// Run, Run again and Try again.
  final VoidCallback? onRun;
  final VoidCallback? onKeepWaiting;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (view.stage) {
      ServerCheckStage.intro => StateMessage(
        icon: AppIcons.info,
        title: l10n.serverCareCheckIntroTitle,
        detail: l10n.serverCareCheckIntroDetail,
        action: onRun == null
            ? null
            : FilledButton(
                onPressed: onRun,
                child: Text(l10n.serverCareCheckRunButton),
              ),
      ),
      ServerCheckStage.running => _running(context),
      ServerCheckStage.result => _result(context),
      ServerCheckStage.timeout => StateMessage(
        icon: AppIcons.warning,
        title: l10n.serverCareCheckTimeoutTitle,
        detail: l10n.serverCareCheckTimeoutDetail,
        action: _buttons([
          if (onKeepWaiting != null)
            FilledButton(
              onPressed: onKeepWaiting,
              child: Text(l10n.serverCareCheckKeepWaiting),
            ),
          if (onDismiss != null)
            TextButton(
              onPressed: onDismiss,
              child: Text(l10n.serverCareCheckDismiss),
            ),
        ]),
      ),
      ServerCheckStage.failed => _failed(context),
    };
  }

  static Widget? _buttons(List<Widget> buttons) => buttons.isEmpty
      ? null
      : ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: buttons,
          ),
        );

  Widget _running(BuildContext context) {
    final l10n = context.l10n;
    return GroupedListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ServerStatusCard(
          tone: ServerStatusTone.loading,
          title: l10n.serverCareCheckRunning,
          detail: view.checksSoFar > 0
              ? l10n.serverCareCheckRunningCount(view.checksSoFar)
              : null,
        ),
        const Padding(padding: EdgeInsets.only(top: 12), child: BusyBar()),
      ],
    );
  }

  Widget _failed(BuildContext context) {
    final l10n = context.l10n;
    final (icon, title, detail) = switch (view.failure) {
      ServerCheckFailureKind.unreachable || null => (
        AppIcons.warning,
        l10n.serverCareHeadlineOffline,
        l10n.serverCareHeadlineOfflineDetail,
      ),
      ServerCheckFailureKind.refused => (
        AppIcons.error,
        l10n.serverCareCheckFailedStartTitle,
        view.message ?? l10n.serverCareCheckFailedStartDetail,
      ),
      ServerCheckFailureKind.exited => (
        AppIcons.error,
        l10n.serverCareCheckFailedExitedTitle,
        view.message ?? l10n.serverCareCheckFailedExitedDetail,
      ),
    };
    return StateMessage(
      icon: icon,
      title: title,
      detail: detail,
      action: _buttons([
        if (onRun != null)
          FilledButton(onPressed: onRun, child: Text(l10n.serverCareTryAgain)),
      ]),
    );
  }

  Widget _result(BuildContext context) {
    final l10n = context.l10n;
    final problems = view.problems.length;
    final warnings = view.warnings.length;
    final (tone, title, detail) = view.incomplete
        ? (
            ServerStatusTone.warning,
            l10n.serverCareCheckIncompleteTitle,
            l10n.serverCareCheckIncompleteDetail,
          )
        : view.allPassed
        ? (ServerStatusTone.healthy, l10n.serverCareCheckAllPassed, null)
        : problems > 0 || warnings > 0
        ? (
            problems > 0 ? ServerStatusTone.error : ServerStatusTone.warning,
            checkSummary(l10n, problems, warnings),
            null,
          )
        : (
            ServerStatusTone.info,
            l10n.serverCareCheckSummaryUnreadable,
            l10n.serverCareCheckSummaryUnreadableDetail,
          );
    final checked = view.checkedAgo == null
        ? null
        : l10n.serverCareCheckChecked(view.checkedAgo!);
    return GroupedListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ServerStatusCard(
          tone: tone,
          title: title,
          detail: [?detail, ?checked].join(' · ').nullIfEmpty,
          button: onRun == null
              ? null
              : ServerStatusButton(
                  label: view.incomplete
                      ? l10n.serverCareTryAgain
                      : l10n.serverCareCheckRunAgain,
                  outlined: true,
                  onPressed: onRun!,
                ),
        ),
        if (problems > 0)
          GroupedSection(
            header: l10n.serverCareCheckProblemsHeader,
            children: [
              for (final f in view.problems)
                _FindingRow(finding: f, problem: true),
            ],
          ),
        if (warnings > 0)
          GroupedSection(
            header: l10n.serverCareCheckWarningsHeader,
            children: [
              for (final f in view.warnings)
                _FindingRow(finding: f, problem: false),
            ],
          ),
        if (view.fixes.isNotEmpty)
          GroupedSection(
            header: l10n.serverCareCheckFixesHeader,
            children: [
              for (final (i, fix) in view.fixes.indexed)
                _FixRow(number: i + 1, fix: fix),
            ],
          ),
        if (view.unknown.isNotEmpty)
          GroupedSection(
            header: l10n.serverCareCheckOtherHeader,
            children: [
              for (final line in view.unknown)
                GroupedRow(
                  title: line.text,
                  titleMaxLines: null,
                  caption: line.group,
                ),
            ],
          ),
        if (view.passedCount > 0)
          GroupedSection(children: [_PassedTile(groups: view.passed)]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            l10n.serverCareCheckFooter,
            style: TextStyle(
              fontSize: GroupedMetrics.of(context).footerSize,
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
      ],
    );
  }
}

/// "2 problems and 3 warnings", "1 problem" or "3 warnings".
String checkSummary(AppLocalizations l10n, int problems, int warnings) =>
    problems > 0 && warnings > 0
    ? l10n.serverCareCheckSummaryProblemsAndWarnings(problems, warnings)
    : problems > 0
    ? l10n.serverCareCheckSummaryProblems(problems)
    : l10n.serverCareCheckSummaryWarnings(warnings);

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding, required this.problem});

  final CheckFinding finding;
  final bool problem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final metrics = GroupedMetrics.of(context);
    final note = finding.note;
    final group = finding.group;
    return GroupedRow(
      // The icon carries the severity in words for screen readers.
      leading: AppIcon(
        problem ? AppIcons.error : AppIcons.warning,
        color: problem ? scheme.error : colors.warning,
        semanticLabel: problem
            ? l10n.serverCareCheckSeverityProblem
            : l10n.serverCareCheckSeverityWarning,
      ),
      title: finding.title,
      titleMaxLines: null,
      subtitle: finding.detail,
      subtitleMaxLines: null,
      details: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              note,
              style: TextStyle(
                fontSize: metrics.subtitleSize,
                color: colors.subtleText,
              ),
            ),
          ),
        // Where Hermes listed it; the last line, as the least needed one.
        if (group != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              group,
              style: TextStyle(
                fontSize: metrics.footerSize,
                color: colors.subtleText,
              ),
            ),
          ),
      ],
    );
  }
}

class _FixRow extends StatelessWidget {
  const _FixRow({required this.number, required this.fix});

  final int number;
  final CheckFix fix;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final command = fix.command;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: metrics.rowVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ${fix.text}',
            style: TextStyle(fontSize: metrics.titleSize),
          ),
          if (command != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: CommandRow(command: command, copyBelowAtLargeText: true),
            ),
        ],
      ),
    );
  }
}

class _PassedTile extends StatelessWidget {
  const _PassedTile({required this.groups});

  final List<CheckPassedGroup> groups;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final count = groups.fold(0, (n, g) => n + g.items.length);
    return DisclosureTile(
      shape: const Border(),
      collapsedShape: const Border(),
      minTileHeight: metrics.rowMinHeight,
      tilePadding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
      childrenPadding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        0,
        metrics.rowPadding,
        metrics.rowPadding,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(
        l10n.serverCareCheckPassedTitle(count),
        style: TextStyle(fontSize: metrics.titleSize),
      ),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Semantics(
              header: true,
              child: Text(
                group.title,
                style: TextStyle(
                  fontSize: metrics.subtitleSize,
                  fontWeight: FontWeight.w600,
                  color: colors.subtleText,
                ),
              ),
            ),
          ),
          for (final item in group.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(
                    AppIcons.checkCircle,
                    size: metrics.subtitleSize + 3,
                    color: colors.success,
                    semanticLabel: l10n.serverCareCheckSeverityPassed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(fontSize: metrics.subtitleSize),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
