import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../api/hermes_repositories.dart';
import '../theme/app_icons.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'hermes_update_run.dart';
import 'server_care_controller.dart';
import 'update_actions.dart';
import 'update_check_controller.dart';
import 'widgets/update_run_view.dart';
import 'widgets/update_status_card.dart';

/// Words an [Elapsed] for [l10n]: "just now", "2 hours ago", "today".
String elapsedText(AppLocalizations l10n, Elapsed elapsed) =>
    switch (elapsed.unit) {
      ElapsedUnit.justNow => l10n.serverCareAgoJustNow,
      ElapsedUnit.minutes => l10n.serverCareAgoMinutes(elapsed.count),
      ElapsedUnit.hours => l10n.serverCareAgoHours(elapsed.count),
      ElapsedUnit.today => l10n.serverCareAgoToday,
      ElapsedUnit.days => l10n.serverCareAgoDays(elapsed.count),
    };

/// The status card's model for [state], worded for [l10n]. Hermes' own text
/// goes through as it came.
UpdateStatus updateStatusOf(
  AppLocalizations l10n,
  UpdateState state,
) => switch (state) {
  UpdateStateChecking() => const UpdateChecking(),
  UpdateStateUpToDate(:final version, :final checkedAgo) => UpdateUpToDate(
    version: version,
    checkedAgo: elapsedText(l10n, checkedAgo),
  ),
  UpdateStateFailed(:final message, :final reason) => UpdateCheckFailed(
    message:
        message ??
        switch (reason) {
          UpdateFailureReason.offline => l10n.serverCareFailureOffline,
          UpdateFailureReason.checkFailed => l10n.serverCareFailureUpdateCheck,
          UpdateFailureReason.noResult => l10n.serverCareUpdateCheckFailed,
        },
  ),
  UpdateStateAvailable(:final changeCount, :final currentVersion) =>
    UpdateAvailable(changeCount: changeCount, currentVersion: currentVersion),
  UpdateStateRollback(
    :final stableVersion,
    :final changeCount,
    :final currentVersion,
  ) =>
    UpdateRollback(
      stableVersion: stableVersion,
      changeCount: changeCount,
      currentVersion: currentVersion,
    ),
  UpdateStateCannotApply(:final message, :final command) => UpdateCannotApply(
    message: message ?? l10n.serverCareUpdateOnServer,
    command: command,
  ),
};

/// Pushes the Update page over the current route, for a link that does not
/// start from the Server screen (the restart banner). The pushed route sits
/// above the shell's providers, so they go with it.
Future<void> showUpdatePage(BuildContext context) {
  final care = context.read<ServerCareController>();
  final run = context.read<HermesUpdateRun>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ServerCareController>.value(value: care),
          ChangeNotifierProvider<HermesUpdateRun>.value(value: run),
        ],
        child: const UpdatePage(),
      ),
    ),
  );
}

/// What the Updates row opens: whether Hermes is up to date, what changed,
/// Check now and Update Hermes, and, once an update was confirmed, its
/// progress and outcome. The run belongs to the shell, so leaving the page
/// never cancels it and returning shows where it is.
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, this.controller, this.version});

  /// Shared with the Server screen, which owns it. A page opened without one
  /// (from the restart banner) checks for itself.
  final UpdateCheckController? controller;

  /// The version the server's status reported, for a check that names none.
  final String? version;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  UpdateCheckController? _own;
  late final HermesUpdateRun _run;
  UpdatePhase? _lastPhase;

  UpdateCheckController get _controller => widget.controller ?? _own!;

  @override
  void initState() {
    super.initState();
    _run = context.read<HermesUpdateRun>();
    _lastPhase = _run.phase;
    if (widget.controller == null) {
      final care = context.read<ServerCareController>();
      _own = UpdateCheckController(
        repository: HermesRepositories.of(context).serverCare,
        onUnsupported: () => care.reportUnsupported(CarePart.update),
      );
      // What the page checked is stale once an update ended.
      _run.addListener(_runChanged);
    }
    if (!_controller.everChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.check();
      });
    }
  }

  void _runChanged() {
    final phase = _run.phase;
    final ended =
        _lastPhase != UpdatePhase.finished && phase == UpdatePhase.finished;
    _lastPhase = phase;
    if (ended && mounted) _controller.check(force: true);
  }

  @override
  void dispose() {
    if (_own != null) {
      _run.removeListener(_runChanged);
      _own!.dispose();
    }
    super.dispose();
  }

  void _tryAgain() {
    _run.dismiss();
    runUpdate(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, _run]),
    builder: (context, _) {
      final controller = _controller;
      final l10n = context.l10n;
      final view = updateRunViewOf(l10n, _run);
      final state = controller.state(fallbackVersion: widget.version);
      final status = state == null ? null : updateStatusOf(l10n, state);
      final checking = state is UpdateStateChecking;
      final changes = [
        for (final c in controller.changes)
          UpdateChange(
            summary: c.summary,
            byline: [
              ?c.author,
              if (c.when case final ago?) elapsedText(l10n, ago),
            ].join(' · '),
          ),
      ];
      final canApply =
          state is UpdateStateAvailable || state is UpdateStateRollback;
      return SettingsScaffold(
        title: l10n.serverCareUpdatePageTitle,
        previousTitle: l10n.serverCareTitle,
        actions: [
          SettingsBarAction(
            key: const Key('update-refresh'),
            label: l10n.serverCareCheckNow,
            icon: AppIcons.refresh,
            onPressed: checking || view != null
                ? null
                : () => controller.check(force: true),
          ),
        ],
        body: GroupedListView(
          children: [
            if (view != null)
              UpdateRunBody(
                view: view,
                onDone: _run.dismiss,
                onTryAgain: _tryAgain,
                onCheckAgain: _run.checkAgain,
                onKeepWaiting: _run.keepWaiting,
                onDismiss: _run.dismiss,
              )
            else ...[
              if (status != null)
                UpdateStatusCard(
                  status: status,
                  onCheckNow: checking
                      ? null
                      : () => controller.check(force: true),
                  onUpdate: canApply ? () => runUpdate(context) : null,
                ),
              if (canApply && changes.isNotEmpty)
                UpdateChangeList(changes: changes),
            ],
          ],
        ),
      );
    },
  );
}
