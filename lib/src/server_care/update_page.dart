import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_icons.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'update_check_controller.dart';
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

/// What the Updates row opens: whether Hermes is up to date, what changed,
/// and Check now. Applying an update is not offered here yet.
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.controller, this.version});

  /// Shared with the Server screen, which owns it.
  final UpdateCheckController controller;

  /// The version the server's status reported, for a check that names none.
  final String? version;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.everChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.check();
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final l10n = context.l10n;
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
      return SettingsScaffold(
        title: l10n.serverCareUpdatePageTitle,
        previousTitle: l10n.serverCareTitle,
        actions: [
          SettingsBarAction(
            key: const Key('update-refresh'),
            label: l10n.serverCareCheckNow,
            icon: AppIcons.refresh,
            onPressed: checking ? null : () => controller.check(force: true),
          ),
        ],
        body: GroupedListView(
          children: [
            if (status != null)
              UpdateStatusCard(
                status: status,
                onCheckNow: checking
                    ? null
                    : () => controller.check(force: true),
              ),
            if (state is UpdateStateAvailable || state is UpdateStateRollback)
              if (changes.isNotEmpty) UpdateChangeList(changes: changes),
          ],
        ),
      );
    },
  );
}
